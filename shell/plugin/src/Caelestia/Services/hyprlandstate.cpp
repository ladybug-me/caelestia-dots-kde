#include "hyprlandstate.hpp"
#include "plasmawindows.hpp"

#include <qdir.h>
#include <qlocalsocket.h>
#include <qloggingcategory.h>

Q_LOGGING_CATEGORY(lcHyprState, "caelestia.services.hyprlandstate", QtInfoMsg)

namespace caelestia::services {

HyprlandState::HyprlandState(QObject* parent)
    : QObject(parent)
    , m_requestSocket("")
    , m_eventSocket("")
    , m_socket(nullptr)
    , m_socketValid(false) {

    const auto his = qEnvironmentVariable("HYPRLAND_INSTANCE_SIGNATURE");
    if (his.isEmpty()) {
        qCWarning(lcHyprState) << "$HYPRLAND_INSTANCE_SIGNATURE is unset. Using KDE (PlasmaWindows) bridge.";
        auto* pw = PlasmaWindows::instance();
        connect(pw, &PlasmaWindows::windowAdded, this, &HyprlandState::onKWinWindowListChanged);
        connect(pw, &PlasmaWindows::handleLost, this, &HyprlandState::onKWinWindowListChanged);
        // Push the initial state that PlasmaWindows already has
        onKWinWindowListChanged();
        onKWinActiveWindowChanged();
        return;
    }

    auto hyprDir = QString("%1/hypr/%2").arg(qEnvironmentVariable("XDG_RUNTIME_DIR"), his);
    if (!QDir(hyprDir).exists()) {
        hyprDir = "/tmp/hypr/" + his;

        if (!QDir(hyprDir).exists()) {
            qCWarning(lcHyprState) << "Hyprland socket directory does not exist. Unable to connect to Hyprland socket.";
            return;
        }
    }

    m_requestSocket = hyprDir + "/.socket.sock";
    m_eventSocket = hyprDir + "/.socket2.sock";

    m_socket = new QLocalSocket(this);

    QObject::connect(m_socket, &QLocalSocket::errorOccurred, this, &HyprlandState::socketError);
    QObject::connect(m_socket, &QLocalSocket::stateChanged, this, &HyprlandState::socketStateChanged);
    QObject::connect(m_socket, &QLocalSocket::readyRead, this, &HyprlandState::readEvent);

    m_socket->connectToServer(m_eventSocket, QLocalSocket::ReadOnly);

    // Initial fetch
    updateAll();
}

QVariantList HyprlandState::windowList() const { return m_windowList; }
QVariantMap HyprlandState::windowByAddress() const { return m_windowByAddress; }
QVariantList HyprlandState::addresses() const { return m_addresses; }
QVariantList HyprlandState::workspaces() const { return m_workspaces; }
QVariantMap HyprlandState::workspaceById() const { return m_workspaceById; }
QVariantList HyprlandState::workspaceIds() const { return m_workspaceIds; }
QVariantMap HyprlandState::activeWorkspace() const {
    return m_activeWorkspace;
}

QVariantMap HyprlandState::activeWindow() const {
    return m_activeWindow;
}

QVariantList HyprlandState::monitors() const { return m_monitors; }
QVariantMap HyprlandState::layers() const { return m_layers; }

void HyprlandState::updateAll() {
    updateWindowList();
    updateWorkspaces();
    updateMonitors();
    updateLayers();
    updateActiveWorkspace();
}

void HyprlandState::onKWinWindowListChanged() {
    auto* pw = PlasmaWindows::instance();
    QVariantList newList;
    QVariantMap newByAddress;
    QVariantList newAddresses;
    QVariantMap newActiveWindow;
    for (const QString& uuid : pw->windowUuids()) {
        auto* handle = pw->handleFor(uuid);
        if (!handle) continue;
        const auto cls = handle->appId();
        if (cls.isEmpty() || cls.toLower().contains("quickshell")) continue;
        const QVariantMap variant = {
            { "address", handle->uuid() },
            { "pid",     static_cast<int>(handle->pid()) },
            { "title",   handle->title() },
            { "class",   handle->appId() },
            { "x",       handle->x() },
            { "y",       handle->y() },
            { "width",   static_cast<int>(handle->width()) },
            { "height",  static_cast<int>(handle->height()) },
            { "fullscreen", handle->isFullscreen() },
            { "maximized",  handle->isMaximized() },
            { "minimized",  handle->isMinimized() },
        };
        newList.append(variant);
        newByAddress.insert(handle->uuid(), variant);
        newAddresses.append(handle->uuid());
        if (handle->isActive()) {
            newActiveWindow = variant;
        }
    }
    m_windowList = newList;
    m_windowByAddress = newByAddress;
    m_addresses = newAddresses;
    emit windowListChanged();
    // Also update active window from the same pass
    if (m_activeWindow != newActiveWindow) {
        m_activeWindow = newActiveWindow;
        emit activeWindowChanged();
    }
}

void HyprlandState::onKWinActiveWindowChanged() {
    // Active window state is derived in onKWinWindowListChanged; nothing more needed here.
}

void HyprlandState::updateWindowList() {

    if (!m_clientsRefresh.isNull()) {
        m_clientsRefresh->close();
    }

    m_clientsRefresh = makeRequestJson("clients", [this](bool success, const QJsonDocument& response) {
        m_clientsRefresh.reset();
        if (!success) {
            m_windowList.clear();
            m_windowByAddress.clear();
            m_addresses.clear();
            emit windowListChanged();
            return;
        }

        const auto clients = response.array();
        QVariantList newList;
        QVariantMap newByAddress;
        QVariantList newAddresses;

        for (const auto& c : clients) {
            const auto obj = c.toObject();
            const auto cls = obj.value("class").toString();
            if (cls.isEmpty() || cls.toLower().contains("quickshell")) {
                continue;
            }
            const auto variant = obj.toVariantMap();
            newList.append(variant);
            const auto addr = obj.value("address").toString();
            newByAddress.insert(addr, variant);
            newAddresses.append(addr);
        }

        m_windowList = newList;
        m_windowByAddress = newByAddress;
        m_addresses = newAddresses;
        emit windowListChanged();
    });
}

void HyprlandState::updateWorkspaces() {
    if (!m_workspacesRefresh.isNull()) {
        m_workspacesRefresh->close();
    }

    m_workspacesRefresh = makeRequestJson("workspaces", [this](bool success, const QJsonDocument& response) {
        m_workspacesRefresh.reset();
        if (!success) {
            m_workspaces.clear();
            m_workspaceById.clear();
            m_workspaceIds.clear();
            emit workspacesChanged();
            return;
        }

        const auto workspaces = response.array();
        QVariantList newList;
        QVariantMap newById;
        QVariantList newIds;

        for (const auto& w : workspaces) {
            const auto obj = w.toObject();
            const auto id = obj.value("id").toInt();
            if (id >= 1 && id <= 100) {
                const auto variant = obj.toVariantMap();
                newList.append(variant);
                newById.insert(QString::number(id), variant);
                newIds.append(id);
            }
        }

        m_workspaces = newList;
        m_workspaceById = newById;
        m_workspaceIds = newIds;
        emit workspacesChanged();
    });
}

void HyprlandState::updateMonitors() {
    if (!m_monitorsRefresh.isNull()) {
        m_monitorsRefresh->close();
    }

    m_monitorsRefresh = makeRequestJson("monitors", [this](bool success, const QJsonDocument& response) {
        m_monitorsRefresh.reset();
        if (success) {
            m_monitors = response.array().toVariantList();
            emit monitorsChanged();
        }
    });
}

void HyprlandState::updateLayers() {
    if (!m_layersRefresh.isNull()) {
        m_layersRefresh->close();
    }

    m_layersRefresh = makeRequestJson("layers", [this](bool success, const QJsonDocument& response) {
        m_layersRefresh.reset();
        if (success) {
            m_layers = response.object().toVariantMap();
            emit layersChanged();
        }
    });
}

void HyprlandState::updateActiveWorkspace() {
    if (!m_activeWorkspaceRefresh.isNull()) {
        m_activeWorkspaceRefresh->close();
    }

    m_activeWorkspaceRefresh = makeRequestJson("activeworkspace", [this](bool success, const QJsonDocument& response) {
        m_activeWorkspaceRefresh.reset();
        if (success) {
            m_activeWorkspace = response.object().toVariantMap();
            emit activeWorkspaceChanged();
        }
    });
}

void HyprlandState::socketError(QLocalSocket::LocalSocketError error) const {
    if (!m_socketValid) {
        qCWarning(lcHyprState) << "socketError: unable to connect to Hyprland event socket:" << error;
    } else {
        qCWarning(lcHyprState) << "socketError: Hyprland event socket error:" << error;
    }
}

void HyprlandState::socketStateChanged(QLocalSocket::LocalSocketState state) {
    if (state == QLocalSocket::UnconnectedState && m_socketValid) {
        qCWarning(lcHyprState) << "socketStateChanged: Hyprland event socket disconnected.";
    }
    m_socketValid = state == QLocalSocket::ConnectedState;
}

void HyprlandState::readEvent() {
    while (true) {
        auto rawEvent = m_socket->readLine();
        if (rawEvent.isEmpty()) {
            break;
        }
        rawEvent.truncate(rawEvent.length() - 1); // Remove trailing \n
        const auto event = QByteArrayView(rawEvent.data(), rawEvent.indexOf(">>"));
        handleEvent(QString::fromUtf8(event));
    }
}

void HyprlandState::handleEvent(const QString& event) {
    // We only care about events that affect our state
    if (event == "openlayer" || event == "closelayer" || event == "screencast") {
        return;
    }

    if (event == "workspace" || event == "createworkspace" || event == "destroyworkspace" || event == "renameworkspace") {
        updateWorkspaces();
        updateActiveWorkspace();
    } else if (event == "activewindow" || event == "activewindowv2" || event == "openwindow" || event == "closewindow" || event == "movewindow" || event == "windowtitle") {
        updateWindowList();
    } else if (event == "monitoradded" || event == "monitorremoved" || event == "focusedmon") {
        updateMonitors();
        updateWorkspaces(); // active workspace on monitor changes
        updateActiveWorkspace();
    } else if (event == "activelayout") {
        // Just in case keyboard layout changes affect anything, but typically they don't affect this state.
    } else {
        // For other events, we can safely update everything to be sure, or just ignore.
        // It's safer to update all for unknown events since there might be overlapping data.
        updateAll();
    }
}

HyprlandState::SocketPtr HyprlandState::makeRequestJson(
    const QString& request, const std::function<void(bool, QJsonDocument)>& callback) {
    return makeRequest("j/" + request, [callback](bool success, const QByteArray& response) {
        callback(success, QJsonDocument::fromJson(response));
    });
}

HyprlandState::SocketPtr HyprlandState::makeRequest(
    const QString& request, const std::function<void(bool, QByteArray)>& callback) {
    if (m_requestSocket.isEmpty()) {
        return SocketPtr();
    }

    auto socket = SocketPtr::create(this);

    QObject::connect(socket.data(), &QLocalSocket::connected, this, [=, this]() {
        QObject::connect(socket.data(), &QLocalSocket::readyRead, this, [socket, callback]() {
            const auto response = socket->readAll();
            callback(true, std::move(response));
            socket->close();
        });

        socket->write(request.toUtf8());
        socket->flush();
    });

    QObject::connect(socket.data(), &QLocalSocket::errorOccurred, this, [=](QLocalSocket::LocalSocketError err) {
        qCWarning(lcHyprState) << "makeRequest: error making request:" << err << "| request:" << request;
        callback(false, {});
        socket->close();
    });

    socket->connectToServer(m_requestSocket);

    return socket;
}

} // namespace caelestia::services
