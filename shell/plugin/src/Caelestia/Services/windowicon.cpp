// SPDX-License-Identifier: GPL-3.0-only
#include "windowicon.hpp"

#include <qcryptographichash.h>
#include <qdir.h>
#include <qfile.h>
#include <qimage.h>
#include <qloggingcategory.h>
#include <qstandardpaths.h>

#include <X11/Xatom.h>
#include <X11/Xlib.h>
#include <X11/Xutil.h>

namespace caelestia::services {

namespace {

Q_LOGGING_CATEGORY(logWindowIcon, "caelestia.services.windowicon");

/// RAII for the X display, so every early return still closes it.
class XDisplay {
public:
    XDisplay()
        : m_dpy(XOpenDisplay(nullptr)) {}
    ~XDisplay() {
        if (m_dpy) {
            XCloseDisplay(m_dpy);
        }
    }

    XDisplay(const XDisplay&) = delete;
    XDisplay& operator=(const XDisplay&) = delete;

    operator Display*() const { return m_dpy; }
    bool isValid() const { return m_dpy != nullptr; }

private:
    Display* m_dpy;
};

/// Fetch a window property in full, following the multi-read protocol.
unsigned char* fetchProperty(Display* dpy, Window win, Atom prop, Atom type, unsigned long* count) {
    Atom actualType;
    int actualFormat;
    unsigned long bytesAfter;
    unsigned char* data = nullptr;

    if (XGetWindowProperty(dpy, win, prop, 0, 0, False, type, &actualType, &actualFormat, count, &bytesAfter,
            &data) != Success) {
        return nullptr;
    }
    if (data) {
        XFree(data);
        data = nullptr;
    }
    if (bytesAfter == 0) {
        return nullptr;
    }

    // bytesAfter is in bytes; XGetWindowProperty wants 32-bit words.
    const long words = static_cast<long>((bytesAfter + 3) / 4);
    if (XGetWindowProperty(dpy, win, prop, 0, words, False, type, &actualType, &actualFormat, count, &bytesAfter,
            &data) != Success) {
        return nullptr;
    }
    return data;
}

QString windowTitle(Display* dpy, Window win) {
    const Atom netName = XInternAtom(dpy, "_NET_WM_NAME", True);
    if (netName != None) {
        unsigned long count = 0;
        if (auto* data = fetchProperty(dpy, win, netName, AnyPropertyType, &count)) {
            const auto title = QString::fromUtf8(reinterpret_cast<const char*>(data));
            XFree(data);
            if (!title.isEmpty()) {
                return title;
            }
        }
    }

    char* legacy = nullptr;
    if (XFetchName(dpy, win, &legacy) && legacy) {
        const auto title = QString::fromUtf8(legacy);
        XFree(legacy);
        return title;
    }
    return QString();
}

bool matchesWindow(Display* dpy, Window win, const QString& wmClass, const QString& title) {
    XClassHint hint {};
    bool classMatches = false;

    if (XGetClassHint(dpy, win, &hint)) {
        const auto name = QString::fromUtf8(hint.res_name ? hint.res_name : "");
        const auto cls = QString::fromUtf8(hint.res_class ? hint.res_class : "");
        if (hint.res_name) {
            XFree(hint.res_name);
        }
        if (hint.res_class) {
            XFree(hint.res_class);
        }
        classMatches = name.compare(wmClass, Qt::CaseInsensitive) == 0 || cls.compare(wmClass, Qt::CaseInsensitive) == 0;
    }

    if (classMatches) {
        return true;
    }

    // KWin often reports the title as the "class" for these windows (Minecraft
    // shows up as "Minecraft* 1.21.11"), so fall back to matching on it.
    const auto actual = windowTitle(dpy, win);
    if (actual.isEmpty()) {
        return false;
    }
    return actual == wmClass || (!title.isEmpty() && actual == title);
}

/**
 * Decode the largest image in a _NET_WM_ICON payload.
 *
 * The property is a sequence of [width, height, w*h ARGB pixels] runs. Each
 * pixel is a 32-bit value stored in a long, which is 64-bit here — so it has to
 * be narrowed rather than memcpy'd.
 */
QImage decodeLargest(const unsigned long* data, unsigned long count) {
    QImage best;
    unsigned long i = 0;

    while (i + 2 <= count) {
        const auto w = static_cast<int>(data[i]);
        const auto h = static_cast<int>(data[i + 1]);
        i += 2;

        if (w <= 0 || h <= 0) {
            break;
        }
        const unsigned long pixels = static_cast<unsigned long>(w) * static_cast<unsigned long>(h);
        if (pixels > count - i) {
            break; // truncated payload
        }

        if (static_cast<qint64>(w) * h > static_cast<qint64>(best.width()) * best.height()) {
            QImage image(w, h, QImage::Format_ARGB32);
            for (int y = 0; y < h; ++y) {
                auto* line = reinterpret_cast<QRgb*>(image.scanLine(y));
                for (int x = 0; x < w; ++x) {
                    line[x] = static_cast<QRgb>(data[i + static_cast<unsigned long>(y) * w + x] & 0xffffffff);
                }
            }
            best = image;
        }

        i += pixels;
    }

    return best;
}

} // namespace

WindowIcon::WindowIcon(QObject* parent)
    : QObject(parent) {}

QString WindowIcon::extract(const QString& wmClass, const QString& title) {
    if (wmClass.isEmpty()) {
        return QString();
    }

    const auto cacheRoot =
        QStandardPaths::writableLocation(QStandardPaths::GenericCacheLocation) + QStringLiteral("/caelestia/winicons");
    const auto key = QString::fromLatin1(
        QCryptographicHash::hash((wmClass + QStringLiteral("|") + title).toUtf8(), QCryptographicHash::Sha256)
            .toHex()
            .left(16));
    const auto path = cacheRoot + QStringLiteral("/") + key + QStringLiteral(".png");

    if (QFile::exists(path)) {
        emit extracted(wmClass, path);
        return path;
    }

    XDisplay display;
    if (!display.isValid()) {
        qCDebug(logWindowIcon) << "no X display; only XWayland windows carry _NET_WM_ICON";
        return QString();
    }

    Display* dpy = display;
    const Atom netWmIcon = XInternAtom(dpy, "_NET_WM_ICON", True);
    const Atom clientList = XInternAtom(dpy, "_NET_CLIENT_LIST", True);
    if (netWmIcon == None || clientList == None) {
        return QString();
    }

    unsigned long windowCount = 0;
    auto* rawWindows = fetchProperty(dpy, DefaultRootWindow(dpy), clientList, XA_WINDOW, &windowCount);
    if (!rawWindows) {
        return QString();
    }
    const auto* windows = reinterpret_cast<const Window*>(rawWindows);

    QImage icon;
    for (unsigned long i = 0; i < windowCount; ++i) {
        if (!matchesWindow(dpy, windows[i], wmClass, title)) {
            continue;
        }

        unsigned long iconCount = 0;
        auto* rawIcon = fetchProperty(dpy, windows[i], netWmIcon, XA_CARDINAL, &iconCount);
        if (!rawIcon) {
            continue;
        }

        icon = decodeLargest(reinterpret_cast<const unsigned long*>(rawIcon), iconCount);
        XFree(rawIcon);
        if (!icon.isNull()) {
            break;
        }
    }
    XFree(rawWindows);

    if (icon.isNull()) {
        return QString();
    }

    if (!QDir().mkpath(cacheRoot) || !icon.save(path, "PNG")) {
        qCWarning(logWindowIcon) << "could not write icon cache for" << wmClass << "to" << path;
        return QString();
    }

    emit extracted(wmClass, path);
    return path;
}

} // namespace caelestia::services
