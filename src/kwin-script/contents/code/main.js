console.info("Quickshell KDE Bridge script starting...");
function updateWindows() {
    let wins = workspace.windowList();
    let result = [];
    for (let i = 0; i < wins.length; ++i) {
        let w = wins[i];
        if (w.normalWindow) {
            let desktopId = 0;
            if (w.desktops && w.desktops.length > 0) {
                // In KWin 6, desktop might have an x11DesktopNumber or similar
                // We'll just grab the id if it has one, or assume desktop sequence
                desktopId = w.desktops[0].x11DesktopNumber || 1;
            }
            result.push({
                title: w.caption,
                class: w.resourceClass,
                workspace: { id: desktopId },
                at: [w.frameGeometry ? w.frameGeometry.x : 0, w.frameGeometry ? w.frameGeometry.y : 0],
                size: [w.frameGeometry ? w.frameGeometry.width : 0, w.frameGeometry ? w.frameGeometry.height : 0],
                internalId: w.internalId.toString(),
                floating: !w.tile,
                fullscreen: w.fullScreen,
                xwayland: w.xwayland
            });
        }
    }
    callDBus("org.kde.qs", "/bridge", "org.kde.qs.bridge", "updateWindows", JSON.stringify(result));
}

workspace.windowAdded.connect((w) => {
    try { w.frameGeometryChanged.connect(updateWindows); } catch(e) {}
    try { w.desktopsChanged.connect(updateWindows); } catch(e) {}
    try { w.desktopChanged.connect(updateWindows); } catch(e) {}
    updateWindows();
});
workspace.windowRemoved.connect(updateWindows);
workspace.windowActivated.connect(updateWindows);
try { workspace.currentDesktopChanged.connect(updateWindows); } catch(e) {}

// Initial connect to existing windows
let wins = workspace.windowList();
for (let i = 0; i < wins.length; ++i) {
    let w = wins[i];
    try { w.frameGeometryChanged.connect(updateWindows); } catch(e) {}
    try { w.desktopsChanged.connect(updateWindows); } catch(e) {}
    try { w.desktopChanged.connect(updateWindows); } catch(e) {}
}

// Initial update
updateWindows();

// Initial update
updateWindows();
