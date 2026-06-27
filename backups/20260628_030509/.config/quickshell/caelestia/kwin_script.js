function broadcastActiveWindow() {
    var win = workspace.activeWindow;
    if (win) {
        callDBus("org.caelestia.ActiveWindow", "/ActiveWindow", "org.caelestia.ActiveWindow", "titleChanged", win.caption || "Desktop");
    } else {
        callDBus("org.caelestia.ActiveWindow", "/ActiveWindow", "org.caelestia.ActiveWindow", "titleChanged", "Desktop");
    }
}
workspace.windowActivated.connect(broadcastActiveWindow);
broadcastActiveWindow();
