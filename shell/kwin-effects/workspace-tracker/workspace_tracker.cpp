#include "workspace_tracker.hpp"
#include <QTimer>
#include <KPluginFactory>
#include <QStandardPaths>
#include <QDir>
#include <QDebug>
#include <QStandardPaths>
#include <QDir>

namespace caelestia {

WorkspaceTrackerEffect::WorkspaceTrackerEffect()
    : m_socket(new QLocalSocket(this))
{
    connect(KWin::effects, &KWin::EffectsHandler::desktopChanging,
            this, &WorkspaceTrackerEffect::onDesktopChanging);
    connect(KWin::effects, &KWin::EffectsHandler::desktopChangingCancelled,
            this, &WorkspaceTrackerEffect::onDesktopChangingCancelled);
    connect(KWin::effects, &KWin::EffectsHandler::desktopChanged,
            this, &WorkspaceTrackerEffect::onDesktopChanged);

    connect(m_socket, &QLocalSocket::disconnected, this, [this]() {
        qDebug() << "WorkspaceTracker: Socket disconnected, retrying...";
        QTimer::singleShot(2000, this, &WorkspaceTrackerEffect::connectSocket);
    });

    connect(m_socket, &QLocalSocket::errorOccurred, this, [this](QLocalSocket::LocalSocketError err) {
        qDebug() << "WorkspaceTracker: Socket error:" << err << "- retrying in 2s";
        QTimer::singleShot(2000, this, &WorkspaceTrackerEffect::connectSocket);
    });

    connect(m_socket, &QLocalSocket::connected, this, [this]() {
        qDebug() << "WorkspaceTracker: Socket connected!";
    });

    connectSocket();
}

WorkspaceTrackerEffect::~WorkspaceTrackerEffect()
{
    if (m_socket->isOpen()) {
        m_socket->close();
    }
}

void WorkspaceTrackerEffect::connectSocket()
{
    if (m_socket->state() == QLocalSocket::UnconnectedState) {
        QString socketPath = QStandardPaths::writableLocation(QStandardPaths::RuntimeLocation) + QStringLiteral("/caelestia-workspace-tracker");
        qDebug() << "WorkspaceTracker: Connecting to socket:" << socketPath;
        m_socket->connectToServer(socketPath);
    }
}

void WorkspaceTrackerEffect::sendPayload(int desktop, float x, float y)
{
    if (m_socket->state() == QLocalSocket::ConnectedState) {
        DesktopTransition payload{desktop, x, y};
        m_socket->write(reinterpret_cast<const char*>(&payload), sizeof(payload));
    }
}

void WorkspaceTrackerEffect::onDesktopChanging(KWin::VirtualDesktop* desktop, QPointF offset)
{
    if (desktop && m_socket->state() == QLocalSocket::ConnectedState) {
        qDebug() << "WorkspaceTracker: sending offset" << offset << "for desktop" << desktop->x11DesktopNumber();
        sendPayload(desktop->x11DesktopNumber(), static_cast<float>(offset.x()), static_cast<float>(offset.y()));
    } else {
        qDebug() << "WorkspaceTracker: not connected or desktop is null. Socket state:" << m_socket->state();
    }
}

void WorkspaceTrackerEffect::onDesktopChangingCancelled()
{
    sendPayload(0, 0.0f, 0.0f);
}

void WorkspaceTrackerEffect::onDesktopChanged(KWin::VirtualDesktop* oldDesktop, KWin::VirtualDesktop* newDesktop)
{
    if (newDesktop && m_socket->state() == QLocalSocket::ConnectedState) {
        sendPayload(newDesktop->x11DesktopNumber(), 0.0f, 0.0f);
    }
}

} // namespace caelestia

KWIN_EFFECT_FACTORY(caelestia::WorkspaceTrackerEffect, "kwin_workspace_tracker.json")

#include "workspace_tracker.moc"
