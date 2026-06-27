#!/usr/bin/env python3
import dbus
import dbus.service
import dbus.mainloop.glib
from gi.repository import GLib
import os, sys, json, subprocess

STATE_FILE = '/tmp/qs_kwin_windows.json'
KWIN_SCRIPT_PATH = os.path.expanduser(
    "~/.local/share/kwin/scripts/quickshell-kde-bridge/contents/code/main.js"
)

class QSKWinBridge(dbus.service.Object):
    def __init__(self, bus, path_name):
        super().__init__(bus, path_name)
        self.windows_json = "[]"
        if os.path.exists(STATE_FILE):
            try:
                with open(STATE_FILE, 'r') as f:
                    self.windows_json = f.read().strip() or "[]"
            except:
                pass
        # Emit cached state immediately so overview shows last-known windows
        print(self.windows_json, flush=True)

    def trigger_kwin_update(self):
        """Reload the KWin bridge script so its initial updateWindows() fires with us on the bus."""
        try:
            bus = dbus.SessionBus()
            scripting = bus.get_object("org.kde.KWin", "/Scripting")
            scripting_iface = dbus.Interface(scripting, "org.kde.kwin.Scripting")
            try:
                scripting_iface.unloadScript("quickshell-kde-bridge")
            except Exception:
                pass
            scripting_iface.loadScript(KWIN_SCRIPT_PATH)
            scripting_iface.start()
        except Exception:
            pass
        return False  # Don't repeat

    @dbus.service.method("org.kde.qs.bridge", in_signature='s', out_signature='')
    def updateWindows(self, win_json):
        # Validate JSON before printing (avoid corrupting the stdout stream)
        try:
            parsed = json.loads(str(win_json))
        except Exception:
            return
        self.windows_json = str(win_json)
        try:
            with open(STATE_FILE, 'w') as f:
                f.write(self.windows_json)
        except:
            pass
        # Print only valid JSON lines — no debug output to stdout
        print(self.windows_json, flush=True)

dbus.mainloop.glib.DBusGMainLoop(set_as_default=True)
session_bus = dbus.SessionBus()
name = dbus.service.BusName("org.kde.qs", session_bus)
bridge = QSKWinBridge(session_bus, '/bridge')

# After 500ms, reload the KWin script so its initial updateWindows() fires with us on the bus
GLib.timeout_add(500, bridge.trigger_kwin_update)

loop = GLib.MainLoop()
loop.run()
