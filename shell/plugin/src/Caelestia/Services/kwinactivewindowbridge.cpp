#include "kwinactivewindowbridge.hpp"
#include "plasmawindows.hpp"
#include <QDBusMessage>
#include <QDBusConnection>
#include "kwinworkspacestate.hpp"
#include <QGuiApplication>
#include <QScreen>
#include <QTimer>
#include <QtDBus/QDBusConnection>
#include <QtDBus/QDBusMessage>

namespace caelestia::services {

KWinActiveWindowBridge::KWinActiveWindowBridge(QObject *parent)
    : QObject(parent) {

    m_updateTimer.setSingleShot(true);
    m_updateTimer.setInterval(50);
    connect(&m_updateTimer, &QTimer::timeout, this, &KWinActiveWindowBridge::buildWindowList);

    auto* plasmaWindows = PlasmaWindows::instance();
    connect(plasmaWindows, &PlasmaWindows::windowAdded, this, &KWinActiveWindowBridge::onWindowAdded);
    connect(plasmaWindows, &PlasmaWindows::handleLost, this, &KWinActiveWindowBridge::onWindowLost);
}

KWinActiveWindowBridge::~KWinActiveWindowBridge() = default;

QVariantMap KWinActiveWindowBridge::activeWindow() const {
    return m_activeWindow;
}

QString KWinActiveWindowBridge::activeOutputName() const {
    return m_activeOutputName;
}

void KWinActiveWindowBridge::setActiveOutputName(const QString &outputName) {
    if (m_activeOutputName != outputName) {
        m_activeOutputName = outputName;
        emit activeOutputNameChanged();
    }
}

QVariantList KWinActiveWindowBridge::windowList() const {
    return m_windowList;
}

QVariantList KWinActiveWindowBridge::windowsForWorkspace(const QVariant& workspace, bool includeOnAllWorkspaces) const {
    const bool hasNumberTarget = workspace.type() == QVariant::Int && workspace.toInt() > 0;
    const bool hasStringTarget = workspace.type() == QVariant::String && !workspace.toString().isEmpty();

    QVariantList out;
    for (const QVariant& v : m_windowList) {
        const QVariantMap window = v.toMap();
        const QVariantMap ws = window.value("workspace").toMap();
        if (ws.isEmpty()) { // No workspace info: can't rule it out.
            out.push_back(v);
            continue;
        }
        const QVariant id = ws.value("id");
        const QString uuid = ws.value("uuid").toString();
        const bool onAll = (id.type() == QVariant::Int && id.toInt() == -1) || uuid.isEmpty();
        if (onAll) {
            if (includeOnAllWorkspaces)
                out.push_back(v);
            continue;
        }
        if (!hasNumberTarget && !hasStringTarget) {
            out.push_back(v);
            continue;
        }
        if (hasNumberTarget && id.type() == QVariant::Int && id.toInt() == workspace.toInt()) {
            out.push_back(v);
            continue;
        }
        if (hasStringTarget && uuid == workspace.toString()) {
            out.push_back(v);
            continue;
        }
    }
    return out;
}

QString KWinActiveWindowBridge::pendingFocusAddress() const {
    return m_pendingFocusAddress;
}

QString KWinActiveWindowBridge::cursorOutputName() const {
    const auto message = QDBusMessage::createMethodCall("org.kde.KWin", "/KWin", "org.kde.KWin", "activeOutputName");
    return QDBusConnection::sessionBus().call(message).arguments().value(0).toString();
}

void KWinActiveWindowBridge::onWindowAdded(const QString& uuid) {
    if (auto* handle = PlasmaWindows::instance()->handleFor(uuid)) {
        connect(handle, &PlasmaWindowHandle::titleChanged, this, &KWinActiveWindowBridge::scheduleWindowListUpdate);
        connect(handle, &PlasmaWindowHandle::appIdChanged, this, &KWinActiveWindowBridge::scheduleWindowListUpdate);
        connect(handle, &PlasmaWindowHandle::geometryChanged, this, &KWinActiveWindowBridge::scheduleWindowListUpdate);
        connect(handle, &PlasmaWindowHandle::stateChanged, this, &KWinActiveWindowBridge::scheduleWindowListUpdate);
        connect(handle, &PlasmaWindowHandle::desktopsChanged, this, &KWinActiveWindowBridge::scheduleWindowListUpdate);
        scheduleWindowListUpdate();
    }
}

void KWinActiveWindowBridge::onWindowLost(const QString& uuid) {
    Q_UNUSED(uuid);
    scheduleWindowListUpdate();
}

void KWinActiveWindowBridge::scheduleWindowListUpdate() {
    if (!m_updateTimer.isActive()) {
        m_updateTimer.start();
    }
}

void KWinActiveWindowBridge::sendToOutput(const QString &address, const QString &outputName) {
    if (address.isEmpty() || outputName.isEmpty()) {
        return;
    }

    QScreen *target = nullptr;
    for (QScreen *screen : QGuiApplication::screens()) {
        if (screen->name() == outputName) {
            target = screen;
            break;
        }
    }
    if (!target) {
        return;
    }

    QVariantMap window;
    for (const QVariant &entry : m_windowList) {
        const QVariantMap map = entry.toMap();
        if (map.value(QStringLiteral("address")).toString() == address) {
            window = map;
            break;
        }
    }
    if (window.isEmpty()) {
        return;
    }

    const QString currentName = window.value(QStringLiteral("output")).toString();
    QScreen *current = nullptr;
    for (QScreen *screen : QGuiApplication::screens()) {
        if (screen->name() == currentName) {
            current = screen;
            break;
        }
    }
    if (!current || current == target) {
        return;
    }

    // KWin's own "move the window one screen over" actions, driven through
    // kglobalaccel.
    //
    // There is no direct way to ask for this: plasma-window-management moves a
    // window between desktops but not between outputs, and no D-Bus interface
    // exposes it either. These actions do exactly the right thing, they are
    // part of KWin proper rather than anything this shell has to install, and
    // they need no privilege. The cost is that they act on the active window,
    // so the window has to be focused first -- which is what dragging a window
    // to another monitor implies anyway.
    const QPoint from = current->geometry().center();
    const QPoint to = target->geometry().center();
    QString action;
    if (qAbs(to.x() - from.x()) >= qAbs(to.y() - from.y())) {
        action = to.x() > from.x() ? QStringLiteral("Window One Screen to the Right")
                                   : QStringLiteral("Window One Screen to the Left");
    } else {
        action = to.y() > from.y() ? QStringLiteral("Window One Screen Down")
                                   : QStringLiteral("Window One Screen Up");
    }

    focusWindow(address);

    // Focus has to have landed before the action fires, or it moves whatever
    // was focused before.
    QTimer::singleShot(120, this, [action]() {
        QDBusMessage msg = QDBusMessage::createMethodCall("org.kde.kglobalaccel", "/component/kwin",
            "org.kde.kglobalaccel.Component", "invokeShortcut");
        msg << action;
        QDBusConnection::sessionBus().call(msg, QDBus::NoBlock);
    });
}

/// A screen's rect in the compositor's physical pixels.
///
/// org_kde_plasma_window.geometry reports window rects in physical pixels,
/// while QScreen::geometry() is logical (already-scaled) pixels: a screen at
/// 200% covers twice the physical extent its geometry() says it does. Both
/// rects have to be intersected in the same space, or the "largest overlap"
/// screen is whichever rect happens to be numerically bigger.
static QRect physicalGeometry(const QScreen* screen) {
    const QRect logical = screen->geometry();
    const qreal dpr = screen->devicePixelRatio();
    return QRect(QPoint(qRound(logical.x() * dpr), qRound(logical.y() * dpr)),
                 QSize(qRound(logical.width() * dpr), qRound(logical.height() * dpr)));
}

QString KWinActiveWindowBridge::getOutputNameForGeometry(int x, int y, int w, int h) const {
    const QRect windowRect(x, y, w, h);

    QScreen* bestScreen = nullptr;
    qreal maxIntersectArea = 0;

    for (QScreen* screen : QGuiApplication::screens()) {
        const QRect intersect = physicalGeometry(screen).intersected(windowRect);
        const qreal area = static_cast<qreal>(intersect.width()) * static_cast<qreal>(intersect.height());
        if (area > maxIntersectArea) {
            maxIntersectArea = area;
            bestScreen = screen;
        }
    }

    if (!bestScreen) {
        // Nothing overlapped at all - a stale rect, or a screen that just went
        // away. Fall back to the nearest screen by centre so a window is never
        // reported without an output: every per-monitor filter in the shell
        // keys off this name and treats "" as "no screen".
        qreal bestDistance = -1;
        const QPoint windowCentre = windowRect.center();
        for (QScreen* screen : QGuiApplication::screens()) {
            const QPoint delta = physicalGeometry(screen).center() - windowCentre;
            const qreal distance =
                static_cast<qreal>(delta.x()) * delta.x() + static_cast<qreal>(delta.y()) * delta.y();
            if (bestDistance < 0 || distance < bestDistance) {
                bestDistance = distance;
                bestScreen = screen;
            }
        }
    }

    return bestScreen ? bestScreen->name() : QString();
}

QVariantMap KWinActiveWindowBridge::windowToVariant(PlasmaWindowHandle* w) const {
    QVariant desktopId = -1;
    QVariant desktopUuid = "";
    if (!w->desktops().isEmpty()) {
        QString firstDesktop = w->desktops().first();
        bool ok;
        int parsed = firstDesktop.toInt(&ok);
        if (ok) {
            desktopId = parsed;
            desktopUuid = firstDesktop;
        } else {
            // Plasma 6 uses UUIDs for desktops. Pass the UUID string directly to QML.
            desktopUuid = firstDesktop;
            if (auto wsState = KWinWorkspaceState::instance()) {
                int idx = wsState->indexForId(firstDesktop);
                if (idx != -1) desktopId = idx;
            }
        }
    }

    QVariantMap map = {
        {"address", w->uuid()},
        {"pid", w->pid()},
        {"title", w->title()},
        {"class", w->appId()},
        {"x", w->x()},
        {"y", w->y()},
        {"width", w->width()},
        {"height", w->height()},
        {"fullscreen", w->isFullscreen()},
        {"maximized", w->isMaximized()},
        {"minimized", w->isMinimized()},
        {"focused", w->isActive()},
        {"floating", !w->isFullscreen() && !w->isMaximized()}, // Fallback for floating state
        {"output", getOutputNameForGeometry(w->x(), w->y(), w->width(), w->height())},
        {"workspace", QVariantMap{{"id", desktopId}, {"uuid", desktopUuid}}}
    };
    return map;
}

void KWinActiveWindowBridge::buildWindowList() {
    m_windowList.clear();
    QVariantMap newActiveWindow;
    bool activeWindowFound = false;

    auto* plasmaWindows = PlasmaWindows::instance();
// qDebug() << "KWinActiveWindowBridge::buildWindowList called, total UUIDs:" << plasmaWindows->windowUuids().size();
    for (const QString& uuid : plasmaWindows->windowUuids()) {
        if (auto* handle = plasmaWindows->handleFor(uuid)) {
            QVariantMap w = windowToVariant(handle);
            m_windowList.append(w);
            if (handle->isActive()) {
                newActiveWindow = w;
                activeWindowFound = true;
            }
        } else {
// qDebug() << "KWinActiveWindowBridge: handleFor returned nullptr for uuid" << uuid;
        }
    }

// qDebug() << "KWinActiveWindowBridge: Emitting windowListChanged with" << m_windowList.size() << "windows.";
    emit windowListChanged();

    if (activeWindowFound && m_activeWindow != newActiveWindow) {
        m_activeWindow = newActiveWindow;
        emit activeWindowChanged();

        // Keep activeOutputName in sync so Hypr.focusedMonitor resolves correctly
        // on multi-monitor setups. Without this it stays empty forever and the QML
        // fallback always picks monitor index 0.
        const QString newOutput = newActiveWindow.value("output").toString();
        if (!newOutput.isEmpty())
            setActiveOutputName(newOutput);

        if (m_activeWindow.value("address").toString() == m_pendingFocusAddress) {
            m_pendingFocusAddress.clear();
            emit pendingFocusAddressChanged();
        }
    } else if (!activeWindowFound && !m_activeWindow.isEmpty()) {
        m_activeWindow.clear();
        emit activeWindowChanged();
    }
}

void KWinActiveWindowBridge::focusWindow(const QString &address) {
    if (auto* handle = PlasmaWindows::instance()->handleFor(address)) {
        m_pendingFocusAddress = address;
        emit pendingFocusAddressChanged();

        // To focus a window, we set the active state
        handle->set_state(QtWayland::org_kde_plasma_window_management::state_active, QtWayland::org_kde_plasma_window_management::state_active);
    }
}

void KWinActiveWindowBridge::closeWindow(const QString &address) {
    if (auto* handle = PlasmaWindows::instance()->handleFor(address)) {
        handle->close();
    }
}

void KWinActiveWindowBridge::minimizeWindow(const QString &address) {
    if (auto* handle = PlasmaWindows::instance()->handleFor(address)) {
        handle->set_state(QtWayland::org_kde_plasma_window_management::state_minimized, QtWayland::org_kde_plasma_window_management::state_minimized);
    }
}

void KWinActiveWindowBridge::maximizeWindow(const QString &address, bool horz, bool vert) {
    if (auto* handle = PlasmaWindows::instance()->handleFor(address)) {
        const auto max = QtWayland::org_kde_plasma_window_management::state_maximized;
        // The plasma-window-management protocol exposes only a combined maximized
        // state — there are no per-axis (horz/vert) flags in the state enum — so
        // any maximize request maps onto the combined flag. The only caller
        // (windowinfo/Buttons.qml) passes both axes equal, so this preserves the
        // maximize/restore behaviour.
        handle->set_state((horz || vert) ? max : 0, max);
    }
}

void KWinActiveWindowBridge::raiseWindow(const QString &address) {
    focusWindow(address);
}

void KWinActiveWindowBridge::setWindowProperty(const QString &address, const QString &property, bool enable) {
    if (auto* handle = PlasmaWindows::instance()->handleFor(address)) {
        uint32_t state = 0;
        if (property == "keep_above") state = QtWayland::org_kde_plasma_window_management::state_keep_above;
        else if (property == "keep_below") state = QtWayland::org_kde_plasma_window_management::state_keep_below;
        else if (property == "skip_taskbar") state = QtWayland::org_kde_plasma_window_management::state_skiptaskbar;
        else if (property == "demands_attention") state = QtWayland::org_kde_plasma_window_management::state_demands_attention;

        if (state != 0) {
            handle->set_state(enable ? state : 0, state);
        }
    }
}

void KWinActiveWindowBridge::setWindowDesktop(const QString &address, int desktopId) {
    if (auto* handle = PlasmaWindows::instance()->handleFor(address)) {
        if (auto wsState = KWinWorkspaceState::instance()) {
            QString uuid = wsState->uuidForIndex(desktopId);
            if (!uuid.isEmpty()) {
                QStringList currentDesktops = handle->desktops();
                for (const QString& oldUuid : currentDesktops) {
                    if (oldUuid != uuid) {
                        handle->request_leave_virtual_desktop(oldUuid);
                    }
                }
                handle->request_enter_virtual_desktop(uuid);
            }
        }
    }
}

void KWinActiveWindowBridge::setFullscreen(const QString& address, bool fullscreen) {
    if (auto* handle = PlasmaWindows::instance()->handleFor(address)) {
        handle->set_state(fullscreen ? QtWayland::org_kde_plasma_window_management::state_fullscreen : 0, QtWayland::org_kde_plasma_window_management::state_fullscreen);
    }
}

void KWinActiveWindowBridge::setMaximized(const QString& address, bool maximized) {
    if (auto* handle = PlasmaWindows::instance()->handleFor(address)) {
        handle->set_state(maximized ? QtWayland::org_kde_plasma_window_management::state_maximized : 0, QtWayland::org_kde_plasma_window_management::state_maximized);
    }
}

void KWinActiveWindowBridge::highlightWindow(const QString& address) {
    auto msg = QDBusMessage::createMethodCall(QStringLiteral("org.kde.KWin"),
                                              QStringLiteral("/org/kde/KWin/HighlightWindow"),
                                              QStringLiteral("org.kde.KWin.HighlightWindow"),
                                              QStringLiteral("highlightWindows"));
    QStringList list;
    if (!address.isEmpty()) {
        list << address;
    }
    msg << list;
    QDBusConnection::sessionBus().send(msg);
}

void KWinActiveWindowBridge::clearHighlight() {
    highlightWindow(QString());
}

void KWinActiveWindowBridge::refreshWindows() {
    scheduleWindowListUpdate();
}

} // namespace caelestia::services
