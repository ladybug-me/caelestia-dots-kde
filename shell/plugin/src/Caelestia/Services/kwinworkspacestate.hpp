#pragma once

#include <QObject>
#include <QVariantList>
#include <QVariantMap>
#include <QQmlEngine>
#include <QtWaylandClient/QWaylandClientExtension>

#include "qwayland-org-kde-plasma-virtual-desktop.h"

namespace caelestia::services {

class KWinDesktop;

class KWinWorkspaceState : public QWaylandClientExtensionTemplate<KWinWorkspaceState>, public QtWayland::org_kde_plasma_virtual_desktop_management
{
    Q_OBJECT
    Q_PROPERTY(int activeId READ activeId NOTIFY activeIdChanged)
    Q_PROPERTY(QVariantList workspaces READ workspaces NOTIFY workspacesChanged)
    QML_ELEMENT
    QML_SINGLETON

public:
    explicit KWinWorkspaceState(QObject *parent = nullptr);
    ~KWinWorkspaceState() override;

    int activeId() const;
    QVariantList workspaces() const;

    Q_INVOKABLE void switchTo(const QString& id);

signals:
    void activeIdChanged();
    void workspacesChanged();

protected:
    void org_kde_plasma_virtual_desktop_management_desktop_created(const QString &desktop_id, uint32_t position) override;
    void org_kde_plasma_virtual_desktop_management_desktop_removed(const QString &desktop_id) override;
    void org_kde_plasma_virtual_desktop_management_done() override;
    void org_kde_plasma_virtual_desktop_management_rows(uint32_t rows) override;

private:
    friend class KWinDesktop;
    void rebuildWorkspaceList();
    void scheduleRebuild();

    QList<KWinDesktop*> m_desktops;
    int m_activeId = 0;
    uint32_t m_rows = 1;
    class QTimer* m_rebuildTimer = nullptr;
};

class KWinDesktop : public QObject, public QtWayland::org_kde_plasma_virtual_desktop
{
    Q_OBJECT
public:
    KWinDesktop(KWinWorkspaceState *manager, struct ::org_kde_plasma_virtual_desktop *desktop, const QString &id, uint32_t position);
    ~KWinDesktop() override;

    QString id() const { return m_id; }
    QString name() const { return m_name; }
    uint32_t position() const { return m_position; }
    bool isActive() const { return m_active; }

protected:
    void org_kde_plasma_virtual_desktop_desktop_id(const QString &desktop_id) override;
    void org_kde_plasma_virtual_desktop_name(const QString &name) override;
    void org_kde_plasma_virtual_desktop_activated() override;
    void org_kde_plasma_virtual_desktop_deactivated() override;
    void org_kde_plasma_virtual_desktop_position(uint32_t position) override;
    void org_kde_plasma_virtual_desktop_done() override;

private:
    KWinWorkspaceState *m_manager;
    QString m_id;
    QString m_name;
    uint32_t m_position = 0;
    bool m_active = false;
};

} // namespace caelestia::services
