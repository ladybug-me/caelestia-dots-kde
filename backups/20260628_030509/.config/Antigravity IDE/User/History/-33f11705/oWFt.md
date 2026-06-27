# Known Issues & Workarounds

> The Caelestia KDE v2.0.0 is still under development. Kindly use Caelestia v1.0.0 for a stable experience.
## 🚧 Currently Not Working

### Trackpad Gestures

Multi-touch trackpad gestures are not yet supported.

**Workaround**

* Configure gestures using external tools such as `libinput-gestures`, `ydotool`, or compositor-specific plugins (where available).
* On KDE Wayland, gesture customization is currently limited.

---

### Default Application Configuration

Changing default applications from the configuration UI is currently incomplete.

**Workaround**

* Edit the generated configuration manually.
* Modify the config generator if you want changes to persist after regeneration.

---

### Media Player Integration

Some media players may not expose playback information correctly, causing widgets to remain empty or controls to fail.

**Workaround**

* Use players that implement the MPRIS interface (e.g. VLC, MPV, Elisa, Spotify).

---

### Brightness Keys

Brightness keys may not work correctly when intercepted by tools like `keyd`.

**Workaround**

* Disable `keyd` for brightness keys.
* Let KDE handle brightness controls directly.
* Verify the keycodes using `evtest` or `libinput debug-events`.

---

### Global Hotkeys

Some global shortcuts can conflict with KDE's own shortcut system.

**Workaround**

* Remove conflicting KDE shortcuts.
* Use dedicated hotkey daemons such as `swhkd` or `keyd` where appropriate.

---

## ⚠️ Limitations

* The shell currently targets **KDE Plasma** and is not guaranteed to work on other desktop environments.
* Some features depend on optional third-party utilities being installed.
* Configuration formats may change until the project reaches a stable release.

---

## 💡 Reporting Issues

If you encounter a bug that is not listed here, please open an issue with:

* Your distribution and version
* KDE Plasma version
* Quickshell version
* Steps to reproduce the problem
* Relevant logs or screenshots
