console.info("Quickshell KDE Bridge script starting...");
function updateWindows() {
    let wins = workspace.windowList();
    console.info("Quickshell: found " + wins.length + " windows");
    let result = [];
    for (let i = 0; i < wins.length; ++i) {
        let w = wins[i];
        if (w.normalWindow) {
            let desktopId = 0;
            if (w.desktops && w.desktops.length > 0) {
                desktopId = w.desktops[0].x11DesktopNumber || 1;
            }
            result.push({
                title: w.caption,
                class: w.resourceClass,
                workspace: { id: desktopId },
                at: [w.frameGeometry ? w.frameGeometry.x : 0, w.frameGeometry ? w.frameGeometry.y : 0],
                size: [w.frameGeometry ? w.frameGeometry.width : 0, w.frameGeometry ? w.frameGeometry.height : 0],
                internalId: w.internalId ? w.internalId.toString() : i.toString(),
                address: w.internalId ? w.internalId.toString() : i.toString(),
                floating: !w.tile,
                fullscreen: w.fullScreen,
                xwayland: w.xwayland,
                focused: (workspace.activeWindow === w)
            });
        }
    }
    callDBus("org.kde.qs", "/bridge", "org.kde.qs.bridge", "updateWindows", JSON.stringify(result));
}
workspace.windowAdded.connect(updateWindows);
workspace.windowRemoved.connect(updateWindows);
workspace.windowActivated.connect(updateWindows);
updateWindows();
