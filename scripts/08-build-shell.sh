#!/usr/bin/env bash

set -uo pipefail

BUNDLE_DIR="${BUNDLE_DIR:-$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)}"
source "$BUNDLE_DIR/scripts/00-ui.sh"

SHELL_DIR="$BUNDLE_DIR/shell"

ui_section "Step 8/11 - Build Caelestia Shell"

ui_info "Patching Recorder.qml to wait for portal selection..."
sed -i 's/command: \["pidof", "gpu-screen-recorder"\]/command: \["sh", "-c", "pidof gpu-screen-recorder >\\/dev\\/null \&\& test -f $HOME\\/.local\\/state\\/caelestia\\/record\\/recording.mp4"\]/g' "$HOME/.local/share/caelestia-shell/services/Recorder.qml" 2>/dev/null || true
sed -i 's/command: \["pidof", "gpu-screen-recorder"\]/command: \["sh", "-c", "pidof gpu-screen-recorder >\\/dev\\/null \&\& test -f $HOME\\/.local\\/state\\/caelestia\\/record\\/recording.mp4"\]/g' "$BUNDLE_DIR/shell/services/Recorder.qml" 2>/dev/null || true

ui_info "Building Caelestia Shell..."

if [ ! -d "$SHELL_DIR" ]; then
    ui_die "Shell directory not found at $SHELL_DIR."
fi

cd "$SHELL_DIR"

ui_info "Configuring CMake..."
rm -rf build
cmake -B build -DCMAKE_BUILD_TYPE=Release -DCMAKE_INSTALL_PREFIX="$HOME/.local" -DINSTALL_QSCONFDIR="$HOME/.config/quickshell/caelestia" -DINSTALL_LIBDIR="lib/caelestia" -DINSTALL_QMLDIR="lib/qt6/qml" || {
    ui_die "CMake configuration failed."
}

ui_info "Building..."
cmake --build build -j"$(nproc)" || {
    ui_die "Build failed."
}

ui_info "Installing to user local dir..."
cmake --install build || {
    ui_die "Installation failed."
}

if ! grep -q "QML2_IMPORT_PATH=.*caelestia" "$HOME/.bashrc"; then
    echo 'export QML2_IMPORT_PATH="$HOME/.local/lib/qt6/qml"' >> "$HOME/.bashrc"
    echo 'export CAELESTIA_LIB_DIR="$HOME/.local/lib/caelestia"' >> "$HOME/.bashrc"
fi
if [ -f "$HOME/.config/fish/config.fish" ]; then
    if ! grep -q "QML2_IMPORT_PATH" "$HOME/.config/fish/config.fish"; then
        echo 'set -gx QML2_IMPORT_PATH "$HOME/.local/lib/qt6/qml"' >> "$HOME/.config/fish/config.fish"
        echo 'set -gx CAELESTIA_LIB_DIR "$HOME/.local/lib/caelestia"' >> "$HOME/.config/fish/config.fish"
    fi
fi

ui_info "Deploying KDE bridge scripts..."

mkdir -p "$HOME/.local/bin" "$HOME/.local/share/kwin/scripts" "$HOME/.config/systemd/user"

if [ -d "$BUNDLE_DIR/src/bin" ]; then
    cp "$BUNDLE_DIR/src/bin/"* "$HOME/.local/bin/"
    chmod +x "$HOME/.local/bin/hyprctl" "$HOME/.local/bin/qs-kwin-bridge.py"
fi

if [ -f "$BUNDLE_DIR/scripts/record.sh" ]; then
    cp "$BUNDLE_DIR/scripts/record.sh" "$HOME/.local/bin/caelestia-record"
    chmod +x "$HOME/.local/bin/caelestia-record"
fi

ui_info "Patching caelestia-cli to use KDE mock hyprctl..."

sudo -v || exit 1
(while true; do sudo -n true; sleep 55; done) 2>/dev/null &
SUDO_LOOP_PID=$!
trap 'kill $SUDO_LOOP_PID 2>/dev/null || true' EXIT

