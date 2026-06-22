#!/usr/bin/env bash

set -uo pipefail

CYAN="\033[0;36m"
GREEN="\033[0;32m"
RED="\033[0;31m"
RST="\033[0m"

info() { echo -e "${CYAN}[INFO]  $*${RST}"; }
ok()   { echo -e "${GREEN}[OK]    $*${RST}"; }
err()  { echo -e "${RED}[ERR]   $*${RST}"; }

BUNDLE_DIR="${BUNDLE_DIR:-$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)}"
SHELL_DIR="$BUNDLE_DIR/shell"

info "Patching Recorder.qml to wait for portal selection..."
sed -i 's/command: \["pidof", "gpu-screen-recorder"\]/command: \["sh", "-c", "pidof gpu-screen-recorder >\\\/dev\\\/null \&\& test -f $HOME\\\/.local\\\/state\\\/caelestia\\\/record\\\/recording.mp4"\]/g' "$HOME/.local/share/caelestia-shell/services/Recorder.qml" 2>/dev/null || true
sed -i 's/command: \["pidof", "gpu-screen-recorder"\]/command: \["sh", "-c", "pidof gpu-screen-recorder >\\\/dev\\\/null \&\& test -f $HOME\\\/.local\\\/state\\\/caelestia\\\/record\\\/recording.mp4"\]/g' "shell/services/Recorder.qml" 2>/dev/null || true

info "Building Caelestia Shell..."

if [ ! -d "$SHELL_DIR" ]; then
    err "Shell directory not found at $SHELL_DIR!"
    exit 1
fi

cd "$SHELL_DIR"

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

info "Deploying KDE Bridge Scripts..."

mkdir -p ~/.local/bin ~/.local/share/kwin/scripts ~/.config/systemd/user

# Install python bridge and hyprctl mock
if [ -d "$BUNDLE_DIR/src/bin" ]; then
    cp "$BUNDLE_DIR/src/bin/"* ~/.local/bin/
    chmod +x ~/.local/bin/hyprctl ~/.local/bin/qs-kwin-bridge.py
fi

if [ -f "$BUNDLE_DIR/scripts/record.sh" ]; then
    cp "$BUNDLE_DIR/scripts/record.sh" ~/.local/bin/caelestia-record
    chmod +x ~/.local/bin/caelestia-record
fi

# Patch system-wide caelestia-cli hypr.py to use mock hyprctl
info "Patching caelestia-cli to use KDE mock hyprctl..."

# Ensure sudo privileges for patching without timing out
sudo -v || exit 1
(while true; do sudo -n true; sleep 55; done) 2>/dev/null &
SUDO_LOOP_PID=$!
trap 'kill $SUDO_LOOP_PID 2>/dev/null || true' EXIT

if ! sudo python3 -c '
import sys, os, glob
search_paths = sys.path + glob.glob("'"$HOME"'/.local/lib/python*/site-packages")
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
    with open(file_path, "r") as f: code = f.read()
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
    if not os.path.exists(hyprctl_path): hyprctl_path = "hyprctl"
    args = [hyprctl_path, msg]
    if is_json: args.append("-j")
    try: resp = subprocess.check_output(args, text=True)
    except Exception: resp = "[]" if is_json else ""
    return __import__("json").loads(resp) if is_json else resp

