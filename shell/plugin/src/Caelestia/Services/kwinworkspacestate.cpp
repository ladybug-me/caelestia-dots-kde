#include "kwinworkspacestate.hpp"
#include <QDebug>
#include <QDBusConnection>
#include <QDBusMessage>
#include <QDBusReply>
#include <QDBusInterface>
#include <QDBusMetaType>
#include <algorithm>

namespace caelestia::services {

QDBusArgument &operator<<(QDBusArgument &argument, const KWinDesktopData &data) {
    argument.beginStructure();
    argument << data.position << data.id << data.name;
    argument.endStructure();
    return argument;
}

const QDBusArgument &operator>>(const QDBusArgument &argument, KWinDesktopData &data) {
    argument.beginStructure();
    argument >> data.position >> data.id >> data.name;
    argument.endStructure();
    return argument;
}

KWinWorkspaceState::KWinWorkspaceState(QObject* parent)
    : QObject(parent)
{
    qDBusRegisterMetaType<KWinDesktopData>();
    qDBusRegisterMetaType<QList<KWinDesktopData>>();

    QDBusConnection bus = QDBusConnection::sessionBus();
    bus.connect("org.kde.KWin", "/VirtualDesktopManager", "org.kde.KWin.VirtualDesktopManager", "desktopCreated",
                this, SLOT(onDesktopCreated(QString, caelestia::services::KWinDesktopData)));
    bus.connect("org.kde.KWin", "/VirtualDesktopManager", "org.kde.KWin.VirtualDesktopManager", "desktopRemoved",
                this, SLOT(onDesktopRemoved(QString)));
    bus.connect("org.kde.KWin", "/VirtualDesktopManager", "org.kde.KWin.VirtualDesktopManager", "desktopDataChanged",
                this, SLOT(onDesktopDataChanged(QString, caelestia::services::KWinDesktopData)));
    bus.connect("org.kde.KWin", "/VirtualDesktopManager", "org.kde.KWin.VirtualDesktopManager", "currentChanged",
                this, SLOT(onCurrentChanged(QString)));
    bus.connect("org.kde.KWin", "/VirtualDesktopManager", "org.kde.KWin.VirtualDesktopManager", "countChanged",
                this, SLOT(onCountChanged(uint)));
    bus.connect("org.kde.KWin", "/VirtualDesktopManager", "org.kde.KWin.VirtualDesktopManager", "rowsChanged",
                this, SLOT(onRowsChanged(uint)));

    fetchInitialState();
}

KWinWorkspaceState::~KWinWorkspaceState() = default;

void KWinWorkspaceState::fetchInitialState() {
    QDBusMessage msg = QDBusMessage::createMethodCall("org.kde.KWin", "/VirtualDesktopManager", "org.freedesktop.DBus.Properties", "Get");
    msg << "org.kde.KWin.VirtualDesktopManager" << "desktops";
    QDBusReply<QDBusVariant> reply = QDBusConnection::sessionBus().call(msg);
    
    if (reply.isValid()) {
        QVariant var = reply.value().variant();
        if (var.canConvert<QDBusArgument>()) {
            QDBusArgument arg = var.value<QDBusArgument>();
            arg >> m_desktops;
        }
    }

    QDBusMessage currentMsg = QDBusMessage::createMethodCall("org.kde.KWin", "/VirtualDesktopManager", "org.freedesktop.DBus.Properties", "Get");
    currentMsg << "org.kde.KWin.VirtualDesktopManager" << "current";
    QDBusReply<QDBusVariant> currentReply = QDBusConnection::sessionBus().call(currentMsg);
    
    if (currentReply.isValid()) {
        m_currentUuid = currentReply.value().variant().toString();
    }

    updateActiveId();
}

void KWinWorkspaceState::updateActiveId() {
    std::sort(m_desktops.begin(), m_desktops.end(), [](const KWinDesktopData& a, const KWinDesktopData& b) {
        return a.position < b.position;
    });

    int newActiveId = 1;
    for (int i = 0; i < m_desktops.size(); ++i) {
        if (m_desktops[i].id == m_currentUuid) {
            newActiveId = i + 1;
            break;
        }
    }

    if (m_activeId != newActiveId) {
        m_activeId = newActiveId;
        emit activeIdChanged();
    }

    emit workspacesChanged();
}

int KWinWorkspaceState::activeId() const {
    return m_activeId;
}

QVariantList KWinWorkspaceState::workspaces() const {
    QVariantList list;
    for (int i = 0; i < m_desktops.size(); ++i) {
        const auto& d = m_desktops[i];
        if (d.id.isEmpty())
            continue;
        list.append(QVariantMap{
            { "id", d.id },
            { "name", d.name.isEmpty() ? QString::number(i + 1) : d.name },
            { "index", i + 1 },
            { "active", (d.id == m_currentUuid) }
        });
    }
    return list;
}

void KWinWorkspaceState::switchTo(const QString& id) {
    QString targetUuid;
    for (const auto& d : m_desktops) {
        if (d.id == id || QString::number(d.position + 1) == id || d.name == id) {
            targetUuid = d.id;
            break;
        }
    }
    
    if (!targetUuid.isEmpty()) {
        QDBusMessage msg = QDBusMessage::createMethodCall("org.kde.KWin", "/VirtualDesktopManager", "org.freedesktop.DBus.Properties", "Set");
        msg << "org.kde.KWin.VirtualDesktopManager" << "current" << QVariant::fromValue(QDBusVariant(targetUuid));
        QDBusConnection::sessionBus().call(msg, QDBus::NoBlock);
    }
}

void KWinWorkspaceState::createWorkspace(const QString& name) {
    QDBusMessage msg = QDBusMessage::createMethodCall("org.kde.KWin", "/VirtualDesktopManager", "org.kde.KWin.VirtualDesktopManager", "createDesktop");
    msg << std::numeric_limits<uint32_t>::max() << name;
    QDBusConnection::sessionBus().call(msg, QDBus::NoBlock);
}

void KWinWorkspaceState::removeWorkspace(const QString& id) {
    QString targetUuid = id;
    for (const auto& d : m_desktops) {
        if (d.id == id || QString::number(d.position + 1) == id || d.name == id) {
            targetUuid = d.id;
            break;
        }
    }
    
    if (!targetUuid.isEmpty()) {
        QDBusMessage msg = QDBusMessage::createMethodCall("org.kde.KWin", "/VirtualDesktopManager", "org.kde.KWin.VirtualDesktopManager", "removeDesktop");
        msg << targetUuid;
        QDBusConnection::sessionBus().call(msg, QDBus::NoBlock);
    }
}

void KWinWorkspaceState::onDesktopCreated(const QString& id, const caelestia::services::KWinDesktopData& desktopData) {
    bool exists = false;
    for (auto& d : m_desktops) {
        if (d.id == id) {
            d = desktopData;
            exists = true;
            break;
        }
    }
    if (!exists) {
        m_desktops.append(desktopData);
    }
    updateActiveId();
}

void KWinWorkspaceState::onDesktopRemoved(const QString& id) {
    for (int i = 0; i < m_desktops.size(); ++i) {
        if (m_desktops[i].id == id) {
            m_desktops.removeAt(i);
            break;
        }
    }
    updateActiveId();
}

void KWinWorkspaceState::onDesktopDataChanged(const QString& id, const caelestia::services::KWinDesktopData& desktopData) {
    for (auto& d : m_desktops) {
        if (d.id == id) {
            d = desktopData;
            break;
        }
    }
    updateActiveId();
}

void KWinWorkspaceState::onCurrentChanged(const QString& id) {
    m_currentUuid = id;
    updateActiveId();
}

void KWinWorkspaceState::onCountChanged(uint count) {
    // Rely on desktopCreated / desktopRemoved for actual data
}

void KWinWorkspaceState::onRowsChanged(uint rows) {
    if (rows > 0)
        m_rows = rows;
}

} // namespace caelestia::services