if ! sudo python3 -c '
import sys, os, glob
search_paths = sys.path + glob.glob("'$HOME'/.local/lib/python*/site-packages")
file_path = None
for p in search_paths:
    candidate = os.path.join(p, "caelestia", "utils", "hypr.py")
    if os.path.exists(candidate):
        file_path = candidate
        break
if not file_path:
    print("Could not find caelestia/utils/hypr.py to patch")
    sys.exit(1)
try:
    with open(file_path, "r") as f:
        code = f.read()
    new_code = code.replace("""def message(msg: str, is_json: bool = True) -> str | dict[str, Any]:
    with socket.socket(socket.AF_UNIX, socket.SOCK_STREAM) as sock:
        sock.connect(socket_path)

        if is_json:
            msg = f"j/{msg}"
        sock.send(msg.encode())

        resp = sock.recv(8192).decode()
        while True:
            new_resp = sock.recv(8192)
            if not new_resp:
                break
            resp += new_resp.decode()

        return json.loads(resp) if is_json else resp


def dispatch(dispatcher: str, *args: str) -> bool:
    return message(f"dispatch {dispatcher} {\" \".join(map(str, args))}\".rstrip(), is_json=False) == \"ok\"""",
    """import subprocess
def message(msg: str, is_json: bool = True) -> str | dict[str, Any]:
    hyprctl_path = os.path.expanduser("~/.local/bin/hyprctl")
    if not os.path.exists(hyprctl_path):
        hyprctl_path = "hyprctl"
    args = [hyprctl_path, msg]
    if is_json:
        args.append("-j")
    try:
        resp = subprocess.check_output(args, text=True)
    except Exception:
        resp = "[]" if is_json else ""
    return __import__("json").loads(resp) if is_json else resp

def dispatch(dispatcher: str, *args: str) -> bool:
    hyprctl_path = os.path.expanduser("~/.local/bin/hyprctl")
    if not os.path.exists(hyprctl_path):
        hyprctl_path = "hyprctl"
    cmd_args = [hyprctl_path, "dispatch", dispatcher, *args]
    try:
        subprocess.check_call(cmd_args, stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
        return True
    except subprocess.CalledProcessError:
        return False""")
    with open(file_path, "w") as f:
        f.write(new_code)
except Exception as e:
    print(f"Failed to patch hypr.py: {e}")
    sys.exit(1)
'; then
    echo "Caelestia CLI Hyprctl Mock Patch" >> "${XDG_CACHE_HOME:-$HOME/.cache}/caelestia-kde/failed_patches.txt"
fi

ui_info "Patching caelestia-cli record.py..."
if ! sudo python3 -c '
import sys, os, glob
search_paths = sys.path + glob.glob("'$HOME'/.local/lib/python*/site-packages")
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
    with open(file_path, "r") as f:
        code = f.read()

    code = code.replace("args += [\"-a\", \"default_output\"]", "args += [\"-a\", \"default_output\", \"-a\", \"default_input\"]")
    code = code.replace("args += [\"-f\", str(max_rr)]", "args += [\"-f\", str(max_rr if max_rr > 0 else 60)]")
    if "-fallback-cpu-encoding" not in code:
        code = code.replace("recording_path.parent.mkdir(parents=True, exist_ok=True)", """recording_path.parent.mkdir(parents=True, exist_ok=True)
        args += [\"-fallback-cpu-encoding\", \"yes\"]""")

    code = code.replace("args += [focused_monitor[\"name\"], \"-f\",", "args += [\"portal\", \"-f\",")
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

    with open(file_path, "w") as f:
        f.write(code)
except Exception as e:
    print(f"Failed to patch record.py: {e}")
    sys.exit(1)
'; then
    echo "Caelestia CLI Record/Dolphin Patch" >> "${XDG_CACHE_HOME:-$HOME/.cache}/caelestia-kde/failed_patches.txt"
fi

ui_ok "Caelestia Shell build and deployment complete."
