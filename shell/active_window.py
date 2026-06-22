import dbus
import dbus.service
import dbus.mainloop.glib
from gi.repository import GLib
import sys

class ActiveWindowService(dbus.service.Object):
    def __init__(self):
        bus_name = dbus.service.BusName('org.caelestia.ActiveWindow', bus=dbus.SessionBus())
        super().__init__(bus_name, '/ActiveWindow')

    @dbus.service.method('org.caelestia.ActiveWindow', in_signature='s')
    def titleChanged(self, title):
        print(title, flush=True)

dbus.mainloop.glib.DBusGMainLoop(set_as_default=True)
try:
    service = ActiveWindowService()
    GLib.MainLoop().run()
except Exception as e:
    pass
