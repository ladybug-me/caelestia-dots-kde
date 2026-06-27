#!/usr/bin/env python3
import sys
import json
import os
import configparser

def get_friendly_category(section, description):
    if section == "kwin":
        if "Window" in description or "Desktop" in description:
            return "Window"
        return "System"
    elif section == "plasmashell":
        return "Plasma"
    elif "dolphin" in section:
        return "File Manager"
    elif "konsole" in section or "kitty" in section:
        return "Terminal"
    return section.capitalize()

# def parse_kglobalshortcutsrc():
#     path = os.path.expanduser("~/.config/kglobalshortcutsrc")
#     if not os.path.exists(path):
#         return []
    
#     config = configparser.ConfigParser(interpolation=None)
#     config.optionxform = str
#     try:
#         config.read(path)
#     except Exception:
#         return []

#     mod_map = {
#         "Shift": 1,
#         "Ctrl": 4,
#         "Alt": 8,
#         "Meta": 64
#     }
    
#     binds = []
    
#     for section in config.sections():
#         for key, value in config.items(section):
#             parts = value.split(',')
#             if len(parts) >= 3:
#                 shortcut = parts[0]
#                 description = parts[2]
                
#                 if shortcut and shortcut != "none":
#                     keys = shortcut.split('+')
#                     modmask = 0
#                     actual_key = ""
#                     for k in keys:
#                         if k in mod_map:
#                             modmask |= mod_map[k]
#                         else:
#                             actual_key = k
                    
#                     if actual_key:
#                         category = get_friendly_category(section, description)
#                         command = f"qdbus6 org.kde.kglobalaccel /component/{section} invokeShortcut '{key}'"
#                         binds.append({
#                             "description": f"{category}: {description}",
#                             "modmask": modmask,
#                             "key": actual_key.upper(),
#                             "command": command
#                         })
#     return binds

def parse_keyd():
    path = "/etc/keyd/quickshell.conf"
    if not os.path.exists(path):
        # Fallback to local quickshell.conf for testing/if not system-wide yet
        fallback = os.path.expanduser("~/.config/quickshell/quickshell.conf")
        if os.path.exists(fallback):
            path = fallback
        else:
            return []
        
    binds = []
    mod_map = {
        "shift": 1,
        "control": 4,
        "alt": 8,
        "meta": 64
    }
    
    try:
        current_modmask = 0
        with open(path, 'r') as f:
            for line in f:
                line = line.strip()
                if not line or line.startswith('#') or line == "[ids]" or line == "*":
                    continue
                if line.startswith('['):
                    sec = line[1:-1].lower()
                    current_modmask = 0
                    if sec == "main":
                        continue
                    for mod in sec.split('+'):
                        if mod in mod_map:
                            current_modmask |= mod_map[mod]
                    continue
                
                if '=' in line:
                    k, v = line.split('=', 1)
                    k = k.strip()
                    v = v.strip()
                    
                    actual_key = k
                    if actual_key == "sysrq":
                        actual_key = "Print"
                    elif actual_key == "playpause":
                        actual_key = "XF86AudioPlay"
                    elif actual_key == "nextsong":
                        actual_key = "XF86AudioNext"
                    elif actual_key == "previoussong":
                        actual_key = "XF86AudioPrev"
                    elif actual_key == "mute":
                        actual_key = "XF86AudioMute"
                    elif actual_key == "micmute":
                        actual_key = "XF86AudioMicMute"
                    elif actual_key == "volumedown":
                        actual_key = "XF86AudioLowerVolume"
                    elif actual_key == "volumeup":
                        actual_key = "XF86AudioRaiseVolume"
                    elif actual_key == "brightnessdown":
                        actual_key = "XF86MonBrightnessDown"
                    elif actual_key == "brightnessup":
                        actual_key = "XF86MonBrightnessUp"
                    else:
                        actual_key = actual_key.capitalize()

                    modmask = current_modmask

                    desc = "Custom shortcut"
                    category = "Keyd"
                    
                    if "kstart -- foot" in v:
                        category, desc = "App", "Terminal: Foot"
                    elif "kstart -- firefox" in v:
                        category, desc = "App", "Browser"
                    elif "kstart -- code" in v:
                        category, desc = "App", "Code editor"
                    elif "kstart -- github-desktop" in v:
                        category, desc = "App", "GitHub desktop"
                    elif "kstart -- nemo" in v:
                        category, desc = "App", "File manager: Nemo"
                    elif "qdbus6 org.kde.KWin /KWin org.kde.KWin.setCurrentDesktop" in v:
                        category, desc = "Window", "Change workspace"
                    elif "wpctl set-mute @DEFAULT_AUDIO_SOURCE@" in v:
                        category, desc = "Media", "Toggle mic"
                    elif "wpctl set-mute @DEFAULT_AUDIO_SINK@" in v:
                        category, desc = "Media", "Toggle mute"
                    elif "wpctl set-volume -l 1.5 @DEFAULT_AUDIO_SINK@ 5%-" in v:
                        category, desc = "Volume", "Down"
                    elif "wpctl set-volume -l 1.5 @DEFAULT_AUDIO_SINK@ 5%+" in v:
                        category, desc = "Volume", "Up"
                    elif "systemctl suspend-then-hibernate" in v:
                        category, desc = "Session", "Suspend then hibernate"
                    elif "caelestia shell drawers toggle session" in v:
                        category, desc = "Shell", "Toggle session menu"
                    elif "caelestia shell drawers toggle launcher" in v:
                        category, desc = "Shell", "Toggle launcher"
                    elif "caelestia clipboard" in v:
                        category, desc = "Shell", "Open clipboard"
                    elif "caelestia emoji -p" in v:
                        category, desc = "Utilities", "Emoji picker"
                    elif "caelestia shell shortcuts open" in v:
                        category, desc = "Shell", "Show shortcuts"
                    elif "caelestia shell drawers toggle screenshot" in v:
                        category, desc = "Shell", "Toggle screenshot"
                    elif "caelestia screenshot -f" in v:
                        category, desc = "Utilities", "Screenshot"
                    elif "kcolorpicker -a" in v:
                        category, desc = "Utilities", "Pick color #RRGGBB >> clipboard"
                    elif "caelestia shell region search" in v:
                        category, desc = "Shell", "Google Lens"
                    elif "caelestia shell drawers toggle sidebar" in v:
                        category, desc = "Shell", "Toggle sidebar"
                        
                    binds.append({
                        "description": f"{category}: {desc}",
                        "modmask": modmask,
                        "key": actual_key,
                        "command": v
                    })
    except Exception:
        pass
    return binds

