#!/usr/bin/env bash

set -uo pipefail

CYAN="\033[0;36m"
GREEN="\033[0;32m"
YELLOW="\033[38;5;220m"
RED="\033[0;31m"
RST="\033[0m"

info() { echo -e "${CYAN}[INFO]  $*${RST}"; }
ok()   { echo -e "${GREEN}[OK]    $*${RST}"; }
warn() { echo -e "${YELLOW}[WARN]  $*${RST}"; }
err()  { echo -e "${RED}[ERR]   $*${RST}"; }

BUNDLE_DIR="${BUNDLE_DIR:-$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)}"
SHELL_DIR="$BUNDLE_DIR/shell"

missing_tools=()
missing_pkg_modules=()

require_command() {
    local name="$1"
    if ! command -v "$name" >/dev/null 2>&1; then
        missing_tools+=("$name")
    fi
}

require_pkg_module() {
    local module="$1"
    if ! pkg-config --exists "$module" >/dev/null 2>&1; then
        missing_pkg_modules+=("$module")
    fi
}

require_alt_pkg_module() {
    local primary="$1"
    local fallback="$2"
    if pkg-config --exists "$primary" >/dev/null 2>&1; then
        return 0
    fi
    if pkg-config --exists "$fallback" >/dev/null 2>&1; then
        return 0
    fi
    missing_pkg_modules+=("$primary or $fallback")
}

require_sensors_support() {
    if pkg-config --exists sensors >/dev/null 2>&1; then
        return 0
    fi
    if pkg-config --exists libsensors >/dev/null 2>&1; then
        return 0
    fi
    if [[ -f /usr/include/sensors/sensors.h || -f /usr/local/include/sensors/sensors.h ]]; then
        return 0
    fi
    missing_pkg_modules+=("sensors/libsensors (or lm_sensors development headers)")
}

require_command cmake
require_command pkg-config
require_command make
require_command git
require_command nproc

if command -v pkg-config >/dev/null 2>&1; then
    require_pkg_module Qt6Core
    require_pkg_module Qt6Gui
    require_pkg_module Qt6Qml
    require_pkg_module Qt6Quick
    require_pkg_module Qt6QuickControls2
    require_pkg_module Qt6Concurrent
    require_pkg_module Qt6Sql
    require_pkg_module Qt6Network
    require_pkg_module Qt6DBus
    require_pkg_module Qt6ShaderTools
    require_pkg_module Qt6WaylandClient
    require_pkg_module Qt6Widgets
    require_pkg_module libqalculate
    require_pkg_module libpipewire-0.3
    require_pkg_module aubio
    require_alt_pkg_module libcava cava
    require_sensors_support
fi

