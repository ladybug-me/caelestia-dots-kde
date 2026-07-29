#include "kwinworkspacestate.hpp"
#include <QDebug>
#include <QTimer>
#include <algorithm>

namespace caelestia::services {

KWinWorkspaceState::KWinWorkspaceState(QObject* parent)
    : QWaylandClientExtensionTemplate<KWinWorkspaceState>(1) // extension version
{
    initialize(); // Connects to the wayland display globally provided by Qt
}

KWinWorkspaceState::~KWinWorkspaceState() {
    qDeleteAll(m_desktops);
}

int KWinWorkspaceState::activeId() const {
    return m_activeId;
}

QVariantList KWinWorkspaceState::workspaces() const {
    QVariantList list;
    for (int i = 0; i < m_desktops.size(); ++i) {
        auto* d = m_desktops[i];
        if (d->id().isEmpty())
            continue;
        list.append(QVariantMap{ { "id", d->id() },
            { "name", d->name().isEmpty() ? QString::number(i + 1) : d->name() },
            { "index", i + 1 }, { "active", d->isActive() } });
    }
    return list;
}

void KWinWorkspaceState::switchTo(const QString& id) {
    if (!isInitialized())
        return;

    for (auto* d : m_desktops) {
        if (d->id() == id || QString::number(d->position() + 1) == id || d->name() == id) {
            d->request_activate();
            break;
        }
    }
}

void KWinWorkspaceState::rebuildWorkspaceList() {
    // Sort by position
    std::sort(m_desktops.begin(), m_desktops.end(), [](KWinDesktop* a, KWinDesktop* b) {
        return a->position() < b->position();
    });

    // Find active using contiguous index to match KWin's array index
    for (int i = 0; i < m_desktops.size(); ++i) {
        if (m_desktops[i]->isActive()) {
            if (m_activeId != i + 1) {
                m_activeId = i + 1;
                emit activeIdChanged();
            }
            break;
        }
    }

    emit workspacesChanged();
}

void KWinWorkspaceState::scheduleRebuild() {
    if (!m_rebuildTimer) {
        m_rebuildTimer = new QTimer(this);
        m_rebuildTimer->setSingleShot(true);
        m_rebuildTimer->setInterval(20);
        connect(m_rebuildTimer, &QTimer::timeout, this, &KWinWorkspaceState::rebuildWorkspaceList);
    }
    m_rebuildTimer->start();
}

void KWinWorkspaceState::org_kde_plasma_virtual_desktop_management_desktop_created(
    const QString& desktop_id, uint32_t position) {
    if (desktop_id.isEmpty())
        return;

    for (auto* d : m_desktops) {
        if (d->id() == desktop_id)
            return;
    }

    auto* handle = get_virtual_desktop(desktop_id);
    if (!handle)
        return;

    auto* desktop = new KWinDesktop(this, handle, desktop_id, position);
    m_desktops.append(desktop);
}

void KWinWorkspaceState::org_kde_plasma_virtual_desktop_management_desktop_removed(const QString& desktop_id) {
    for (int i = 0; i < m_desktops.size(); ++i) {
        if (m_desktops[i]->id() == desktop_id) {
            delete m_desktops.takeAt(i);
            break;
        }
    }
    // Safety fallback timer: rebuild workspace list after all possible position events
    scheduleRebuild();
}

void KWinWorkspaceState::org_kde_plasma_virtual_desktop_management_done() {
    scheduleRebuild();
}

void KWinWorkspaceState::org_kde_plasma_virtual_desktop_management_rows(uint32_t rows) {
    if (rows > 0)
        m_rows = rows;
}

KWinDesktop::KWinDesktop(
    KWinWorkspaceState* manager, struct ::org_kde_plasma_virtual_desktop* desktop, const QString& id, uint32_t position)
    : QObject(manager)
    , QtWayland::org_kde_plasma_virtual_desktop(desktop)
    , m_manager(manager)
    , m_id(id)
    , m_position(position) {}

KWinDesktop::~KWinDesktop() = default;

void KWinDesktop::org_kde_plasma_virtual_desktop_desktop_id(const QString& desktop_id) {
    m_id = desktop_id;
}

void KWinDesktop::org_kde_plasma_virtual_desktop_name(const QString& name) {
    m_name = name;
}

void KWinDesktop::org_kde_plasma_virtual_desktop_activated() {
    m_active = true;
}

void KWinDesktop::org_kde_plasma_virtual_desktop_deactivated() {
    m_active = false;
}

void KWinDesktop::org_kde_plasma_virtual_desktop_position(uint32_t position) {
    m_position = position;
}

void KWinDesktop::org_kde_plasma_virtual_desktop_done() {
    // Management-level done handles rebuilding after all positions are updated.
    // Per-desktop done only fires after this desktop's own state is set,
    // but other desktops may not have received their position updates yet.
    m_manager->scheduleRebuild();
}

} // namespace caelestia::services