if __name__ == "__main__":
    if len(sys.argv) >= 3 and sys.argv[1] == "binds" and sys.argv[2] == "-j":
        binds = parse_keyd() #+ parse_kglobalshortcutsrc()
        print(json.dumps(binds, indent=2))
    elif len(sys.argv) >= 3 and sys.argv[1] == "monitors" and sys.argv[2] == "-j":
        try:
            import subprocess
            out = subprocess.check_output(["kscreen-doctor", "-j"], text=True)
            k_data = json.loads(out)
            monitors = []
            for o in k_data.get("outputs", []):
                if not o.get("enabled", False): continue
                mode = next((m for m in o.get("modes", []) if m["id"] == o.get("currentModeId")), None)
                w = mode["size"]["width"] if mode else 1920
                h = mode["size"]["height"] if mode else 1080
                rr = mode["refreshRate"] if mode else 60.0
                monitors.append({
                    "id": o.get("id", 0),
                    "name": o.get("name", "Unknown"),
                    "description": o.get("name", "Unknown"),
                    "width": w,
                    "height": h,
                    "refreshRate": rr,
                    "x": o.get("pos", {}).get("x", 0),
                    "y": o.get("pos", {}).get("y", 0),
                    "activeWorkspace": {"id": 1, "name": "1"},
                    "specialWorkspace": {"id": 0, "name": ""},
                    "reserved": [0,0,0,0],
                    "scale": o.get("scale", 1.0),
                    "transform": 0,
                    "focused": False,
                    "dpmsStatus": True,
                    "vrr": False
                })
            try:
                active_output = subprocess.check_output(["qdbus6", "org.kde.KWin", "/KWin", "org.kde.KWin.activeOutputName"], text=True).strip()
            except Exception:
                active_output = None
                
            focused_set = False
            for m in monitors:
                if active_output and m["name"] == active_output:
                    m["focused"] = True
                    focused_set = True
                    
            if monitors and not focused_set:
                monitors[0]["focused"] = True
                
            print(json.dumps(monitors, indent=2))
        except Exception:
            print("[]")
    elif len(sys.argv) >= 3 and sys.argv[1] == "workspaces" and sys.argv[2] == "-j":
        print("[]")
    elif len(sys.argv) >= 3 and sys.argv[1] == "activeworkspace" and sys.argv[2] == "-j":
        print('{"id": 1}')
    elif len(sys.argv) >= 3 and sys.argv[1] == "clients" and sys.argv[2] == "-j":
        try:
            with open('/tmp/qs_kwin_windows.json', 'r') as f:
                print(f.read())
        except Exception:
            print("[]")
    elif len(sys.argv) >= 3 and sys.argv[1] == "layers" and sys.argv[2] == "-j":
        print("{}")
    elif len(sys.argv) >= 3 and sys.argv[1] == "cursorpos" and sys.argv[2] == "-j":
        print('{"x": 0, "y": 0}')
    elif len(sys.argv) >= 4 and sys.argv[1] == "-j" and sys.argv[2] == "getoption" and sys.argv[3] == "input:kb_layout":
        print('{"str": "us"}')
    elif len(sys.argv) >= 3 and sys.argv[1] == "-j" and sys.argv[2] == "devices":
        print('{"keyboards": []}')
    elif len(sys.argv) >= 2 and sys.argv[1] == "splash":
        print("Caelestia on KDE Plasma")
    elif len(sys.argv) >= 2 and sys.argv[1] in ["dispatch", "reload", "switchxkblayout"]:
        if sys.argv[1] == "dispatch" and len(sys.argv) >= 4:
            cmd = sys.argv[2]
            arg = sys.argv[3]
            if cmd in ["focuswindow", "closewindow"] and arg.startswith("address:0x"):
                internalId = arg[10:]
                action = "workspace.activeWindow = wins[i];" if cmd == "focuswindow" else "wins[i].closeWindow();"
                script_content = f"""
let wins = workspace.windowList();
for (let i = 0; i < wins.length; ++i) {{
    if (wins[i].internalId && wins[i].internalId.toString() === "{internalId}") {{
        {action}
        break;
    }}
}}
"""
                import subprocess, tempfile, os
                with tempfile.NamedTemporaryFile(mode='w', delete=False, suffix='.js') as f:
                    f.write(script_content)
                    temp_path = f.name
                subprocess.run(["qdbus6", "org.kde.KWin", "/Scripting", "org.kde.kwin.Scripting.loadScript", temp_path, "qs-action-temp"], capture_output=True)
                subprocess.run(["qdbus6", "org.kde.KWin", "/Scripting", "org.kde.kwin.Scripting.start"], capture_output=True)
                subprocess.run(["qdbus6", "org.kde.KWin", "/Scripting", "org.kde.kwin.Scripting.unloadScript", "qs-action-temp"], capture_output=True)
                os.remove(temp_path)
    else:
        print("Mock hyprctl (Python KDE+Keyd bridge)")
