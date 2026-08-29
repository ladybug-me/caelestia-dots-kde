#pragma once

#include <effect/effect.h>
#include <effect/effecthandler.h>
#include <QLocalSocket>
#include <QPointer>
#include <QObject>
#include <QPointF>
#include <kwin/virtualdesktops.h>

namespace caelestia {

// Reported to the shell over the local socket.
//
// The original record was three fields and said nothing about which screen it
// described, which was fine while KWin had one current desktop for the whole
// session. With PerOutputVirtualDesktops each screen has its own, so a report
// that omits the output is not just incomplete -- it is wrong on every screen
// but the one it came from.
//
// magic exists so the shell can tell this apart from the old 12-byte record: a
// stale effect can outlive a shell update, because a rebuilt effect does not
// load until the session restarts. The first field of the old record was a
// small desktop number, so it can never collide.
struct DesktopReport {
    static constexpr quint32 kMagic = 0x43414557; // 'CAEW'

    quint32 magic = kMagic;
    qint32 desktop = 0;
    float x = 0.0f;
    float y = 0.0f;
    char output[64] = {};
};

class WorkspaceTrackerEffect : public KWin::Effect
{
    Q_OBJECT
    Q_CLASSINFO("D-Bus Interface", "org.caelestia.Workspaces")
public:
    WorkspaceTrackerEffect();
    ~WorkspaceTrackerEffect() override;

public Q_SLOTS:
    /**
     * Switches @p output to virtual desktop @p desktop, counting from 1.
     *
     * KWin's D-Bus only exposes VirtualDesktopManager.current, and setting it
     * always applies to whichever output is active. That is unusable once each
     * screen has its own desktop and more than one thing wants to switch: a
     * request meant for one monitor lands on whichever the pointer happens to
     * be over. Inside the compositor the output can simply be named.
     */
    void SetDesktop(const QString& output, int desktop);

private Q_SLOTS:
    void onDesktopChanging(KWin::VirtualDesktop* desktop, QPointF offset, KWin::EffectWindow* with, KWin::LogicalOutput* output);
    void onDesktopChangingCancelled();
    void onDesktopChanged(KWin::VirtualDesktop* oldDesktop, KWin::VirtualDesktop* newDesktop, KWin::EffectWindow* with, KWin::LogicalOutput* output);
    void connectSocket();

private:
    void sendPayload(int desktop, float x, float y, KWin::LogicalOutput* output);
    /// Reports every output's current desktop, so a shell that just connected
    /// starts from the truth instead of waiting for someone to switch.
    void sendFullState();
    static KWin::LogicalOutput* findOutput(const QString& name);

    QLocalSocket* m_socket;
};

} // namespace caelestia