def dispatch(dispatcher: str, *args: str) -> bool:
    hyprctl_path = os.path.expanduser("~/.local/bin/hyprctl")
    if not os.path.exists(hyprctl_path): hyprctl_path = "hyprctl"
    cmd_args = [hyprctl_path, "dispatch", dispatcher, *args]
    try:
        subprocess.check_call(cmd_args, stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
        return True
    except subprocess.CalledProcessError:
        return False""")
    with open(file_path, "w") as f: f.write(new_code)
except Exception as e:
    print(f"Failed to patch hypr.py: {e}")
    sys.exit(1)
'; then
    echo "Caelestia CLI Hyprctl Mock Patch" >> "${XDG_CACHE_HOME:-$HOME/.cache}/caelestia-kde/failed_patches.txt"
fi

# Patch system-wide caelestia-cli record.py to fix audio and dolphin issues
info "Patching caelestia-cli record.py..."
if ! sudo python3 -c '
import sys, os, glob
search_paths = sys.path + glob.glob("'"$HOME"'/.local/lib/python*/site-packages")
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
    
    # Force XDG Desktop Portal backend instead of raw KMS so it actually captures app windows on KDE Wayland!
    code = code.replace("args += [focused_monitor[\"name\"], \"-f\",", "args += [\"portal\", \"-f\",")
    
    # Disable slurp region capture entirely, because the KDE Portal natively handles region cropping!
    code = code.replace("if self.args.region:", "if False:")
    
    code = code.replace("text=True)", "text=True).strip()")
    code = code.replace("args += [\"region\", \"-region\", region]", "args += [region]")
    
    # Wait for portal selection (i.e., when gpu-screen-recorder actually creates the file) before notifying
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
    
    # Use xdg-open instead of hardcoded apps
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
    
    # Also fix if it was already patched with dolphin
    code = code.replace("[\"dolphin\", \"--select\", str(new_path)]", "[\"xdg-open\", str(new_path.parent)]")
    
    with open(file_path, "w") as f: f.write(code)
    
    # Also patch hypr.py for hyprctl absolute path and correct arguments
    hypr_path = None
    for p in search_paths:
        candidate = os.path.join(p, "caelestia", "utils", "hypr.py")
        if os.path.exists(candidate):
            hypr_path = candidate
            break
    if hypr_path:
        with open(hypr_path, "r") as f: hcode = f.read()
        hcode = hcode.replace("def message(msg: str, is_json: bool = True) -> str | dict[str, Any]:\n    with socket.socket(socket.AF_UNIX, socket.SOCK_STREAM) as sock:\n        sock.connect(socket_path)\n\n        if is_json:\n            msg = f\"j/{msg}\"\n        sock.send(msg.encode())\n\n        resp = sock.recv(8192).decode()\n        while True:\n            new_resp = sock.recv(8192)\n            if not new_resp:\n                break\n            resp += new_resp.decode()\n\n        return json.loads(resp) if is_json else resp", "import subprocess\ndef message(msg: str, is_json: bool = True) -> str | dict[str, Any]:\n    try:\n        cmd = [os.path.expanduser(\"~/.local/bin/hyprctl\"), *msg.split(), \"-j\" if is_json else \"\"]\n        cmd = [x for x in cmd if x]\n        res = subprocess.run(cmd, capture_output=True, text=True)\n        return json.loads(res.stdout) if is_json else res.stdout\n    except Exception as e:\n        print(f\"Mock hyprctl failed: {e}\")\n        return {} if is_json else \"\"")
        with open(hypr_path, "w") as f: f.write(hcode)
except Exception as e:
    print(f"Failed to patch record.py: {e}")
    sys.exit(1)
'; then
    echo "Caelestia CLI Record/Dolphin Patch" >> "${XDG_CACHE_HOME:-$HOME/.cache}/caelestia-kde/failed_patches.txt"
fi

# Install kwin script
if [ -d "$BUNDLE_DIR/src/kwin/quickshell-kde-bridge" ]; then
    cp -r "$BUNDLE_DIR/src/kwin/quickshell-kde-bridge" ~/.local/share/kwin/scripts/
fi

# Install systemd service
if [ -d "$BUNDLE_DIR/src/systemd" ]; then
    cp "$BUNDLE_DIR/src/systemd/qs-kwin-bridge.service" ~/.config/systemd/user/
fi

# Enable systemd service (silently unmask if previously masked)
systemctl --user unmask qs-kwin-bridge.service &>/dev/null || true
systemctl --user daemon-reload
systemctl --user enable --now qs-kwin-bridge.service &>/dev/null || true

# Load and start KWin script
qdbus6 org.kde.KWin /Scripting org.kde.kwin.Scripting.loadScript ~/.local/share/kwin/scripts/quickshell-kde-bridge/contents/code/main.js quickshell-kde-bridge &>/dev/null || true
qdbus6 org.kde.KWin /Scripting org.kde.kwin.Scripting.start &>/dev/null || true

ok "Caelestia Shell and KDE Bridges built and installed successfully to user directory."
