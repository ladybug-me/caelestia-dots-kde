from __future__ import annotations

import atexit
import base64
import getpass
import os
import re
import shutil
import subprocess
import tempfile
import threading
import time
from pathlib import Path

from .config import InstallerConfig
from .ui import UI


class Uninstaller:
    def __init__(self, cfg: InstallerConfig) -> None:
        self.cfg = cfg
        self.env = os.environ.copy()
        self.base_distro = "unknown"
        self.sudo_password = ""
        self.remove_packages = False
        self.selected_backup: Path | None = None
        self._sudo_stop = threading.Event()

    def run(self) -> None:
        self.detect_distro()
        self.print_intro()
        self.collect_sudo_password()

        if not UI.prompt_yes_no("Are you sure you want to uninstall Caelestia KDE?", default=False):
            UI.die("Uninstall cancelled.")

        UI.warn("Remove installed packages as well?")
        UI.info("This will uninstall tools like fish, foot, btop, fastfetch, and similar dependencies.")
        self.remove_packages = UI.prompt_yes_no("Remove packages?", default=False)

        self.selected_backup = self.select_backup()

        self.step1_stop_services()
        self.step2_remove_service_files()
        self.step3_remove_shell_installation()
        self.step4_remove_bridge_scripts()
        self.step5_restore_or_remove_configs()
        self.step6_revert_kde_settings()
        self.step7_revert_shell_changes()
        self.step8_remove_system_level_files()
        self.step9_remove_packages_optional()
        self.step10_cleanup_cache_and_build_dirs()
        self.step11_reload_kde()
        self.finish()

    def detect_distro(self) -> None:
        release_file = Path("/etc/os-release")
        distro = "unknown"
        if release_file.exists():
            data: dict[str, str] = {}
            for line in release_file.read_text(encoding="utf-8", errors="ignore").splitlines():
                if "=" not in line:
                    continue
                key, value = line.split("=", 1)
                data[key] = value.strip().strip('"')

            did = data.get("ID", "").lower()
            like = data.get("ID_LIKE", "").lower()

            if did in {"arch", "cachyos", "endeavouros", "manjaro", "artix"}:
                distro = "arch"
            elif did in {"fedora", "nobara", "bazzite", "rhel", "centos", "almalinux", "rocky"}:
                distro = "fedora"
            elif "arch" in like:
                distro = "arch"
            elif "fedora" in like:
                distro = "fedora"

        if distro == "unknown":
            UI.warn("Could not detect the distribution automatically.")
            UI.info("Select the base platform for this system.")
            print("  1) Arch-based")
            print("  2) Fedora-based")
            print("  3) Exit")
            choice = input("Choice [1-3]: ").strip()
            if choice == "1":
                distro = "arch"
            elif choice == "2":
                distro = "fedora"
            else:
                UI.die("Exiting.")

        self.base_distro = distro

    def print_intro(self) -> None:
        print()
        UI.separator()
        print(f"{UI.BOLD}Caelestia KDE Port{UI.RST}")
        print("Unified uninstaller for the KDE Plasma port.")
        UI.separator()
        print()
        UI.info("This uninstaller removes the Caelestia KDE shell and configuration files.")
        UI.info(f"Backups in {self.cfg.bundle_dir / 'backups'} can be restored during the process.")

    def collect_sudo_password(self) -> None:
        while True:
            pw = getpass.getpass("Enter your sudo password: ")
            self._run(["sudo", "-k"], check=False)
            proc = subprocess.run(
                ["sudo", "-S", "-v"],
                input=(pw + "\n").encode(),
                stdout=subprocess.DEVNULL,
                stderr=subprocess.DEVNULL,
                env=self.env,
            )
            if proc.returncode == 0:
                self.sudo_password = pw
                break
            UI.warn("Incorrect password. Try again.")

        self.start_sudo_keepalive()

    def start_sudo_keepalive(self) -> None:
        def worker() -> None:
            while not self._sudo_stop.is_set():
                self._run(["sudo", "-n", "true"], check=False)
                self._sudo_stop.wait(55)

        thread = threading.Thread(target=worker, daemon=True)
        thread.start()

        def cleanup() -> None:
            self._sudo_stop.set()

        atexit.register(cleanup)

    def select_backup(self) -> Path | None:
        backup_root = self.cfg.bundle_dir / "backups"
        if not backup_root.is_dir():
            return None

        backups = sorted(
            [p for p in backup_root.iterdir() if p.is_dir() and re.match(r"^\d{8}_\d{6}$", p.name)],
            key=lambda p: p.name,
            reverse=True,
        )
        if not backups:
            return None

        print()
        UI.section("Available backups to restore from")
        for i, path in enumerate(backups, start=1):
            ts = path.name
            formatted = f"{ts[0:4]}-{ts[4:6]}-{ts[6:8]} {ts[9:11]}:{ts[11:13]}:{ts[13:15]}"
            tag = self._backup_tag(path)
            print(f"  {i}) {formatted}{tag}")
        print("  0) None (Do not restore from backup)")

        while True:
            raw = input("Select a backup to restore [1]: ").strip() or "1"
            if raw == "0":
                return None
            if raw.isdigit() and 1 <= int(raw) <= len(backups):
                selected = backups[int(raw) - 1]
                if (selected / "config" / "quickshell" / "caelestia" / "shell.qml").exists():
                    print()
                    UI.warn("The selected backup contains Caelestia configurations.")
                    print(f"{UI.YELLOW}Restoring this backup will not revert to a clean KDE desktop.{UI.RST}")
                    print(f"{UI.YELLOW}It will restore a previous Caelestia state instead.{UI.RST}")
                    if not UI.prompt_yes_no("Are you sure you want to restore this backup?", default=False):
                        print(f"{UI.DIM}Backup selection cancelled. Please select again.{UI.RST}")
                        continue
                return selected
            print(f"{UI.RED}Invalid selection.{UI.RST}")

    def _backup_tag(self, backup: Path) -> str:
        tag = ""
        shell_src = self.cfg.bundle_dir / "src" / "dots" / "quickshell" / "caelestia"
        shell_bk = backup / "config" / "quickshell" / "caelestia"
        if (shell_bk / "shell.qml").exists():
            if shell_src.exists() and self._run(["diff", "-qr", str(shell_bk), str(shell_src)], check=False) == 0:
                tag += f" {UI.CYAN}[Caelestia]{UI.RST}"
            else:
                tag += f" {UI.YELLOW}[Caelestia (Modified)]{UI.RST}"

        prev_shell = backup / "previous_shell.txt"
        if prev_shell.exists():
            try:
                tag += f" {UI.CYAN}[Shell: {Path(prev_shell.read_text(encoding='utf-8', errors='ignore').strip()).name}]{UI.RST}"
            except Exception:
                pass
        return tag

    def restore_or_remove(self, name: str, target: Path, backup_subdir: str) -> None:
        shutil.rmtree(target, ignore_errors=True)
        if target.exists() and target.is_file():
            target.unlink(missing_ok=True)

        if self.selected_backup is not None:
            src = self.selected_backup / backup_subdir / name
            if src.exists():
                if src.is_dir():
                    shutil.copytree(src, target)
                else:
                    target.parent.mkdir(parents=True, exist_ok=True)
                    shutil.copy2(src, target)
                UI.ok(f"Restored {name} from backup")
                return

        UI.skip(f"No backup for {name} - removed without restore")

    def step1_stop_services(self) -> None:
        UI.section("Step 1/11 - Stop & disable services")
        for svc in ["qs-kwin-bridge", "cliphist", "ydotoold", "kde-material-you-colors"]:
            enabled = self._run(["systemctl", "--user", "is-enabled", "--quiet", f"{svc}.service"], check=False) == 0
            active = self._run(["systemctl", "--user", "is-active", "--quiet", f"{svc}.service"], check=False) == 0
            if enabled or active:
                self._run(["systemctl", "--user", "disable", "--now", f"{svc}.service"], check=False)
                UI.ok(f"Disabled user service: {svc}")
            else:
                UI.skip(f"User service not active: {svc}")

        keyd_enabled = self._run(["systemctl", "is-enabled", "--quiet", "keyd"], check=False) == 0
        keyd_active = self._run(["systemctl", "is-active", "--quiet", "keyd"], check=False) == 0
        if keyd_enabled or keyd_active:
            self._run(["sudo", "systemctl", "disable", "--now", "keyd"], check=False)
            UI.ok("Disabled system service: keyd")
        else:
            UI.skip("keyd not active")

        self._run(["pkill", "-f", "caelestia shell"], check=False)
        self._run(["pkill", "-f", "quickshell"], check=False)
        UI.ok("Stopped any running shell processes")

    def step2_remove_service_files(self) -> None:
        UI.section("Step 2/11 - Remove service & autostart files")
        user_systemd = Path.home() / ".config" / "systemd" / "user"
        for svc in ["qs-kwin-bridge.service", "cliphist.service", "ydotoold.service", "kde-material-you-colors.service"]:
            p = user_systemd / svc
            if p.exists():
                p.unlink(missing_ok=True)
                UI.ok(f"Removed: {p}")

        auto = Path.home() / ".config" / "autostart" / "caelestiashell.desktop"
        if auto.exists():
            auto.unlink(missing_ok=True)
            UI.ok("Removed autostart entry: caelestiashell.desktop")

        self._run(["systemctl", "--user", "daemon-reload"], check=False)

    def step3_remove_shell_installation(self) -> None:
        UI.section("Step 3/11 - Remove shell installation")
        for p in [
            Path.home() / ".config" / "quickshell" / "caelestia",
            Path.home() / ".local" / "lib" / "caelestia",
            Path.home() / ".local" / "share" / "caelestia-shell",
        ]:
            if p.exists():
                shutil.rmtree(p, ignore_errors=True)
                UI.ok(f"Removed {p}")

        qml_root = Path.home() / ".local" / "lib" / "qt6" / "qml"
        for mod in ["Caelestia", "M3Shapes"]:
            p = qml_root / mod
            if p.exists():
                shutil.rmtree(p, ignore_errors=True)
                UI.ok(f"Removed QML module: {mod}")

    def step4_remove_bridge_scripts(self) -> None:
        UI.section("Step 4/11 - Remove bridge scripts")
        for f in [
            Path.home() / ".local" / "bin" / "hyprctl",
            Path.home() / ".local" / "bin" / "kcolorpicker",
            Path.home() / ".local" / "bin" / "qs-kwin-bridge.py",
            Path.home() / ".local" / "bin" / "caelestia-shortcuts",
            Path.home() / ".local" / "bin" / "caelestia-record",
            Path.home() / ".local" / "bin" / "ydotoold-wrapper",
        ]:
            if f.exists():
                f.unlink(missing_ok=True)
                UI.ok(f"Removed: {f}")

        kwin_script = Path.home() / ".local" / "share" / "kwin" / "scripts" / "quickshell-kde-bridge"
        if kwin_script.exists():
            shutil.rmtree(kwin_script, ignore_errors=True)
            UI.ok("Removed KWin script: quickshell-kde-bridge")

        apps_dir = self.cfg.bundle_dir / "src" / "keyboardshortcuts" / "applications"
        if apps_dir.exists():
            for desktop in apps_dir.glob("*.desktop"):
                target = Path.home() / ".local" / "share" / "applications" / desktop.name
                if target.exists():
                    target.unlink(missing_ok=True)
                    UI.ok(f"Removed desktop entry: {target.name}")
            self._run(["update-desktop-database", str(Path.home() / ".local" / "share" / "applications")], check=False)

    def step5_restore_or_remove_configs(self) -> None:
        UI.section("Step 5/11 - Restore / remove config directories")
        for cfg in ["btop", "fastfetch", "fish", "foot", "hypr", "kitty", "micro", "nvim", "rofi", "thunar", "uwsm", "zed", "zen", "vscode"]:
            target = Path.home() / ".config" / cfg
            if target.exists():
                self.restore_or_remove(cfg, target, "config")

        starship = Path.home() / ".config" / "starship.toml"
        if starship.exists():
            self.restore_or_remove("starship.toml", starship, "config")

        kmix = Path.home() / ".config" / "kmixrc"
        if kmix.exists():
            kmix.unlink(missing_ok=True)
            UI.ok("Removed ~/.config/kmixrc")

    def step6_revert_kde_settings(self) -> None:
        UI.section("Step 6/11 - Revert KDE settings")
        settings = [
            ("plasmarc", "OSD", "Enabled", "true"),
            ("plasmarc", "OSD", "ShowOnActiveScreen", "true"),
            ("kdeglobals", "KDE", "OSDEnabled", "true"),
            ("plasmanotifyrc", "Notifications", "LoudnessChangedOSD", "true"),
            ("powerdevilrc", "BrightnessControl", "showOSD", "true"),
            ("powerdevilrc", "AC", "brightnessosd", "true"),
        ]
        for file_, group, key, val in settings:
            self._run(["kwriteconfig6", "--file", file_, "--group", group, "--key", key, val], check=False)
        UI.ok("Re-enabled KDE OSD notifications")

        if self.selected_backup is not None:
            UI.info("Restoring core KDE configuration files from backup...")
            for kde_cfg in ["kdeglobals", "ksplashrc", "plasmarc", "kwinrc", "kcminputrc", "plasma-org.kde.plasma.desktop-appletsrc"]:
                src = self.selected_backup / "config" / kde_cfg
                dst = Path.home() / ".config" / kde_cfg
                if src.exists():
                    dst.parent.mkdir(parents=True, exist_ok=True)
                    shutil.copy2(src, dst)
            UI.ok("Restored core KDE configuration files (including wallpaper and splash).")
        else:
            backup_file = Path.home() / ".config" / "caelestia-theme-backup.conf"
            if backup_file.exists():
                UI.info(f"Restoring KDE themes from {backup_file}...")
                for line in backup_file.read_text(encoding="utf-8", errors="ignore").splitlines():
                    if "=" not in line:
                        continue
                    key, val = line.split("=", 1)
                    parts = key.split("|")
                    if len(parts) != 3:
                        continue
                    try:
                        decoded = base64.b64decode(val).decode("utf-8", errors="ignore")
                    except Exception:
                        continue
                    self._run(["kwriteconfig6", "--file", parts[0], "--group", parts[1], "--key", parts[2], decoded], check=False)
                UI.ok("Restored previous KDE theme settings.")
            else:
                UI.info("No theme backup found. Reverting to default Breeze theme...")
                defaults = [
                    ("plasmarc", "Theme", "name", "default"),
                    ("kdeglobals", "KDE", "widgetStyle", "Breeze"),
                    ("kdeglobals", "General", "ColorScheme", "BreezeLight"),
                    ("kwinrc", "org.kde.kdecoration2", "library", "org.kde.breeze"),
                    ("kwinrc", "org.kde.kdecoration2", "theme", "@breeze"),
                    ("kcminputrc", "Mouse", "cursorTheme", "breeze_cursors"),
                ]
                for file_, group, key, val in defaults:
                    self._run(["kwriteconfig6", "--file", file_, "--group", group, "--key", key, val], check=False)
                UI.ok("Reset KDE theme settings to Breeze.")

        self._run(["kwriteconfig6", "--file", "kwinrc", "--group", "Plugins", "--key", "quickshell-kde-bridgeEnabled", "false"], check=False)
        self._run(["kwriteconfig6", "--file", "kwinrc", "--group", "Plugins", "--key", "poloniumEnabled", "false"], check=False)
        UI.ok("Disabled KWin plugins: quickshell-kde-bridge, polonium")

        self._run(["kwriteconfig6", "--file", "kwinrc", "--group", "Desktops", "--key", "Number", "1"], check=False)
        self._run(["kwriteconfig6", "--file", "kwinrc", "--group", "Desktops", "--key", "Rows", "1"], check=False)
        for i in range(1, 6):
            self._run(["kwriteconfig6", "--file", "kwinrc", "--group", "Desktops", "--key", f"Name_{i}", f"Desktop {i}"], check=False)
        UI.ok("Restored desktop count to 1")

        for i in range(1, 6):
            self._run(["kwriteconfig6", "--file", "kglobalshortcutsrc", "--group", "kwin", "--key", f"Switch to Desktop {i}", f"none,none,Switch to Desktop {i}"], check=False)
            self._run(["kwriteconfig6", "--file", "kglobalshortcutsrc", "--group", "kwin", "--key", f"Window to Desktop {i}", f"none,none,Move Window to Desktop {i}"], check=False)
        UI.ok("Cleared installer workspace shortcuts from kglobalshortcutsrc")

        if self.selected_backup is not None and (self.selected_backup / "config" / "kglobalshortcutsrc").exists():
            shutil.copy2(self.selected_backup / "config" / "kglobalshortcutsrc", Path.home() / ".config" / "kglobalshortcutsrc")
            UI.ok("Restored kglobalshortcutsrc from backup")
        else:
            backups = sorted((self.cfg.bundle_dir / "backups").glob("kglobalshortcutsrc_*"), reverse=True)
            if backups:
                shutil.copy2(backups[0], Path.home() / ".config" / "kglobalshortcutsrc")
                UI.ok(f"Restored kglobalshortcutsrc from {backups[0].name}")

        for p in [
            Path.home() / ".local" / "share" / "konsole" / "MaterialYou.colorscheme",
            Path.home() / ".local" / "share" / "konsole" / "MaterialYouAlt.colorscheme",
            Path.home() / ".local" / "share" / "konsole" / "TempMyou.profile",
        ]:
            p.unlink(missing_ok=True)
        for p in (Path.home() / ".local" / "share" / "color-schemes").glob("MaterialYou*.colors"):
            p.unlink(missing_ok=True)
        UI.ok("Removed Konsole profiles generated by Caelestia")

        if self.selected_backup is not None:
            konsolerc = self.selected_backup / "config" / "konsolerc"
            if konsolerc.exists():
                shutil.copy2(konsolerc, Path.home() / ".config" / "konsolerc")
                UI.ok("Restored konsolerc from backup")

            local_konsole = self.selected_backup / "local" / "konsole"
            if local_konsole.exists():
                dst = Path.home() / ".local" / "share" / "konsole"
                shutil.rmtree(dst, ignore_errors=True)
                shutil.copytree(local_konsole, dst)
                UI.ok("Restored ~/.local/share/konsole from backup")

    def step7_revert_shell_changes(self) -> None:
        UI.section("Step 7/11 - Revert shell changes")
        restore_shell = ""
        if self.selected_backup is not None:
            prev_shell = self.selected_backup / "previous_shell.txt"
            if prev_shell.exists():
                requested = prev_shell.read_text(encoding="utf-8", errors="ignore").strip()
                if self._is_valid_shell(requested):
                    restore_shell = requested
                else:
                    UI.warn(f"Previous shell ({requested}) is not listed in /etc/shells. Falling back to bash.")

        if not restore_shell:
            restore_shell = shutil.which("bash") or "/bin/bash"

        self._run(["sudo", "chsh", "-s", restore_shell, os.environ.get("USER", "")], check=False)
        UI.ok(f"Login shell reverted to {restore_shell}")

        bashrc = Path.home() / ".bashrc"
        if bashrc.exists():
            text = bashrc.read_text(encoding="utf-8", errors="ignore")
            text = re.sub(r"^.*QML2_IMPORT_PATH.*caelestia.*\n?", "", text, flags=re.MULTILINE)
            text = re.sub(r"^.*CAELESTIA_LIB_DIR.*\n?", "", text, flags=re.MULTILINE)
            bashrc.write_text(text, encoding="utf-8")
            UI.ok("Removed Caelestia env vars from ~/.bashrc")

        fish_cfg = Path.home() / ".config" / "fish" / "config.fish"
        if fish_cfg.exists():
            text = fish_cfg.read_text(encoding="utf-8", errors="ignore")
            text = re.sub(r"^.*QML2_IMPORT_PATH.*\n?", "", text, flags=re.MULTILINE)
            text = re.sub(r"^.*CAELESTIA_LIB_DIR.*\n?", "", text, flags=re.MULTILINE)
            fish_cfg.write_text(text, encoding="utf-8")
            UI.ok("Removed Caelestia env vars from fish config")

    def step8_remove_system_level_files(self) -> None:
        UI.section("Step 8/11 - Remove system-level files")

        keyd_conf = Path("/etc/keyd/quickshell.conf")
        if keyd_conf.exists():
            self._run(["sudo", "rm", "-f", str(keyd_conf)], check=False)
            UI.ok("Removed /etc/keyd/quickshell.conf")
            self._run(["sudo", "rmdir", "/etc/keyd"], check=False)

        uinput_rule = Path("/etc/udev/rules.d/80-uinput.rules")
        if uinput_rule.exists():
            self._run(["sudo", "rm", "-f", str(uinput_rule)], check=False)
            self._run(["sudo", "udevadm", "control", "--reload-rules"], check=False)
            UI.ok("Removed udev rule: 80-uinput.rules")

        ydotoold_sudoers = Path("/etc/sudoers.d/ydotoold-nopasswd")
        if ydotoold_sudoers.exists():
            self._run(["sudo", "rm", "-f", str(ydotoold_sudoers)], check=False)
            UI.ok("Removed sudoers rule: ydotoold-nopasswd")

        for link in ["/usr/local/bin/sass", "/usr/local/bin/qdbus6", "/usr/local/bin/caelestia"]:
            p = Path(link)
            if p.is_symlink():
                self._run(["sudo", "rm", "-f", link], check=False)
                UI.ok(f"Removed symlink: {link}")

        groups_out = subprocess.run(["groups", os.environ.get("USER", "")], capture_output=True, text=True).stdout
        if " input " in f" {groups_out} ":
            self._run(["sudo", "gpasswd", "-d", os.environ.get("USER", ""), "input"], check=False)
            UI.ok(f"Removed {os.environ.get('USER', '')} from 'input' group (takes effect on next login)")

    def step9_remove_packages_optional(self) -> None:
        if not self.remove_packages:
            UI.skip("Package removal skipped (user chose to keep packages)")
            return

        UI.section("Step 9/11 - Remove packages")
        arch_packages = [
            "caelestia-cli", "quickshell-git", "cmake", "ninja", "wl-clipboard", "cliphist", "inotify-tools", "app2unit", "wireplumber", "trash-cli",
            "jq", "aubio", "lm_sensors", "libcava", "libqalculate", "foot", "fish", "eza", "fastfetch", "starship", "btop", "adw-gtk-theme",
            "papirus-icon-theme", "ttf-jetbrains-mono-nerd", "ttf-material-symbols-variable", "ttf-rubik-vf", "ttf-cascadia-code-nerd", "darkly", "swappy",
            "brightnessctl", "ddcutil", "imagemagick", "tesseract", "tesseract-data-eng", "satty", "spectacle", "sassc", "kvantum", "kvantum-qt5",
            "kde-material-you-colors", "keyd",
        ]
        fedora_packages = [
            "quickshell-git", "caelestia-cli", "cmake", "ninja-build", "wl-clipboard", "cliphist", "inotify-tools", "app2unit", "wireplumber", "trash-cli",
            "jq", "aubio", "lm_sensors", "lm_sensors-devel", "libcava", "libcava-devel", "libqalculate", "libqalculate-devel", "foot", "fish", "eza",
            "fastfetch", "starship", "btop", "adw-gtk3-theme", "google-rubik-fonts", "papirus-icon-theme", "swappy", "brightnessctl", "ddcutil",
            "imagemagick", "tesseract", "tesseract-langpack-eng", "spectacle", "fuzzel", "satty", "slurp", "grim", "sassc", "ffmpeg", "gpu-screen-recorder",
            "qt6-qtdeclarative", "qt6-qtdeclarative-devel", "qt6-qtsvg", "qt6-qtsvg-devel", "qt6-qtshadertools-devel", "pipewire-devel", "aubio-devel",
            "dbus-devel", "dbus-glib-devel", "python3-devel", "kvantum", "kde-material-you-colors", "keyd",
        ]

        if self.base_distro == "arch":
            UI.warn("The following packages will be removed:")
            for pkg in arch_packages:
                print(f"  {pkg}")
            print()
            if UI.prompt_yes_no("Proceed?", default=False):
                proc = subprocess.run(["yay", "-Qq", *arch_packages], capture_output=True, text=True)
                installed = [x.strip() for x in proc.stdout.splitlines() if x.strip()]
                if installed:
                    self._run(["yay", "-Rns", "--noconfirm", *installed], check=False)
                UI.ok("Arch packages removed")
            else:
                UI.skip("Package removal skipped")
        elif self.base_distro == "fedora":
            UI.warn("The following packages will be removed:")
            for pkg in fedora_packages:
                print(f"  {pkg}")
            print()
            if UI.prompt_yes_no("Proceed?", default=False):
                self._run(["sudo", "dnf", "remove", "-y", *fedora_packages], check=False)
                UI.ok("Fedora packages removed")
            else:
                UI.skip("Package removal skipped")

        self._run(["sudo", "pip3", "uninstall", "-y", "caelestia"], check=False)
        self._run(["pip3", "uninstall", "-y", "caelestia"], check=False)
        UI.ok("Removed caelestia pip package")

        if shutil.which("uv"):
            self._run(["uv", "tool", "uninstall", "kde-material-you-colors"], check=False)
            UI.ok("Removed kde-material-you-colors (uv)")

        if shutil.which("kpackagetool6"):
            if self._run(["kpackagetool6", "-t", "KWin/Script", "-s", "polonium"], check=False) == 0:
                self._run(["kpackagetool6", "-t", "KWin/Script", "-r", "polonium"], check=False)
                UI.ok("Removed Polonium KWin script")

    def step10_cleanup_cache_and_build_dirs(self) -> None:
        UI.section("Step 10/11 - Clean up cache & build artefacts")
        for build_dir in [self.cfg.bundle_dir / "shell" / "build", self.cfg.bundle_dir / "shell" / "plugin" / "build"]:
            if build_dir.exists():
                shutil.rmtree(build_dir, ignore_errors=True)
                UI.ok(f"Removed build dir: {build_dir}")

        cache_dir = Path(os.environ.get("XDG_CACHE_HOME", str(Path.home() / ".cache"))) / "caelestia-kde"
        if cache_dir.exists():
            if UI.prompt_yes_no(f"Remove installer cache at {cache_dir}?", default=False):
                shutil.rmtree(cache_dir, ignore_errors=True)
                UI.ok("Removed installer cache")
            else:
                UI.skip(f"Kept installer cache at {cache_dir}")

    def step11_reload_kde(self) -> None:
        UI.section("Step 11/11 - Reload KDE")
        self._run(["qdbus6", "org.kde.KWin", "/KWin", "reconfigure"], check=False)
        self._run(["systemctl", "--user", "restart", "plasma-kglobalaccel.service"], check=False)
        self._run(["kbuildsycoca6", "--noincremental"], check=False)
        if shutil.which("lookandfeeltool"):
            self._run(["lookandfeeltool", "--apply", "org.kde.breeze.desktop"], check=False)
        UI.ok("KDE reloaded")

    def finish(self) -> None:
        print()
        UI.section("Caelestia KDE has been uninstalled.", "", UI.GREEN)
        print()
        print(f"  Backups of your original configs are in:  {UI.BOLD}{self.cfg.bundle_dir / 'backups'}{UI.RST}")
        print()
        print(f"{UI.YELLOW}  Please log out and back in to fully apply all changes.{UI.RST}")
        print()

        if UI.prompt_yes_no("Would you like to log out now?", default=False):
            print("Logging out...")
            self._run(["qdbus6", "org.kde.Shutdown", "/Shutdown", "org.kde.Shutdown.logout"], check=False)
        else:
            print("Exiting script. Please remember to log out manually later.")

    def _is_valid_shell(self, shell: str) -> bool:
        shells = Path("/etc/shells")
        if not shells.exists():
            return False
        return any(line.strip() == shell for line in shells.read_text(encoding="utf-8", errors="ignore").splitlines())

    def _run(self, command: list[str], *, check: bool = True) -> int:
        proc = subprocess.run(command, env=self.env)
        if check and proc.returncode != 0:
            raise RuntimeError(f"Command failed ({proc.returncode}): {' '.join(command)}")
        return proc.returncode