if (( ${#missing_tools[@]} > 0 || ${#missing_pkg_modules[@]} > 0 )); then
    if (( ${#missing_tools[@]} > 0 )); then
        err "Missing required tools: ${missing_tools[*]}"
    fi
    if (( ${#missing_pkg_modules[@]} > 0 )); then
        err "Missing required pkg-config modules: ${missing_pkg_modules[*]}"
    fi
    exit 1
fi


# UPDATER ONLY BLOCK START

# This is a temp fix, BREAKS REVERTING TO OLDER VERSIONS
# ANYTHING EXTRA THAT NEEDS TO BE INSTALLED WHEN MAJOR CHANGES HAPPEN,
# RUN THE REQUIRED UPDATE

if [[ "${CAELESTIA_SETUP_RUNNING:-0}" == "0" ]]; then
    info "Running standalone update mode... deploying services first."
    if [[ -f "$BUNDLE_DIR/scripts/06-services.sh" ]]; then
        bash "$BUNDLE_DIR/scripts/06-services.sh" || warn "06-services.sh failed"
    fi

    info "Installing plasma-wallpaper-application"
    if [[ -d "$BUNDLE_DIR/src/plasma-wallpaper-application/package" ]]; then
        kpackagetool6 -t Plasma/Wallpaper -i "$BUNDLE_DIR/src/plasma-wallpaper-application/package" >/dev/null 2>&1 || kpackagetool6 -t Plasma/Wallpaper -u "$BUNDLE_DIR/src/plasma-wallpaper-application/package" || warn "plasma-wallpaper-application installation failed"
    else
        warn "plasma-wallpaper-application not found, Skipping installation"
    fi

    info "Installing qt6-wayland if missing..."
    if command -v pacman >/dev/null; then
        info "Installing via pacman..."
        sudo pacman -S --needed qt6-wayland --noconfirm || warn "qt6-wayland install failed..."
    elif command -v dnf >/dev/null; then
        info "Installing via dnf..."
        sudo dnf install --needed qt6-qtwayland -y || warn "qt6-qtwayland install failed..."
    fi
    
    if [[ "${CAELESTIA_SKIP_DEPLOY:-0}" == "0" ]]; then
        info "Configuring KDE Lock Screen to use Caelestia..."
        if command -v kwriteconfig6 >/dev/null 2>&1 && command -v kpackagetool6 >/dev/null 2>&1; then
            if kpackagetool6 --list -t Plasma/Wallpaper 2>/dev/null | grep -q "net.dosowisko.PlasmaApplicationWallpaper"; then
                kwriteconfig6 --file kscreenlockerrc --group Greeter --key WallpaperPlugin net.dosowisko.PlasmaApplicationWallpaper
                kwriteconfig6 --file kscreenlockerrc --group Greeter --group Wallpaper --group net.dosowisko.PlasmaApplicationWallpaper --group General --key command "quickshell -p $HOME/.config/quickshell/caelestia/lockscreen.qml"
                kwriteconfig6 --file kscreenlockerrc --group Greeter --group Wallpaper --group net.dosowisko.PlasmaApplicationWallpaper --group General --key fps 1
                kwriteconfig6 --file kscreenlockerrc --group Greeter --group LnF --group General --key alwaysShowClock false
                kwriteconfig6 --file kscreenlockerrc --group Greeter --group LnF --group General --key showMediaControls false
                ok "KDE Lock Screen configured."
            else
                warn "plasma-wallpaper-application plugin not installed. Skipping KDE Lock Screen configuration."
            fi
        else
            warn "KDE config tools not found. Skipping KDE Lock Screen configuration."
        fi
    else
        info "KDE Lock Screen configuration skipped."
    fi
fi

# UPDATER ONLY BLOCK END

info "Patching Recorder.qml to wait for portal selection..."
for recorder_qml in \
    "$HOME/.config/quickshell/caelestia/services/Recorder.qml" \
    "$HOME/.local/share/caelestia-shell/services/Recorder.qml" \
    "shell/services/Recorder.qml"; do
    if [[ -f "$recorder_qml" ]]; then
        sed -i 's/command: \["pidof", "gpu-screen-recorder"\]/command: \["sh", "-c", "pidof gpu-screen-recorder >\\\/dev\\\/null \&\& test -f $HOME\\\/.local\\\/state\\\/caelestia\\\/record\\\/recording.mp4"\]/g' "$recorder_qml" 2>/dev/null || true
    fi
done

info "Building Caelestia Shell..."

if [ ! -d "$SHELL_DIR" ]; then
    err "Shell directory not found at $SHELL_DIR!"
    exit 1
fi

cd "$SHELL_DIR" || exit 1

info "Configuring CMake..."
rm -rf build
cmake -B build -DCMAKE_BUILD_TYPE=Release -DCMAKE_INSTALL_PREFIX="$HOME/.local" -DINSTALL_QSCONFDIR="$HOME/.config/quickshell/caelestia" -DINSTALL_LIBDIR="lib/caelestia" -DINSTALL_QMLDIR="lib/qt6/qml" || {
    err "CMake configuration failed."
    exit 1
}

info "Building..."
cmake --build build -j"$(nproc)" || {
    err "Build failed."
    exit 1
}

info "Installing to user local dir..."
cmake --install build || {
    err "Installation failed."
    exit 1
}

# Validate critical QML module presence before declaring success.
CONFIG_MODULE_DIR="$HOME/.local/lib/qt6/qml/Caelestia/Config"
if [[ ! -f "$CONFIG_MODULE_DIR/qmldir" ]]; then
    err "Missing QML module metadata: $CONFIG_MODULE_DIR/qmldir"
    exit 1
fi

shopt -s nullglob
CONFIG_PLUGIN_FILES=("$CONFIG_MODULE_DIR"/*.so)
shopt -u nullglob
if [[ ${#CONFIG_PLUGIN_FILES[@]} -eq 0 ]]; then
    err "Missing Caelestia.Config plugin library in $CONFIG_MODULE_DIR"
    exit 1
fi

# Add wrapper config to bashrc/fish
if ! grep -q "QML2_IMPORT_PATH=.*caelestia" ~/.bashrc; then
    echo 'export QML2_IMPORT_PATH="$HOME/.local/lib/qt6/qml"' >> ~/.bashrc
    echo 'export CAELESTIA_LIB_DIR="$HOME/.local/lib/caelestia"' >> ~/.bashrc
fi
if [ -f "$HOME/.config/fish/config.fish" ]; then
    if ! grep -q "QML2_IMPORT_PATH" ~/.config/fish/config.fish; then
        echo 'set -gx QML2_IMPORT_PATH "$HOME/.local/lib/qt6/qml"' >> ~/.config/fish/config.fish
        echo 'set -gx CAELESTIA_LIB_DIR "$HOME/.local/lib/caelestia"' >> ~/.config/fish/config.fish
    fi
fi

mkdir -p ~/.local/bin ~/.config/systemd/user

info "Patching caelestia-cli record/screenshot (requires root)..."
sudo bash -s -- "$HOME" "${XDG_CACHE_HOME:-$HOME/.cache}" << 'EOF'
USER_HOME="$1"
USER_CACHE="$2"

ln -sf /usr/lib/libopencv_imgproc.so.5.0.0 /usr/lib/libopencv_imgproc.so.413 2>/dev/null || echo "[WARN] Failed to link opencv imgproc"
ln -sf /usr/lib/libopencv_core.so.5.0.0 /usr/lib/libopencv_core.so.413 2>/dev/null || echo "[WARN] Failed to link opencv core"

if ! python3 -c '
import sys, os, glob, re
search_paths = sys.path + glob.glob("'"$USER_HOME"'/.local/lib/python*/site-packages")
file_path = None
for p in search_paths:
    candidate = os.path.join(p, "caelestia", "subcommands", "record.py")
    if os.path.exists(candidate):
        file_path = candidate
        break
if not file_path:
    print("Could not find caelestia/subcommands/record.py to patch")
    sys.exit(1)
try:
    with open(file_path, "r") as f: code = f.read()
    
    code = code.replace("args += [\"-a\", \"default_output\"]", "args += [\"-a\", \"default_output\", \"-a\", \"default_input\"]")
    code = code.replace("args += [\"-f\", str(max_rr)]", "args += [\"-f\", str(max_rr if max_rr > 0 else 60)]")
    if "-fallback-cpu-encoding" not in code:
        code = code.replace("recording_path.parent.mkdir(parents=True, exist_ok=True)", """recording_path.parent.mkdir(parents=True, exist_ok=True)
        args += ["-fallback-cpu-encoding", "yes"]""")
    
    # Inject KWin focused monitor refresh rate logic
    kwin_logic = """        import json, os, subprocess
        focused_rr = 60
        try:
            runtime_dir = os.environ.get("XDG_RUNTIME_DIR", "/tmp")
            with open(os.path.join(runtime_dir, "qs_kwin_active_output.txt"), "r") as f:
                active_output = f.read().strip()
            kscreen_out = subprocess.check_output(["kscreen-doctor", "-j"], text=True)
            kscreen_data = json.loads(kscreen_out)
            for output in kscreen_data.get("outputs", []):
                if output.get("name") == active_output and output.get("connected"):
                    for mode in output.get("modes", []):
                        if mode.get("id") == output.get("currentModeId"):
                            focused_rr = round(mode.get("refreshRate", 60))
                            break
        except Exception:
            pass
"""
    code = code.replace("        monitors = hypr.message(\"monitors\")", kwin_logic)

    # Use portal and the focused_rr
    code = re.sub(r"focused_monitor = next\(monitor for monitor in monitors if monitor\[\"focused\"\]\)\n\s*if focused_monitor:\n\s*args \+= \[focused_monitor\[\"name\"\]?, \"-f\", str\(round\(focused_monitor\[\"refreshRate\"\]\)\)\]", "args += [\"portal\", \"-f\", str(focused_rr)]", code, flags=re.MULTILINE|re.DOTALL)
    code = re.sub(r"focused_monitor = next\(monitor for monitor in monitors if monitor\[\"focused\"\]\)\n\s*if focused_monitor:\n\s*args \+= \[\"portal\", \"-f\", str\(round\(focused_monitor\[\"refreshRate\"\]\)\)\]", "args += [\"portal\", \"-f\", str(focused_rr)]", code, flags=re.MULTILINE|re.DOTALL)

    code = code.replace("if self.args.region:", "if False:")
    code = code.replace("text=True)", "text=True).strip()")
    code = code.replace("args += [\"region\", \"-region\", region]", "args += [region]")
    
    launch_orig = """        proc = subprocess.Popen([RECORDER, *args, "-o", str(recording_path)], start_new_session=True)

        notif = notify("-p", "Recording started", "Recording...")"""
    launch_new = """        recording_path.unlink(missing_ok=True)
        proc = subprocess.Popen([RECORDER, *args, "-o", str(recording_path)], start_new_session=True)
        while proc.poll() is None and not recording_path.exists():
            time.sleep(0.1)
        if proc.poll() is not None:
            return
        notif = notify("-p", "Recording started", "Recording...")"""
    code = code.replace(launch_orig, launch_new)
    
    code = code.replace("[\"app2unit\", \"-O\", new_path]", "[\"xdg-open\", str(new_path)]")
    
    old_dbus = """            p = subprocess.run(
                [
                    "dbus-send",
                    "--session",
                    "--dest=org.freedesktop.FileManager1",
                    "--type=method_call",
                    "/org/freedesktop/FileManager1",
                    "org.freedesktop.FileManager1.ShowItems",
                    f"array:string:file://{new_path}",
                    "string:",
                ]
            )
            if p.returncode != 0:
                subprocess.Popen(["app2unit", "-O", new_path.parent], start_new_session=True)"""
    new_xdg = "            subprocess.Popen([\"xdg-open\", str(new_path.parent)], start_new_session=True)"
    code = code.replace(old_dbus, new_xdg)
    code = code.replace("[\"dolphin\", \"--select\", str(new_path)]", "[\"xdg-open\", str(new_path.parent)]")
    
    with open(file_path, "w") as f: f.write(code)
        
    screenshot_path = None
    for p in search_paths:
        candidate = os.path.join(p, "caelestia", "subcommands", "screenshot.py")
        if os.path.exists(candidate):
            screenshot_path = candidate
            break
    if screenshot_path:
        with open(screenshot_path, "r") as f: scode = f.read()
        scode = scode.replace("cmd = [\"grim\"]", "cmd = [\"spectacle\", \"-b\", \"-f\", \"-n\", \"-o\"]")
        scode = scode.replace("if focused_monitor:\n            cmd += [\"-o\", focused_monitor[\"name\"]]", "")
        scode = scode.replace("cmd += [\"-\"]\n        sc_data = subprocess.check_output(cmd)", "tmp_file = \"/tmp/qs-screenshot.png\"\n        cmd += [tmp_file]\n        subprocess.run(cmd)\n        try:\n            with open(tmp_file, \"rb\") as f:\n                sc_data = f.read()\n        except Exception:\n            sc_data = b\"\"")
        with open(screenshot_path, "w") as f: f.write(scode)
except Exception as e:
    print(f"Failed to patch record.py: {e}")
    sys.exit(1)
'; then
    echo "Caelestia CLI Record/Dolphin Patch" >> "$USER_CACHE/caelestia-kde/failed_patches.txt"
fi
EOF

# Save current commit for the update checker
mkdir -p ~/.config/quickshell/caelestia
if [ -d "$BUNDLE_DIR/.git" ]; then
    git -C "$BUNDLE_DIR" rev-parse HEAD > ~/.config/quickshell/caelestia/.current_commit 2>/dev/null || true
fi

ok "Caelestia Shell and KDE Bridges built and installed successfully to user directory."
