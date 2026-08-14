#pragma once

#include <effect/effect.h>
#include <effect/effecthandler.h>
#include <QLocalSocket>
#include <QPointer>
#include <QObject>
#include <QPointF>
#include <kwin/virtualdesktops.h>

namespace caelestia {

struct DesktopTransition {
    int desktop;
    float x;
    float y;
};

class WorkspaceTrackerEffect : public KWin::Effect
{
    Q_OBJECT
public:
    WorkspaceTrackerEffect();
    ~WorkspaceTrackerEffect() override;

private Q_SLOTS:
    void onDesktopChanging(KWin::VirtualDesktop* desktop, QPointF offset);
    void onDesktopChangingCancelled();
    void onDesktopChanged(KWin::VirtualDesktop* oldDesktop, KWin::VirtualDesktop* newDesktop);
    void connectSocket();

private:
    void sendPayload(int desktop, float x, float y);

    QLocalSocket* m_socket;
};

} // namespace caelestia
