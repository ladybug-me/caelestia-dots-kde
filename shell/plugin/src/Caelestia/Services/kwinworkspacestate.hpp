#pragma once

#include <QObject>
#include <QStringList>
#include <QVariantList>
#include <QVariantMap>
#include <QQmlEngine>
#include <QDBusArgument>

class QLocalServer;

namespace caelestia::services {

struct KWinDesktopData {
    int position;
    QString id;
    QString name;
};

QDBusArgument &operator<<(QDBusArgument &argument, const KWinDesktopData &data);
const QDBusArgument &operator>>(const QDBusArgument &argument, KWinDesktopData &data);

class KWinWorkspaceState : public QObject
{
    Q_OBJECT
    Q_PROPERTY(int activeId READ activeId NOTIFY activeIdChanged)
    /**
     * Current desktop per output name, e.g. { "DP-1": 1, "HDMI-A-2": 3 }.
     *
     * KWin's PerOutputVirtualDesktops gives every screen its own current
     * desktop, but D-Bus still exposes a single VirtualDesktopManager.current,
     * which follows the active output. A per-screen widget reading that shows
     * the focused screen's desktop on every screen, and appears to switch on
     * all of them when the pointer moves. This comes from the workspace-tracker
     * effect instead, which is inside KWin and can ask per output.
     *
     * Empty until the effect connects; fall back to activeId in that case.
     */
    Q_PROPERTY(QVariantMap activeByOutput READ activeByOutput NOTIFY activeByOutputChanged)
    Q_PROPERTY(QVariantList workspaces READ workspaces NOTIFY workspacesChanged)
    Q_PROPERTY(uint rows READ rows NOTIFY rowsChanged)
    Q_PROPERTY(double swipeOffset READ swipeOffset NOTIFY swipeOffsetChanged)
    Q_PROPERTY(bool showingDesktop READ showingDesktop NOTIFY showingDesktopChanged)
    QML_ELEMENT
    QML_SINGLETON

public:
    static KWinWorkspaceState* instance();
    int indexForId(const QString& id) const;
    QString uuidForIndex(int index) const;

    explicit KWinWorkspaceState(QObject *parent = nullptr);
    ~KWinWorkspaceState() override;

    int activeId() const;
    QVariantMap activeByOutput() const;
    QVariantList workspaces() const;
    uint rows() const;
    double swipeOffset() const;
    bool showingDesktop() const;

    /**
     * Switches to desktop @p id. With @p output named, only that screen moves.
     *
     * KWin's D-Bus setter always applies to whichever output is active, which
     * is wrong the moment two screens each have their own desktop and both can
     * ask: a request from one monitor's overview lands on whatever the pointer
     * is over. Naming the output routes it through the workspace-tracker
     * effect, which is inside the compositor and can target it directly.
     */
    Q_INVOKABLE void switchTo(const QString& id, const QString& output = QString());
    Q_INVOKABLE void createWorkspace(const QString& name = QString());
    Q_INVOKABLE void removeWorkspace(const QString& id);

    Q_INVOKABLE void setDesktop(int desktopId);
    Q_INVOKABLE void nextDesktop();
    Q_INVOKABLE void previousDesktop();

signals:
    void activeIdChanged();
    void activeByOutputChanged();
    void workspacesChanged();
    void rowsChanged();
    void swipeOffsetChanged();
    void showingDesktopChanged();

private slots:
    void onDesktopCreated(const QString& id, const caelestia::services::KWinDesktopData& desktopData);
    void onDesktopRemoved(const QString& id);
    void onDesktopDataChanged(const QString& id, const caelestia::services::KWinDesktopData& desktopData);
    void onCurrentChanged(const QString& id);
    void onCountChanged(uint count);
    void onRowsChanged(uint rows);
    void onShowingDesktopChanged(bool showing);
    void onKWinPropertiesChanged(const QString& interface, const QVariantMap& changedProps, const QStringList& invalidatedProps);

private:
    void fetchInitialState();
    void updateActiveId();
    void setupTrackerServer();
    void updateShowingDesktop(bool showing);

    QList<KWinDesktopData> m_desktops;
    QString m_currentUuid;
    int m_activeId = 0;
    QVariantMap m_activeByOutput;
    // -1 unknown, 0 absent, 1 present. See switchTo().
    int m_perOutputSwitchAvailable = -1;
    uint m_rows = 1;
    double m_swipeOffset = 0.0;
    bool m_showingDesktop = false;
    ::QLocalServer* m_trackerServer = nullptr;
};

} // namespace caelestia::services

Q_DECLARE_METATYPE(caelestia::services::KWinDesktopData)

