#include "kwinactivewindowbridge.hpp"
#include "plasmawindows.hpp"
#include "kwinworkspacestate.hpp"
#include <QGuiApplication>
#include <QScreen>
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

QString KWinActiveWindowBridge::getOutputNameForGeometry(int x, int y, int w, int h) const {
    QRect windowRect(x, y, w, h);
    int maxIntersectArea = 0;
    QString bestScreenName = "";

    for (QScreen* screen : QGuiApplication::screens()) {
        QRect intersect = screen->geometry().intersected(windowRect);
        int area = intersect.width() * intersect.height();
        if (area > maxIntersectArea) {
            maxIntersectArea = area;
            bestScreenName = screen->name();
        }
    }

    return bestScreenName;
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
    } else if (!activeWindowFound && !m_activeWindow.isEmpty()) {
        m_activeWindow.clear();
        emit activeWindowChanged();
    }
}

void KWinActiveWindowBridge::focusWindow(const QString &address) {
    if (auto* handle = PlasmaWindows::instance()->handleFor(address)) {
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
        handle->set_state(QtWayland::org_kde_plasma_window_management::state_maximized, QtWayland::org_kde_plasma_window_management::state_maximized);
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



void KWinActiveWindowBridge::refreshWindows() {
    scheduleWindowListUpdate();
}

} // namespace caelestia::services
