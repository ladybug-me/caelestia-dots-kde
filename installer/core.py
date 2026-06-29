#!/usr/bin/env python3
"""Unified Python installer for the Caelestia KDE port.

This script ports the setup.sh workflow and step scripts to Python while
preserving behavior, prompts, and failure tracking.
"""

from __future__ import annotations

import atexit
import base64
import getpass
import glob
import os
import re
import shutil
import subprocess
import sys
import tempfile
import threading
import time
from pathlib import Path
from typing import Callable, Iterable

from .config import InstallerConfig
from .ui import UI

class Installer:
    def __init__(self, cfg: InstallerConfig) -> None:
        self.cfg = cfg
        self.env = os.environ.copy()
        self.sudo_password = ""
        self._sudo_stop = threading.Event()
        self._sudo_thread: threading.Thread | None = None

    def run(self) -> None:
        self.print_banner()
        self.init_cache_dirs()
        self.detect_distro()
        self.prompt_preferences()
        self.collect_sudo_password()
        self.grant_temp_nopasswd()

        self.step0_system_update()
        self.run_step("Ensure prerequisites", self.step1_ensure_prereqs)
        self.run_step("Package installation", self.step2_packages)
        self.run_step("Backup KDE Themes", self.step3_backup_themes)
        self.run_step("Config deployment", self.step3_deploy_configs)
        self.run_step("KDE settings", self.step4_kde_settings)
        self.run_step("Keyboard shortcuts", self.step5_keyboard_shortcuts)
        self.run_step("Services", self.step6_services)
        self.run_step("KDE theme apps", self.step7_kde_apps)
        self.run_step("Build Caelestia Shell", self.step8_build_shell)
        self.run_step("System tweaks", self.step9_system_tweaks)
        self.run_step("Autostart", self.step10_autostart)

        if self.cfg.remove_cache:
            UI.info("Cleaning up downloaded packages and build files...")
            shutil.rmtree(self.cfg.cache_dir, ignore_errors=True)
            UI.ok("Downloaded packages and build files removed.")

        self.run_step("Finalize", self.step11_finalize)

    def print_banner(self) -> None:
        print()
        UI.separator()
        print(f"{UI.BOLD}Caelestia KDE Port{UI.RST}")
        print("Unified installer for the KDE Plasma port.")
        print("Original Hyprland dots: fufexan/dotfiles")
        print("KDE port and modifications: ladybug-me")
        UI.separator()
        print()
        print("Existing configs are backed up automatically before changes.")
        print()

    def init_cache_dirs(self) -> None:
        for path in [
            self.cfg.cache_dir,
            self.cfg.builddir,
            self.cfg.pkgdest,
            self.cfg.srcdest,
            self.cfg.srcpkgdest,
        ]:
            path.mkdir(parents=True, exist_ok=True)

        for path in [self.cfg.failed_steps_file, self.cfg.failed_packages_file]:
            if path.exists():
                path.unlink()

        self.env.update(
            {
                "BUNDLE_DIR": str(self.cfg.bundle_dir),
                "CACHE_DIR": str(self.cfg.cache_dir),
                "BUILDDIR": str(self.cfg.builddir),
                "PKGDEST": str(self.cfg.pkgdest),
                "SRCDEST": str(self.cfg.srcdest),
                "SRCPKGDEST": str(self.cfg.srcpkgdest),
                "CONFIRM_ARG": self.cfg.confirm_arg,
            }
        )

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
            UI.warn("Could not automatically detect your distribution base.")
            print("Please select your base distribution:")
            print("  1) Arch-based")
            print("  2) Fedora")
            print("  3) Exit")
            choice = input("Enter choice [1-3]: ").strip()
            if choice == "1":
                distro = "arch"
            elif choice == "2":
                distro = "fedora"
            else:
                UI.die("Exiting installer.")

        if distro == "arch" and shutil.which("pacman") is None:
            UI.die("pacman not found. This installer requires Arch Linux or an Arch-based distro.")
        if distro == "fedora" and shutil.which("dnf") is None:
            UI.die("dnf not found. This installer requires Fedora or a Fedora-based distro.")

        self.cfg.base_distro = distro
        self.env["BASE_DISTRO"] = distro

    def prompt_preferences(self) -> None:
        UI.section("Installer preferences")
        options: list[tuple[str, str]] = [
            ("polonium_enabled", "Enable Polonium tiling"),
            ("remove_cache", "Remove downloaded packages and build files after installation"),
            ("apply_darkly", "Apply Darkly theme (Plasma, decorations, Kvantum, Bibata cursors)"),
            ("apply_material_you", "Enable Material You colors (kde-material-you-colors daemon)"),
            ("apply_fonts", "Apply included custom fonts (lookandfeeltool)"),
        ]

        selected = 0
        max_item = len(options)

        def render() -> None:
            UI.clear_screen()
            UI.separator()
            print("  Configure installation options")
            UI.separator()
            print()
            for idx, (attr, label) in enumerate(options):
                marker = ">" if selected == idx else " "
                mark = "[x]" if getattr(self.cfg, attr) else "[ ]"
                print(f" {marker} {mark} {label}")
            marker = ">" if selected == max_item else " "
            print(f" {marker} [ ] Continue")
            print()
            print(f"{UI.DIM}Controls: Up/Down to navigate, Space/Enter to toggle, Enter on Continue to proceed.{UI.RST}")

        with UI.hidden_cursor():
            while True:
                render()
                key = UI.read_key()

                if key in {"UP", "k"}:
                    selected = max(0, selected - 1)
                    continue
                if key in {"DOWN", "j", "TAB"}:
                    selected = min(max_item, selected + 1)
                    continue
                if key in {"SPACE", "ENTER"}:
                    if selected == max_item:
                        break
                    attr = options[selected][0]
                    setattr(self.cfg, attr, not getattr(self.cfg, attr))
                    continue
                if key in {"1", "2", "3", "4", "5"}:
                    idx = int(key) - 1
                    attr = options[idx][0]
                    setattr(self.cfg, attr, not getattr(self.cfg, attr))

        UI.clear_screen()

        if self.cfg.polonium_enabled:
            UI.warn("Polonium may cause close, maximize, and minimize buttons to be unresponsive.")
            UI.warn("You may need to use Alt+F4 to close applications.")
            if not UI.prompt_yes_no("Keep Polonium enabled?", default=True):
                self.cfg.polonium_enabled = False

        self.env.update(
            {
                "POLONIUM_ENABLED": str(self.cfg.polonium_enabled).lower(),
                "REMOVE_CACHE": str(self.cfg.remove_cache).lower(),
                "APPLY_DARKLY": str(self.cfg.apply_darkly).lower(),
                "APPLY_MATERIAL_YOU": str(self.cfg.apply_material_you).lower(),
                "APPLY_FONTS": str(self.cfg.apply_fonts).lower(),
            }
        )

        print()
        UI.section("Preference summary")
        print(f"  Polonium tiling: {str(self.cfg.polonium_enabled).lower()}")
        print(f"  Remove downloaded packages/cache: {str(self.cfg.remove_cache).lower()}")
        print(f"  Apply Darkly theme: {str(self.cfg.apply_darkly).lower()}")
        print(f"  Enable Material You colors: {str(self.cfg.apply_material_you).lower()}")
        print(f"  Apply included custom fonts: {str(self.cfg.apply_fonts).lower()}")

    def collect_sudo_password(self) -> None:
        print(f"{UI.YELLOW}This installer needs sudo for package installation.{UI.RST}")
        while True:
            pw = getpass.getpass("Please enter your sudo password: ")
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
                self.env["SUDO_PASS"] = pw
                break
            print(f"{UI.RED}[ERROR] Incorrect password. Please try again.{UI.RST}")

        self.start_sudo_keepalive()

    def start_sudo_keepalive(self) -> None:
        def worker() -> None:
            while not self._sudo_stop.is_set():
                self._run(["sudo", "-n", "true"], check=False)
                self._sudo_stop.wait(55)

        self._sudo_thread = threading.Thread(target=worker, daemon=True)
        self._sudo_thread.start()

    def grant_temp_nopasswd(self) -> None:
        rule = f"{os.environ.get('USER', '')} ALL=(ALL) NOPASSWD: ALL\n"
        self._run(
            [
                "sudo",
                "sh",
                "-c",
                "cat > /etc/sudoers.d/caelestia-installer-temp && chmod 0440 /etc/sudoers.d/caelestia-installer-temp",
            ],
            input_text=rule,
        )

        def cleanup() -> None:
            self._run(["sudo", "rm", "-f", "/etc/sudoers.d/caelestia-installer-temp"], check=False)
            self._sudo_stop.set()

        atexit.register(cleanup)

    def run_step(self, name: str, fn: Callable[[], None]) -> None:
        while True:
            print()
            UI.info(f"Running: {name}")
            self._run(["sudo", "-n", "true"], check=False)
            try:
                fn()
                UI.ok(f"{name} - done")
                return
            except Exception as exc:
                UI.warn(f"{name} - encountered errors: {exc}")
                while True:
                    action = input("Choose an action: [r]etry, [i]gnore, [e]xit: ").strip().lower()
                    if action in {"r", "retry"}:
                        UI.info(f"Retrying {name}...")
                        break
                    if action in {"i", "ignore"}:
                        self._append_line(self.cfg.failed_steps_file, name)
                        UI.info("Ignoring error and continuing...")
                        return
                    if action in {"e", "exit"}:
                        UI.die("Aborting installation.")
                    UI.warn("Please enter r, i, or e.")

    def step0_system_update(self) -> None:
        print()
        if self.cfg.base_distro == "arch":
            UI.section("Step 0 - System Update", "pacman -Syu")
            UI.info("Running sudo pacman -Syu to bring the system up to date first...")
            code = self._run(["sudo", "pacman", "-Syu", "--noconfirm"], check=False)
            if code == 0:
                UI.ok("System is up to date.")
            else:
                UI.warn("pacman -Syu encountered errors. Continuing anyway...")
        else:
            UI.section("Step 0 - System Update", "dnf upgrade")
            UI.info("Running sudo dnf upgrade --refresh -y to bring the system up to date first...")
            code = self._run(["sudo", "dnf", "upgrade", "--refresh", "-y"], check=False)
            if code == 0:
                UI.ok("System is up to date.")
            else:
                UI.warn("dnf upgrade encountered errors. Continuing anyway...")

    def step1_ensure_prereqs(self) -> None:
        UI.section("Step 1/11 - Prerequisites")
        if self.cfg.base_distro == "arch":
            if shutil.which("yay"):
                UI.ok("yay is already installed.")
            else:
                UI.info("yay not found. Installing...")
                if shutil.which("pacman") is None:
                    raise RuntimeError("pacman not found. This installer requires Arch Linux.")
                self._run(["sudo", "pacman", "-S", "--needed", "--noconfirm", "base-devel", "git"])
                tmpdir = Path(tempfile.mkdtemp())
                try:
                    self._run(["git", "clone", "https://aur.archlinux.org/yay-bin.git", str(tmpdir)])
                    self._run(["bash", "-lc", f"cd {self._q(tmpdir)} && makepkg -si --noconfirm"])
                finally:
                    shutil.rmtree(tmpdir, ignore_errors=True)
                UI.ok("yay installed.")

            UI.info("Configuring yay sudo looping and disabling interactive menus...")
            help_proc = subprocess.run(
                ["yay", "-Y", "--help"],
                capture_output=True,
                text=True,
                env=self.env,
            )
            help_text = (help_proc.stdout or "") + (help_proc.stderr or "")
            yay_args = ["yay", "-Y", "--sudoloop"]
            if "--nocleanmenu" in help_text:
                yay_args.append("--nocleanmenu")
            if "--nodiffmenu" in help_text:
                yay_args.append("--nodiffmenu")
            yay_args.append("--save")
            self._run(yay_args, check=False)
            UI.ok("yay configured.")
        else:
            UI.info("Checking for Fedora prerequisites (dnf, yq, createrepo_c, jq)...")
            if shutil.which("dnf") is None:
                raise RuntimeError("dnf not found. This installer requires Fedora 42 or later.")

            needed = ["yq", "createrepo_c", "jq"]
            if all(shutil.which(x) for x in needed):
                UI.ok("Prerequisites are already installed.")
                return

            UI.info("Missing prerequisites. Installing...")
            self._run(["sudo", "dnf", "install", "-y", *needed])
            UI.ok("Prerequisites installed.")

    def step2_packages(self) -> None:
        UI.section("Step 2/11 - Packages")
        if self.cfg.base_distro == "arch":
            UI.info("Installing from local package list (Arch)...")
            self._install_arch_packages()
        else:
            UI.info("Installing from local package list (Fedora)...")
            self._install_fedora_packages()
            UI.info("Applying Fedora compatibility symlinks...")
            if not Path("/usr/local/bin/qdbus6").is_symlink():
                self._run(["sudo", "ln", "-s", "/usr/bin/qdbus-qt6", "/usr/local/bin/qdbus6"], check=False)

        if self.cfg.polonium_enabled:
            UI.info("Installing Polonium KWin script...")
            if shutil.which("kpackagetool6") is None:
                UI.warn("kpackagetool6 not found. Ensure KDE Plasma development/package tools are installed.")
            else:
                tmpdir = Path(tempfile.mkdtemp())
                pkg = tmpdir / "polonium.kwinscript"
                try:
                    code = self._run(
                        [
                            "curl",
                            "-sL",
                            "https://github.com/zeroxoneafour/polonium/releases/latest/download/polonium.kwinscript",
                            "-o",
                            str(pkg),
                        ],
                        check=False,
                    )
                    if code == 0:
                        check_code = self._run(["kpackagetool6", "-t", "KWin/Script", "-s", "polonium"], check=False)
                        if check_code == 0:
                            self._run(["kpackagetool6", "-t", "KWin/Script", "-u", str(pkg)], check=False)
                        else:
                            self._run(["kpackagetool6", "-t", "KWin/Script", "-i", str(pkg)], check=False)
                        UI.ok("Polonium installed.")
                    else:
                        UI.warn("Failed to download Polonium.")
                finally:
                    shutil.rmtree(tmpdir, ignore_errors=True)

        UI.ok("Package installation complete.")

    def step3_backup_themes(self) -> None:
        UI.section("Backup KDE theme settings")
        UI.info("Backing up current KDE theme configurations...")
        backup_file = Path.home() / ".config" / "caelestia-theme-backup.conf"
        backup_file.parent.mkdir(parents=True, exist_ok=True)
        backup_file.unlink(missing_ok=True)

        targets = [
            ("plasmarc", "Theme", "name"),
            ("kdeglobals", "KDE", "widgetStyle"),
            ("kdeglobals", "General", "ColorScheme"),
            ("kwinrc", "org.kde.kdecoration2", "library"),
            ("kwinrc", "org.kde.kdecoration2", "theme"),
            ("kcminputrc", "Mouse", "cursorTheme"),
        ]

        for file_, group, key in targets:
            if shutil.which("kreadconfig6") is None:
                continue
            proc = subprocess.run(
                ["kreadconfig6", "--file", file_, "--group", group, "--key", key],
                capture_output=True,
                text=True,
                env=self.env,
            )
            val = proc.stdout.strip()
            if not val:
                continue
            encoded = base64.b64encode(val.encode()).decode()
            self._append_line(backup_file, f"{file_}|{group}|{key}={encoded}")

        UI.ok(f"KDE theme settings backed up to {backup_file}")

    def step3_deploy_configs(self) -> None:
        UI.section("Step 3/11 - Config Deployment")
        src_dir = self.cfg.bundle_dir / "src"
        backup_dir = self.cfg.bundle_dir / "backups" / time.strftime("%Y%m%d_%H%M%S")
        (backup_dir / "config").mkdir(parents=True, exist_ok=True)
        (backup_dir / "local").mkdir(parents=True, exist_ok=True)

        UI.info("Recording previous login shell...")
        proc = subprocess.run(["getent", "passwd", os.environ.get("USER", "")], capture_output=True, text=True)
        if proc.returncode == 0 and proc.stdout.strip():
            shell = proc.stdout.strip().split(":")[-1]
            (backup_dir / "previous_shell.txt").write_text(shell + "\n", encoding="utf-8")

        UI.info("Backing up the entire ~/.config folder...")
        cfg_dir = Path.home() / ".config"
        if cfg_dir.exists():
            self._run(["bash", "-lc", f"cp -r {self._q(cfg_dir)} {self._q(backup_dir)}"], check=False)

        UI.info("Deploying Caelestia configs...")
        for name in ["btop", "fastfetch", "fish", "foot", "hypr", "kitty", "micro", "thunar"]:
            source = src_dir / "dots" / name
            dest = cfg_dir / name
            if source.is_dir():
                shutil.rmtree(dest, ignore_errors=True)
                shutil.copytree(source, dest)
                UI.ok(f"Deployed: {name}")

        starship = src_dir / "dots" / "starship.toml"
        if starship.is_file():
            shutil.copy2(starship, cfg_dir / "starship.toml")
            UI.ok("Deployed: starship.toml")

        UI.info("Backing up Konsole config...")
        konsole = Path.home() / ".local" / "share" / "konsole"
        if konsole.exists():
            self._run(["bash", "-lc", f"cp -r {self._q(konsole)} {self._q(backup_dir / 'local')}"], check=False)

        UI.info("Deploying bridge files (bin, applications, systemd, kwin script)...")
        (Path.home() / ".local" / "bin").mkdir(parents=True, exist_ok=True)
        (Path.home() / ".local" / "share" / "applications").mkdir(parents=True, exist_ok=True)
        (Path.home() / ".config" / "systemd" / "user").mkdir(parents=True, exist_ok=True)
        (Path.home() / ".local" / "share" / "kwin" / "scripts").mkdir(parents=True, exist_ok=True)

        src_bin = src_dir / "bin"
        if src_bin.is_dir():
            for child in src_bin.iterdir():
                if child.is_file():
                    shutil.copy2(child, Path.home() / ".local" / "bin" / child.name)
            for cmd in ["hyprctl", "kcolorpicker", "qs-kwin-bridge.py"]:
                target = Path.home() / ".local" / "bin" / cmd
                if target.exists():
                    target.chmod(target.stat().st_mode | 0o111)

        svc_src = src_dir / "systemd" / "qs-kwin-bridge.service"
        if svc_src.exists() and svc_src.stat().st_size > 0:
            shutil.copy2(svc_src, Path.home() / ".config" / "systemd" / "user" / svc_src.name)

        kwin_src = src_dir / "kwin" / "quickshell-kde-bridge"
        if kwin_src.is_dir():
            dst = Path.home() / ".local" / "share" / "kwin" / "scripts" / "quickshell-kde-bridge"
            shutil.rmtree(dst, ignore_errors=True)
            shutil.copytree(kwin_src, dst)

        self._run(["update-desktop-database", str(Path.home() / ".local" / "share" / "applications")], check=False)
        UI.ok("Bridge files deployed.")
        UI.ok("Config deployment complete.")

    def _set_config(self, *args: str) -> None:
        self._run(["kwriteconfig6", *args], check=False)

    def step4_kde_settings(self) -> None:
        UI.section("Step 4/11 - KDE Settings")
        if self.cfg.apply_darkly:
            UI.info("Applying Darkly plasma style...")
            self._set_config("--file", "plasmarc", "--group", "Theme", "--key", "name", "Darkly")
            UI.info("Applying Darkly application style...")
            self._set_config("--file", "kdeglobals", "--group", "KDE", "--key", "widgetStyle", "darkly")
            self._set_config("--file", "kdeglobals", "--group", "General", "--key", "ColorScheme", "Darkly")
            UI.info("Applying Darkly window decoration...")
            self._set_config("--file", "kwinrc", "--group", "org.kde.kdecoration2", "--key", "library", "org.kde.darkly")
            self._set_config("--file", "kwinrc", "--group", "org.kde.kdecoration2", "--key", "library", "org.kde.breeze")
            self._set_config("--file", "kwinrc", "--group", "org.kde.kdecoration2", "--key", "theme", "@darkly")
            UI.info("Applying Bibata cursor theme...")
            self._set_config("--file", "kcminputrc", "--group", "Mouse", "--key", "cursorTheme", "Bibata-Modern-Ice")
        else:
            UI.skip("Skipping Darkly theme and Bibata cursor application.")

        UI.info(f"Configuring Polonium (tiling), enabled={str(self.cfg.polonium_enabled).lower()}...")
        self._set_config("--file", "kwinrc", "--group", "Plugins", "--key", "poloniumEnabled", str(self.cfg.polonium_enabled).lower())
        UI.info("Enabling quickshell-kde-bridge KWin script...")
        self._set_config("--file", "kwinrc", "--group", "Plugins", "--key", "quickshell-kde-bridgeEnabled", "true")

        UI.info("Setting up 5 virtual desktops...")
        self._set_config("--file", "kwinrc", "--group", "Desktops", "--key", "Number", "5")
        self._set_config("--file", "kwinrc", "--group", "Desktops", "--key", "Rows", "1")
        for idx in range(1, 6):
            self._set_config("--file", "kwinrc", "--group", "Desktops", "--key", f"Name_{idx}", f"Desktop {idx}")
        UI.ok("5 virtual desktops configured.")

        UI.info("Disabling KDE OSD popups...")
        self._set_config("--file", "plasmarc", "--group", "OSD", "--key", "Enabled", "false")
        self._set_config("--file", "kdeglobals", "--group", "KDE", "--key", "OSDEnabled", "false")
        self._set_config("--file", "plasmanotifyrc", "--group", "Notifications", "--key", "LoudnessChangedOSD", "false")
        self._set_config("--file", "powerdevilrc", "--group", "BrightnessControl", "--key", "showOSD", "false")
        self._set_config("--file", "powerdevilrc", "--group", "AC", "--key", "brightnessosd", "false")
        self._set_config("--file", "plasmarc", "--group", "OSD", "--key", "ShowOnActiveScreen", "false")

        kmix = Path.home() / ".config" / "kmixrc"
        kmix.parent.mkdir(parents=True, exist_ok=True)
        kmix.write_text("[Global]\nShowOSD=false\n", encoding="utf-8")
        UI.ok("KDE OSDs disabled.")

        if self.cfg.apply_fonts:
            if shutil.which("lookandfeeltool"):
                if self.cfg.apply_darkly:
                    UI.info("Applying custom fonts and look and feel via lookandfeeltool...")
                    self._run(["lookandfeeltool", "--apply", "Darkly"], check=False)
                else:
                    UI.skip("Skipping Darkly look and feel because the theme was opted out. Fonts must be applied manually.")
        else:
            UI.skip("Skipping custom fonts application.")

        UI.info("Setting up cliphist background service...")
        svc = Path.home() / ".config" / "systemd" / "user" / "cliphist.service"
        svc.parent.mkdir(parents=True, exist_ok=True)
        svc.write_text(
            """[Unit]\nDescription=Clipboard history service\nAfter=graphical-session.target\n\n[Service]\nType=simple\nExecStart=/bin/bash -c \"wl-paste --type text --watch cliphist store & wl-paste --type image --watch cliphist store & wait\"\nRestart=always\nRestartSec=3\n\n[Install]\nWantedBy=default.target\n""",
            encoding="utf-8",
        )
        self._run(["systemctl", "--user", "daemon-reload"], check=False)
        self._run(["systemctl", "--user", "enable", "--now", "cliphist.service"], check=False)
        UI.ok("Cliphist background service enabled.")

        UI.ok("KDE settings applied.")

        UI.info("Setting default wallpaper to Minimal-Paper.png...")
        wallpaper = self.cfg.bundle_dir / "shell" / "assets" / "wallpapers" / "Minimal-Paper.png"
        if wallpaper.is_file():
            script = (
                "var allDesktops = desktops();"
                "for (i = 0; i < allDesktops.length; i++) {"
                "d = allDesktops[i];"
                "d.wallpaperPlugin = 'org.kde.image';"
                "d.currentConfigGroup = Array('Wallpaper', 'org.kde.image', 'General');"
                f"d.writeConfig('Image', 'file://{wallpaper}');"
                "}"
            )
            self._run(
                [
                    "qdbus6",
                    "org.kde.plasmashell",
                    "/PlasmaShell",
                    "org.kde.PlasmaShell.evaluateScript",
                    script,
                ],
                check=False,
            )
            state_dir = Path.home() / ".local" / "share" / "caelestia" / "state" / "wallpaper"
            state_dir.mkdir(parents=True, exist_ok=True)
            (state_dir / "path.txt").write_text(str(wallpaper) + "\n", encoding="utf-8")

    def step5_keyboard_shortcuts(self) -> None:
        UI.section("Step 5/11 - Keyboard Shortcuts & Workspaces")
        config_file = Path.home() / ".config" / "kglobalshortcutsrc"
        script_dir = self.cfg.bundle_dir / "src" / "keyboardshortcuts"
        shortcuts_md = script_dir / "shortcuts.md"
        backup_dir = self.cfg.bundle_dir / "backups"
        backup_file = backup_dir / f"kglobalshortcutsrc_{time.strftime('%Y%m%d_%H%M%S')}"

        UI.info("Step 0: Checking for keyd...")
        if shutil.which("keyd") is None:
            if self.cfg.base_distro == "arch":
                UI.warn("keyd not found. Attempting to install keyd via yay...")
                self._run(["yay", "-S", "--noconfirm", "keyd"])
            else:
                UI.warn("keyd not found. Attempting to install keyd via dnf from COPR...")
                self._run(["sudo", "dnf", "copr", "enable", "alternateved/keyd", "-y"], check=False)
                self._run(["sudo", "dnf", "install", "-y", "keyd"])
            UI.ok("keyd installed.")
        else:
            UI.ok("keyd is already installed.")

        self._run(["sudo", "systemctl", "disable", "--now", f"swhkd@{os.environ.get('USER', '')}.service"], check=False)
        self._run(["systemctl", "--user", "disable", "--now", "swhks.service"], check=False)

        UI.info("Step 1: Resolving shortcut collisions in KDE...")
        if config_file.exists() and shortcuts_md.exists():
            backup_dir.mkdir(parents=True, exist_ok=True)
            shutil.copy2(config_file, backup_file)
            self._resolve_shortcut_collisions(shortcuts_md, config_file)
            UI.ok("KDE collision check complete.")
        else:
            UI.warn("kglobalshortcutsrc or configuration not found - skipping collision check.")

        UI.info("Step 2: Deploying keyd configuration...")
        if not shortcuts_md.exists():
            raise RuntimeError(f"shortcuts.md not found at {shortcuts_md}")

        keyd_conf = self._build_keyd_config(shortcuts_md)
        tmp_out = Path(tempfile.gettempdir()) / "quickshell.conf"
        tmp_out.write_text(keyd_conf, encoding="utf-8")

        self._run(["sudo", "mkdir", "-p", "/etc/keyd"])
        self._run(["sudo", "cp", str(tmp_out), "/etc/keyd/quickshell.conf"])
        self._run(["sudo", "systemctl", "enable", "keyd"])
        self._run(["sudo", "systemctl", "restart", "keyd"])

        UI.ok("keyd native configuration deployed.")
        UI.info("Step 3: Reloading KDE shortcut daemon...")
        self._run(["kbuildsycoca6", "--noincremental"], check=False)
        self._run(["systemctl", "--user", "restart", "plasma-kglobalaccel.service"], check=False)
        UI.ok("KDE reloaded.")

    def step6_services(self) -> None:
        UI.section("Step 6/11 - Services and KWin")
        svc = Path.home() / ".config" / "systemd" / "user" / "qs-kwin-bridge.service"
        if svc.exists() and svc.stat().st_size > 0:
            UI.info("Enabling qs-kwin-bridge service...")
            self._run(["systemctl", "--user", "daemon-reload"], check=False)
            self._run(["systemctl", "--user", "enable", "--now", "qs-kwin-bridge.service"], check=False)
            UI.ok("qs-kwin-bridge enabled.")
        else:
            UI.skip("qs-kwin-bridge.service is empty or missing.")

        UI.info("Setting up ydotoold (OSK key injection daemon)...")
        rule = Path("/etc/udev/rules.d/80-uinput.rules")
        if not rule.exists():
            self._run(["sudo", "sh", "-c", 'echo \"KERNEL==\\\"uinput\\\", GROUP=\\\"input\\\", MODE=\\\"0660\\\"\" > /etc/udev/rules.d/80-uinput.rules'])
            self._run(["sudo", "udevadm", "control", "--reload-rules"], check=False)
            self._run(["sudo", "udevadm", "trigger"], check=False)
            UI.ok("udev rule for uinput created.")

        user = os.environ.get("USER", "")
        groups = subprocess.run(["groups", user], capture_output=True, text=True).stdout
        if " input " not in f" {groups} ":
            self._run(["sudo", "usermod", "-aG", "input", user])
            UI.ok(f"Added {user} to input group (takes effect on next login).")
        else:
            UI.ok(f"{user} is already in the input group.")

        self._run(["sudo", "sh", "-c", f'echo "{user} ALL=(root) NOPASSWD: /usr/bin/ydotoold" > /etc/sudoers.d/ydotoold-nopasswd'])
        self._run(["sudo", "chmod", "440", "/etc/sudoers.d/ydotoold-nopasswd"])
        UI.ok("sudoers NOPASSWD rule updated for ydotoold.")

        self._run(["sudo", "chmod", "660", "/dev/uinput"], check=False)
        self._run(["sudo", "chgrp", "input", "/dev/uinput"], check=False)

        wrapper = Path.home() / ".local" / "bin" / "ydotoold-wrapper"
        wrapper.parent.mkdir(parents=True, exist_ok=True)
        wrapper.write_text(
            """#!/bin/bash\nSOCKET=\"${YDOTOOL_SOCKET:-/run/user/$(id -u)/.ydotool_socket}\"\nif [ -S \"$SOCKET\" ] && pidof ydotoold > /dev/null 2>&1; then\n    exit 0\nfi\nexec sudo /usr/bin/ydotoold --socket-path=\"$SOCKET\" --socket-perm=0666\n""",
            encoding="utf-8",
        )
        wrapper.chmod(wrapper.stat().st_mode | 0o111)
        UI.ok("ydotoold-wrapper deployed to ~/.local/bin.")

        src_svc = self.cfg.bundle_dir / "src" / "systemd" / "ydotoold.service"
        if src_svc.exists():
            target = Path.home() / ".config" / "systemd" / "user" / "ydotoold.service"
            target.parent.mkdir(parents=True, exist_ok=True)
            shutil.copy2(src_svc, target)
            self._run(["systemctl", "--user", "daemon-reload"], check=False)
            self._run(["systemctl", "--user", "enable", "ydotoold.service"], check=False)
            code = self._run(["systemctl", "--user", "start", "ydotoold.service"], check=False)
            if code != 0:
                UI.info("ydotoold will start on next login.")
            UI.ok("ydotoold service configured.")

        UI.info("Reloading KWin...")
        self._run(["qdbus6", "org.kde.KWin", "/KWin", "reconfigure"], check=False)
        UI.info("Restarting plasma-kglobalaccel...")
        self._run(["systemctl", "--user", "restart", "plasma-kglobalaccel.service"], check=False)
        UI.ok("Services configured.")

    def step7_kde_apps(self) -> None:
        UI.section("Step 7/11 - KDE Theme Apps")
        self._install_if_missing("kvantum")
        self._install_if_missing("kvantum-qt5", optional=True)

        if shutil.which("uv") is None:
            UI.info("Installing uv...")
            if not self._install_if_missing("uv", optional=True):
                self._run(["bash", "-lc", "curl -LsSf https://astral.sh/uv/install.sh | sh"], check=False)

        if self.cfg.apply_material_you:
            if self.cfg.base_distro == "arch":
                self._install_if_missing("kde-material-you-colors", optional=True)
            else:
                if shutil.which("kde-material-you-colors") is None:
                    UI.info("Installing kde-material-you-colors via uv...")
                    self._run(["sudo", "dnf", "install", "-y", "dbus-devel", "dbus-glib-devel", "python3-devel"], check=False)
                    self._run(["uv", "tool", "install", "kde-material-you-colors"], check=False)
                else:
                    UI.skip("kde-material-you-colors is already installed.")
        else:
            UI.skip("Skipping kde-material-you-colors installation. Uninstalling if present...")
            self._run(["systemctl", "--user", "stop", "kde-material-you-colors.service"], check=False)
            self._run(["systemctl", "--user", "disable", "kde-material-you-colors.service"], check=False)
            if self.cfg.base_distro == "arch":
                self._run(["sudo", "pacman", "-Rs", "--noconfirm", "kde-material-you-colors"], check=False)
            else:
                self._run(["uv", "tool", "uninstall", "kde-material-you-colors"], check=False)

        self._set_config("--file", "plasmarc", "--group", "Theme", "--key", "name", "Darkly")
        UI.ok("KDE extra apps step complete.")

    def step8_build_shell(self) -> None:
        UI.section("Step 8/11 - Build Caelestia Shell")
        shell_dir = self.cfg.bundle_dir / "shell"
        if not shell_dir.is_dir():
            raise RuntimeError(f"Shell directory not found at {shell_dir}.")

        UI.info("Patching Recorder.qml to wait for portal selection...")
        patch_old = 'command: ["pidof", "gpu-screen-recorder"]'
        patch_new = (
            'command: ["sh", "-c", '
            '"pidof gpu-screen-recorder >/dev/null && test -f $HOME/.local/state/caelestia/record/recording.mp4"]'
        )
        for qml in [
            Path.home() / ".local" / "share" / "caelestia-shell" / "services" / "Recorder.qml",
            shell_dir / "services" / "Recorder.qml",
        ]:
            if qml.exists():
                text = qml.read_text(encoding="utf-8", errors="ignore")
                qml.write_text(text.replace(patch_old, patch_new), encoding="utf-8")

        UI.info("Building Caelestia Shell...")
        build_dir = shell_dir / "build"
        shutil.rmtree(build_dir, ignore_errors=True)

        self._run(
            [
                "cmake",
                "-B",
                "build",
                "-DCMAKE_BUILD_TYPE=Release",
                f"-DCMAKE_INSTALL_PREFIX={Path.home() / '.local'}",
                f"-DINSTALL_QSCONFDIR={Path.home() / '.config' / 'quickshell' / 'caelestia'}",
                "-DINSTALL_LIBDIR=lib/caelestia",
                "-DINSTALL_QMLDIR=lib/qt6/qml",
            ],
            cwd=shell_dir,
        )
        self._run(["cmake", "--build", "build", f"-j{os.cpu_count() or 1}"], cwd=shell_dir)
        self._run(["cmake", "--install", "build"], cwd=shell_dir)

        bashrc = Path.home() / ".bashrc"
        marker = "QML2_IMPORT_PATH=.*caelestia"
        if not (bashrc.exists() and re.search(marker, bashrc.read_text(encoding="utf-8", errors="ignore"))):
            with bashrc.open("a", encoding="utf-8") as fh:
                fh.write('export QML2_IMPORT_PATH="$HOME/.local/lib/qt6/qml"\n')
                fh.write('export CAELESTIA_LIB_DIR="$HOME/.local/lib/caelestia"\n')

        fish_cfg = Path.home() / ".config" / "fish" / "config.fish"
        if fish_cfg.exists() and "QML2_IMPORT_PATH" not in fish_cfg.read_text(encoding="utf-8", errors="ignore"):
            with fish_cfg.open("a", encoding="utf-8") as fh:
                fh.write('set -gx QML2_IMPORT_PATH "$HOME/.local/lib/qt6/qml"\n')
                fh.write('set -gx CAELESTIA_LIB_DIR "$HOME/.local/lib/caelestia"\n')

        UI.info("Deploying KDE bridge scripts...")
        (Path.home() / ".local" / "bin").mkdir(parents=True, exist_ok=True)
        (Path.home() / ".local" / "share" / "kwin" / "scripts").mkdir(parents=True, exist_ok=True)
        (Path.home() / ".config" / "systemd" / "user").mkdir(parents=True, exist_ok=True)

        src_bin = self.cfg.bundle_dir / "src" / "bin"
        if src_bin.is_dir():
            for child in src_bin.iterdir():
                if child.is_file():
                    dst = Path.home() / ".local" / "bin" / child.name
                    shutil.copy2(child, dst)
                    if child.name in {"hyprctl", "qs-kwin-bridge.py"}:
                        dst.chmod(dst.stat().st_mode | 0o111)

        record_sh = self.cfg.bundle_dir / "scripts" / "record.sh"
        if record_sh.exists():
            dst = Path.home() / ".local" / "bin" / "caelestia-record"
            shutil.copy2(record_sh, dst)
            dst.chmod(dst.stat().st_mode | 0o111)

        UI.info("Patching caelestia-cli to use KDE mock hyprctl...")
        if not self._patch_hypr_py():
            self._append_line(self.cfg.failed_patches_file, "Caelestia CLI Hyprctl Mock Patch")

        UI.info("Patching caelestia-cli record.py...")
        if not self._patch_record_py():
            self._append_line(self.cfg.failed_patches_file, "Caelestia CLI Record/Dolphin Patch")

        UI.ok("Caelestia Shell build and deployment complete.")

    def step9_system_tweaks(self) -> None:
        UI.section("Step 9/11 - Live System Tweaks")
        UI.info("Disabling KDE OSD popups (volume and brightness)...")
        for args in [
            ["--file", "plasmarc", "--group", "OSD", "--key", "Enabled", "false"],
            ["--file", "plasmarc", "--group", "OSD", "--key", "ShowOnActiveScreen", "false"],
            ["--file", "kdeglobals", "--group", "KDE", "--key", "OSDEnabled", "false"],
            ["--file", "plasmanotifyrc", "--group", "Notifications", "--key", "LoudnessChangedOSD", "false"],
            ["--file", "powerdevilrc", "--group", "BrightnessControl", "--key", "showOSD", "false"],
            ["--file", "powerdevilrc", "--group", "AC", "--key", "brightnessosd", "false"],
        ]:
            self._set_config(*args)

        kmix = Path.home() / ".config" / "kmixrc"
        kmix.parent.mkdir(parents=True, exist_ok=True)
        if kmix.exists():
            text = kmix.read_text(encoding="utf-8", errors="ignore")
            text = re.sub(r"^ShowOSD=.*$", "ShowOSD=false", text, flags=re.MULTILINE)
            if "ShowOSD=" not in text:
                text += "\n[Global]\nShowOSD=false\n"
            kmix.write_text(text, encoding="utf-8")
        else:
            kmix.write_text("[Global]\nShowOSD=false\n", encoding="utf-8")
        UI.ok("KDE OSD popups disabled.")

        UI.info("Configuring 5 virtual desktops...")
        self._set_config("--file", "kwinrc", "--group", "Desktops", "--key", "Number", "5")
        self._set_config("--file", "kwinrc", "--group", "Desktops", "--key", "Rows", "1")
        for idx in range(1, 6):
            self._set_config("--file", "kwinrc", "--group", "Desktops", "--key", f"Name_{idx}", f"Desktop {idx}")
        UI.ok("5 virtual desktops configured.")

        UI.info("Registering Meta+1..5 workspace switching shortcuts...")
        for idx in range(1, 6):
            self._set_config("--file", "kglobalshortcutsrc", "--group", "kwin", "--key", f"Switch to Desktop {idx}", f"Meta+{idx},none,Switch to Desktop {idx}")
            self._set_config("--file", "kglobalshortcutsrc", "--group", "kwin", "--key", f"Window to Desktop {idx}", f"Meta+Shift+{idx},none,Move Window to Desktop {idx}")
        UI.ok("Workspace shortcuts registered.")

        UI.info("Setting default shell to fish...")
        fish_path = shutil.which("fish")
        if fish_path:
            self._run(["sudo", "chsh", "-s", fish_path, os.environ.get("USER", "")], check=False)
            profile_dir = Path.home() / ".local" / "share" / "konsole"
            profile_dir.mkdir(parents=True, exist_ok=True)
            profiles = list(profile_dir.glob("*.profile"))
            if profiles:
                for profile in profiles:
                    self._set_config("--file", str(profile), "--group", "General", "--key", "Command", fish_path)
            else:
                p = profile_dir / "Profile 1.profile"
                self._set_config("--file", str(p), "--group", "General", "--key", "Name", "Profile 1")
                self._set_config("--file", str(p), "--group", "General", "--key", "Command", fish_path)
                self._set_config("--file", str(Path.home() / ".config" / "konsolerc"), "--group", "Desktop Entry", "--key", "DefaultProfile", "Profile 1.profile")
        else:
            UI.warn("Fish is not installed, skipping shell change.")
        UI.ok("Shell configuration applied.")

        UI.info("Patching caelestia CLI to fix terminal sequence bleeding...")
        if not self._patch_theme_py():
            self._append_line(self.cfg.failed_patches_file, "Caelestia CLI Theme Sequence Patch")
        else:
            UI.ok("caelestia CLI patched.")

        UI.info("Reloading KWin and plasma-kglobalaccel...")
        self._run(["qdbus6", "org.kde.KWin", "/KWin", "reconfigure"], check=False)
        self._run(["systemctl", "--user", "restart", "plasma-kglobalaccel.service"], check=False)
        self._run(["kbuildsycoca6", "--noincremental"], check=False)
        UI.ok("KDE daemons reloaded.")
        UI.ok("All system tweaks applied successfully.")

    def step10_autostart(self) -> None:
        UI.section("Step 10/11 - Autostart Setup")
        autostart = Path.home() / ".config" / "autostart"
        autostart.mkdir(parents=True, exist_ok=True)

        UI.info("Creating Caelestia Shell autostart entry...")
        (autostart / "caelestiashell.desktop").write_text(
            """[Desktop Entry]\nType=Application\nName=Caelestia Shell\nComment=Start Caelestia Shell\nExec=bash -c 'sleep 2 && caelestia shell -d &'\nIcon=quickshell\nHidden=false\nNoDisplay=false\nX-GNOME-Autostart-enabled=true\nX-KDE-AutostartPhase=2\n""",
            encoding="utf-8",
        )
        UI.ok("Quickshell autostart created.")

        UI.info("Deploying systemd service for KDE Material You Colors...")
        if self.cfg.apply_material_you:
            (autostart / "kde-material-you-colors.desktop").unlink(missing_ok=True)
            for old in (Path.home() / ".local" / "share" / "color-schemes").glob("MaterialYou*.colors"):
                old.unlink(missing_ok=True)

            svc_dir = Path.home() / ".config" / "systemd" / "user"
            svc_dir.mkdir(parents=True, exist_ok=True)
            kmyc_path = shutil.which("kde-material-you-colors") or str(Path.home() / ".local" / "bin" / "kde-material-you-colors")
            svc = svc_dir / "kde-material-you-colors.service"
            svc.write_text(
                f"""[Unit]\nDescription=KDE Material You Colors\nPartOf=graphical-session.target\nAfter=graphical-session.target\n\n[Service]\nType=simple\nExecStart={kmyc_path}\nRestart=on-failure\nRestartSec=3\n\n[Install]\nWantedBy=graphical-session.target\n""",
                encoding="utf-8",
            )
            self._run(["systemctl", "--user", "daemon-reload"], check=False)
            self._run(["systemctl", "--user", "enable", "--now", "kde-material-you-colors.service"], check=False)
            UI.ok("kde-material-you-colors systemd service enabled.")
        else:
            UI.skip("Skipping kde-material-you-colors systemd service.")

        UI.ok("Autostart entries configured.")

    def step11_finalize(self) -> None:
        UI.section("Step 11/11 - Finalize", "Installation complete", UI.GREEN)

        def step_ok(step_name: str, desc: str) -> None:
            failed = self.cfg.failed_steps_file.exists() and step_name in self.cfg.failed_steps_file.read_text(encoding="utf-8", errors="ignore")
            print(f"{'[FAILED]' if failed else '[OK]':<12} {desc}")

        def patch_ok(patch_name: str, desc: str) -> None:
            failed = self.cfg.failed_patches_file.exists() and patch_name in self.cfg.failed_patches_file.read_text(encoding="utf-8", errors="ignore")
            print(f"{'[FAILED]' if failed else '[OK]':<12} {desc}")

        print("What was set up:")
        if self.cfg.base_distro == "arch":
            print(f"{'[OK]':<12} System updated (pacman -Syu)")
        else:
            print(f"{'[OK]':<12} System updated (dnf upgrade)")

        step_ok("Package installation", "Packages installed (PKGBUILDs + fonts + dependencies)")
        step_ok("Config deployment", "Configs deployed from repo base and KDE overrides")
        step_ok("KDE settings", "Darkly theme, Kvantum, and default wallpaper")
        step_ok("System tweaks", "Virtual desktops and KDE OSD settings")
        step_ok("Keyboard shortcuts", "Keyboard shortcuts and keyd configuration")
        step_ok("Autostart", "Quickshell and kde-material-you-colors autostart")
        step_ok("Build Caelestia Shell", "Caelestia Shell built and installed")

        print("\nPatches applied:")
        patch_ok("Caelestia CLI Hyprctl Mock Patch", "Caelestia CLI Hyprctl mock patch")
        patch_ok("Caelestia CLI Record/Dolphin Patch", "Caelestia CLI record and file manager patch")
        patch_ok("Caelestia CLI Theme Sequence Patch", "Caelestia CLI theme sequence patch")

        if self.cfg.failed_packages_file.exists() and self.cfg.failed_packages_file.read_text(encoding="utf-8", errors="ignore").strip():
            print("\nFailed packages:")
            for line in self.cfg.failed_packages_file.read_text(encoding="utf-8", errors="ignore").splitlines():
                if line.strip():
                    print(f"  - {line.strip()}")

        if self.cfg.failed_steps_file.exists() and "Build Caelestia Shell" in self.cfg.failed_steps_file.read_text(encoding="utf-8", errors="ignore"):
            print("\nShell build failed. Review the terminal output and logs.")
            print("You may need to install missing dependencies manually and re-run setup.py.")

        UI.section("Action required", "Please complete the following", UI.YELLOW)
        print("1. Log out now and log back in.")
        print("   A fresh login is required to fully apply all KDE and Quickshell changes.")
        print("   If a kernel update occurred, reboot immediately.")
        print()
        print("2. Remove all KDE panels after logging back in.")
        print("   Right-click the panel, open Panel configuration, and remove every existing KDE panel for optimal behavior with the Quickshell bar.")
        print()
        print("3. To enter edit mode next time, press Super+D, then right-click on the desktop and enter edit mode.")
        print()
        print("You can re-run this installer at any time; it is idempotent.")
        print()
        print("Shortcuts not working or other problems? Check the troubleshooting steps on GitHub.")
        print()

        shutil.rmtree(self.cfg.bundle_dir / "shell" / "build", ignore_errors=True)
        shutil.rmtree(self.cfg.bundle_dir / "shell" / "plugin" / "build", ignore_errors=True)

        if UI.prompt_yes_no("Would you like to log out now?", default=False):
            print("Logging out...")
            self._run(["qdbus6", "org.kde.Shutdown", "/Shutdown", "org.kde.Shutdown.logout"], check=False)
        else:
            print("Exiting script. Please remember to log out manually later.")

    def _install_if_missing(self, pkg: str, optional: bool = False) -> bool:
        if self.cfg.base_distro == "arch":
            if self._run(["pacman", "-Qi", pkg], check=False) == 0:
                UI.skip(f"{pkg} is already installed.")
                return True
            UI.info(f"Installing {pkg}...")
            if self._run_with_retries(["yay", "-S", "--needed", self.cfg.confirm_arg, pkg], attempts=3, delay_seconds=5):
                UI.ok(f"{pkg} installed.")
                return True
            if self._run(["sudo", "pacman", "-S", "--needed", self.cfg.confirm_arg, pkg], check=False) == 0:
                UI.ok(f"{pkg} installed.")
                return True
        else:
            if self._run(["dnf", "list", "--installed", pkg], check=False) == 0:
                UI.skip(f"{pkg} is already installed.")
                return True
            UI.info(f"Installing {pkg}...")
            if self._run(["sudo", "dnf", "install", "-y", pkg], check=False) == 0:
                UI.ok(f"{pkg} installed.")
                return True

        if optional:
            UI.warn(f"Could not install {pkg}. Skipping.")
            return False
        raise RuntimeError(f"Could not install required package: {pkg}")

    def _install_arch_packages(self) -> None:
        if shutil.which("yay") is None:
            self.step1_ensure_prereqs()

        packages = [
            "cmake", "ninja", "wl-clipboard", "cliphist", "inotify-tools", "app2unit", "wireplumber", "trash-cli",
            "jq", "aubio", "lm_sensors", "libpipewire", "glibc", "libcava", "qt6-declarative", "gcc-libs",
            "qt6-base", "libqalculate", "caelestia-cli", "quickshell-git", "foot", "fish", "eza", "fastfetch",
            "starship", "btop", "bash", "adw-gtk-theme", "papirus-icon-theme", "ttf-jetbrains-mono-nerd",
            "ttf-material-symbols-variable", "ttf-rubik-vf", "ttf-cascadia-code-nerd", "darkly", "swappy",
            "brightnessctl", "ddcutil", "networkmanager", "imagemagick", "tesseract", "tesseract-data-eng",
            "satty", "spectacle", "xdg-utils", "sassc",
        ]
        self._run_with_retries(["yay", "-Syu", "--noconfirm"], attempts=3, delay_seconds=5)

        failed: list[str] = []
        for pkg in packages:
            if self._run_with_retries(["yay", "-S", "--needed", "--noconfirm", pkg], attempts=3, delay_seconds=5):
                continue
            UI.info(f"yay failed to install {pkg}. Attempting manual build from AUR...")
            tmp = Path(tempfile.mkdtemp())
            try:
                if self._run_with_retries(["git", "clone", f"https://aur.archlinux.org/{pkg}.git", str(tmp)], attempts=3, delay_seconds=5):
                    code = self._run(["bash", "-lc", f"cd {self._q(tmp)} && makepkg -si --noconfirm"], check=False)
                    if code != 0:
                        failed.append(pkg)
                else:
                    failed.append(pkg)
            finally:
                shutil.rmtree(tmp, ignore_errors=True)

        if failed:
            for pkg in failed:
                self._append_line(self.cfg.failed_packages_file, pkg)

        if shutil.which("sassc") and shutil.which("sass") is None:
            self._run(["sudo", "ln", "-sf", "/usr/bin/sassc", "/usr/local/bin/sass"], check=False)

    def _install_fedora_packages(self) -> None:
        packages = [
            "cmake", "ninja-build", "wl-clipboard", "cliphist", "inotify-tools", "wireplumber", "trash-cli", "jq",
            "aubio", "lm_sensors", "lm_sensors-devel", "pipewire-devel", "glibc", "qt6-qtdeclarative",
            "qt6-qtdeclarative-devel", "qt6-qtsvg", "qt6-qtsvg-devel", "qt6-qtshadertools-devel", "libgcc",
            "qt6-qtbase", "libqalculate", "libqalculate-devel", "aubio-devel", "foot", "fish", "eza", "fastfetch",
            "starship", "btop", "bash", "adw-gtk3-theme", "papirus-icon-theme", "google-rubik-fonts", "fuzzel",
            "swappy", "brightnessctl", "ddcutil", "NetworkManager", "ImageMagick", "tesseract",
            "tesseract-langpack-eng", "spectacle", "gpu-screen-recorder", "slurp", "grim", "xdg-utils", "sassc",
            "app2unit", "libcava", "quickshell-git",
        ]

        self._run(
            [
                "sudo",
                "dnf",
                "install",
                "-y",
                "https://mirrors.rpmfusion.org/free/fedora/rpmfusion-free-release-$(rpm -E %fedora).noarch.rpm",
                "https://mirrors.rpmfusion.org/nonfree/fedora/rpmfusion-nonfree-release-$(rpm -E %fedora).noarch.rpm",
            ],
            shell=True,
            check=False,
        )
        self._run(["sudo", "dnf", "swap", "-y", "ffmpeg-free", "ffmpeg", "--allowerasing"], check=False)
        packages.append("ffmpeg")
        self._run(["sudo", "dnf", "upgrade", "-y"], check=False)

        failed: list[str] = []
        for pkg in packages:
            if self._run(["sudo", "dnf", "install", "-y", pkg], check=False) == 0:
                continue
            if not self._fedora_copr_fallback(pkg):
                if not self._fedora_manual_fallback(pkg):
                    failed.append(pkg)

        for pkg in failed:
            self._append_line(self.cfg.failed_packages_file, pkg)

        fonts_dir = Path(os.environ.get("XDG_DATA_HOME", str(Path.home() / ".local" / "share"))) / "fonts"
        fonts_dir.mkdir(parents=True, exist_ok=True)
        self._run(
            [
                "curl",
                "-sL",
                "https://github.com/google/material-design-icons/raw/master/variablefont/MaterialSymbolsRounded%5BFILL%2CGRAD%2Copsz%2Cwght%5D.ttf",
                "-o",
                str(fonts_dir / "MaterialSymbolsRounded.ttf"),
            ],
            check=False,
        )
        self._run(["bash", "-lc", f"curl -sL https://github.com/ryanoasis/nerd-fonts/releases/download/v3.0.2/CascadiaCode.zip -o /tmp/CascadiaCode.zip && unzip -qo /tmp/CascadiaCode.zip -d {self._q(fonts_dir)} && rm -f /tmp/CascadiaCode.zip"], check=False)
        self._run(["bash", "-lc", f"curl -sL https://github.com/ryanoasis/nerd-fonts/releases/download/v3.0.2/JetBrainsMono.zip -o /tmp/JetBrainsMono.zip && unzip -qo /tmp/JetBrainsMono.zip -d {self._q(fonts_dir)} && rm -f /tmp/JetBrainsMono.zip"], check=False)
        self._run(["fc-cache", "-f"], check=False)

        if shutil.which("darkly") is None:
            self._run(["sudo", "dnf", "copr", "enable", "-y", "deltacopy/darkly"], check=False)
            self._run(["sudo", "dnf", "install", "-y", "darkly"], check=False)

        if shutil.which("caelestia") is None:
            self._run(["sudo", "dnf", "install", "-y", "python3-pip", "python3-build", "python3-installer", "python3-hatchling", "python3-hatch-vcs"], check=False)
            tmp = Path(tempfile.mkdtemp())
            try:
                self._run(["curl", "-sL", "https://github.com/caelestia-dots/cli/releases/download/v1.0.8/caelestia-1.0.8.tar.gz", "-o", str(tmp / "caelestia.tar.gz")], check=False)
                self._run(["bash", "-lc", f"cd {self._q(tmp)} && tar -xzf caelestia.tar.gz && cd caelestia-1.0.8 && python3 -m build --wheel --no-isolation && (sudo pip3 install dist/*.whl --break-system-packages || pip3 install dist/*.whl --user --break-system-packages)"], check=False)
            finally:
                shutil.rmtree(tmp, ignore_errors=True)

        if shutil.which("sassc") and shutil.which("sass") is None:
            self._run(["sudo", "ln", "-sf", "/usr/bin/sassc", "/usr/local/bin/sass"], check=False)

    def _fedora_copr_fallback(self, pkg: str) -> bool:
        copr_map = {
            "quickshell-git": ("errornointernet/quickshell", "quickshell-git"),
            "quickshell": ("errornointernet/quickshell", "quickshell-git"),
            "gpu-screen-recorder": ("brycensranch/gpu-screen-recorder-git", "gpu-screen-recorder-ui"),
            "app2unit": ("celestelove/app2unit", "app2unit"),
            "starship": ("atim/starship", "starship"),
            "libcava": ("celestelove/libcava", "libcava-devel"),
        }
        if pkg not in copr_map:
            return False
        copr, install_name = copr_map[pkg]
        return (
            self._run(["sudo", "dnf", "copr", "enable", "-y", copr], check=False) == 0
            and self._run(["sudo", "dnf", "install", "-y", install_name], check=False) == 0
        )

    def _fedora_manual_fallback(self, pkg: str) -> bool:
        tmp = Path(tempfile.mkdtemp())
        try:
            if pkg == "libcava":
                self._run(["sudo", "dnf", "install", "-y", "alsa-lib-devel", "fftw-devel", "pulseaudio-libs-devel", "iniparser-devel", "meson", "ninja-build", "cmake", "gcc-c++"], check=False)
                if self._run(["git", "clone", "https://github.com/LukashonakV/cava", str(tmp)], check=False) != 0:
                    return False
                cmd = f"cd {self._q(tmp)} && (meson setup build && meson compile -C build && sudo meson install -C build)"
                return self._run(["bash", "-lc", cmd], check=False) == 0
            if pkg == "app2unit":
                self._run(["sudo", "dnf", "install", "-y", "make"], check=False)
                if self._run(["git", "clone", "https://github.com/Vladimir-csp/app2unit", str(tmp)], check=False) != 0:
                    return False
                return self._run(["bash", "-lc", f"cd {self._q(tmp)} && sudo make install"], check=False) == 0
            if pkg == "gpu-screen-recorder":
                self._run(["sudo", "dnf", "install", "-y", "meson", "ninja-build", "pkgconf", "libXcomposite-devel", "libXrandr-devel", "libXfixes-devel", "libdrm-devel", "wayland-devel", "pipewire-devel", "libcap-devel", "ffmpeg-devel"], check=False)
                if self._run(["git", "clone", "https://git.dec05eba.com/gpu-screen-recorder", str(tmp)], check=False) != 0:
                    return False
                cmd = f"cd {self._q(tmp)} && meson setup build && ninja -C build && sudo meson install -C build"
                return self._run(["bash", "-lc", cmd], check=False) == 0
            if pkg == "starship":
                return self._run(["bash", "-lc", "curl -sS https://starship.rs/install.sh | sh -s -- -y"], check=False) == 0
            return False
        finally:
            shutil.rmtree(tmp, ignore_errors=True)

    def _patch_hypr_py(self) -> bool:
        rel = ["caelestia", "utils", "hypr.py"]
        path = self._find_site_file(rel)
        if not path:
            return False
        try:
            text = path.read_text(encoding="utf-8", errors="ignore")
        except OSError as exc:
            UI.warn(f"Could not read {path}: {exc}")
            return False
        old = """def message(msg: str, is_json: bool = True) -> str | dict[str, Any]:
    with socket.socket(socket.AF_UNIX, socket.SOCK_STREAM) as sock:
        sock.connect(socket_path)

        if is_json:
            msg = f\"j/{msg}\"
        sock.send(msg.encode())

        resp = sock.recv(8192).decode()
        while True:
            new_resp = sock.recv(8192)
            if not new_resp:
                break
            resp += new_resp.decode()

        return json.loads(resp) if is_json else resp


def dispatch(dispatcher: str, *args: str) -> bool:
    return message(f\"dispatch {dispatcher} {\" \\".join(map(str, args))}\".rstrip(), is_json=False) == \"ok\""""
        new = """import subprocess
def message(msg: str, is_json: bool = True) -> str | dict[str, Any]:
    hyprctl_path = os.path.expanduser(\"~/.local/bin/hyprctl\")
    if not os.path.exists(hyprctl_path):
        hyprctl_path = \"hyprctl\"
    args = [hyprctl_path, msg]
    if is_json:
        args.append(\"-j\")
    try:
        resp = subprocess.check_output(args, text=True)
    except Exception:
        resp = \"[]\" if is_json else \"\"
    return __import__(\"json\").loads(resp) if is_json else resp

def dispatch(dispatcher: str, *args: str) -> bool:
    hyprctl_path = os.path.expanduser(\"~/.local/bin/hyprctl\")
    if not os.path.exists(hyprctl_path):
        hyprctl_path = \"hyprctl\"
    cmd_args = [hyprctl_path, \"dispatch\", dispatcher, *args]
    try:
        subprocess.check_call(cmd_args, stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
        return True
    except subprocess.CalledProcessError:
        return False"""
        replaced = text.replace(old, new)
        if replaced == text:
            return True
        return self._write_text_with_elevation(path, replaced)

    def _patch_record_py(self) -> bool:
        rel = ["caelestia", "subcommands", "record.py"]
        path = self._find_site_file(rel)
        if not path:
            return False
        try:
            text = path.read_text(encoding="utf-8", errors="ignore")
        except OSError as exc:
            UI.warn(f"Could not read {path}: {exc}")
            return False
        text = text.replace('args += ["-a", "default_output"]', 'args += ["-a", "default_output", "-a", "default_input"]')
        text = text.replace('args += ["-f", str(max_rr)]', 'args += ["-f", str(max_rr if max_rr > 0 else 60)]')
        if "-fallback-cpu-encoding" not in text:
            text = text.replace(
                "recording_path.parent.mkdir(parents=True, exist_ok=True)",
                "recording_path.parent.mkdir(parents=True, exist_ok=True)\n        args += [\"-fallback-cpu-encoding\", \"yes\"]",
            )
        text = text.replace('args += [focused_monitor["name"], "-f",', 'args += ["portal", "-f",')
        text = text.replace("if self.args.region:", "if False:")
        text = text.replace("text=True)", "text=True).strip()")
        text = text.replace('args += ["region", "-region", region]', 'args += [region]')
        text = text.replace('["app2unit", "-O", new_path]', '["xdg-open", str(new_path)]')
        text = text.replace('["dolphin", "--select", str(new_path)]', '["xdg-open", str(new_path.parent)]')
        return self._write_text_with_elevation(path, text)

    def _patch_theme_py(self) -> bool:
        theme_file = ""
        proc = subprocess.run(
            [
                "python3",
                "-c",
                "import importlib.util; spec = importlib.util.find_spec('caelestia.utils.theme'); print(spec.origin if spec and spec.origin else '')",
            ],
            capture_output=True,
            text=True,
            env=self.env,
        )
        if proc.returncode == 0:
            theme_file = proc.stdout.strip()
        if not theme_file:
            return False

        path = Path(theme_file)
        if not path.exists():
            return False

        old = """    for pt in pts_path.iterdir():
        if pt.name.isdigit():
            try:
                # Use non-blocking write with timeout to prevent hangs"""
        new = """    for pt in pts_path.iterdir():
        if pt.name.isdigit():
            try:
                res = subprocess.run([\"ps\", \"-t\", pt.name, \"-o\", \"comm=\"], capture_output=True, text=True)
                processes = [p.strip() for p in res.stdout.splitlines() if p.strip()]
                if not any(re.match(r\"^(bash|zsh|fish|sh|dash|mksh|tcsh|csh|ksh)$\", p) for p in processes):
                    continue
            except Exception:
                pass
            try:
                # Use non-blocking write with timeout to prevent hangs"""
        try:
            text = path.read_text(encoding="utf-8", errors="ignore")
        except OSError as exc:
            UI.warn(f"Could not read {path}: {exc}")
            return False
        if old in text:
            return self._write_text_with_elevation(path, text.replace(old, new))
        return True

    def _write_text_with_elevation(self, path: Path, text: str) -> bool:
        try:
            path.write_text(text, encoding="utf-8")
            return True
        except PermissionError:
            UI.warn(f"Permission denied writing {path}; attempting elevated write...")
        except OSError as exc:
            UI.warn(f"Write failed for {path}: {exc}")

        fd, tmp_name = tempfile.mkstemp(prefix="caelestia_patch_", suffix=".tmp")
        os.close(fd)
        tmp = Path(tmp_name)
        try:
            tmp.write_text(text, encoding="utf-8")
            if self._run(["sudo", "install", "-m", "0644", str(tmp), str(path)], check=False) == 0:
                return True
            UI.warn(f"Elevated write failed for {path}.")
            return False
        finally:
            tmp.unlink(missing_ok=True)

    def _find_site_file(self, relative_parts: Iterable[str]) -> Path | None:
        parts = list(relative_parts)
        local_paths = [Path(p) for p in glob.glob(str(Path.home() / ".local" / "lib" / "python*" / "site-packages"))]
        search_paths = local_paths + [Path(p) for p in sys.path if p]
        seen: set[str] = set()
        for base in search_paths:
            key = str(base)
            if key in seen:
                continue
            seen.add(key)
            candidate = base.joinpath(*parts)
            if candidate.exists():
                return candidate
        return None

    def _resolve_shortcut_collisions(self, swhkdrc_file: Path, kglobal_file: Path) -> None:
        text = swhkdrc_file.read_text(encoding="utf-8", errors="ignore").splitlines()
        in_block = False
        swhkd_keys: list[str] = []
        for line in text:
            s = line.strip()
            if s.startswith("```"):
                in_block = not in_block
                continue
            if in_block and s and not s.startswith("#") and not s.startswith(" ") and not s.startswith("\t"):
                swhkd_keys.append(s)

        kde_keys: set[str] = set()
        mapping = {
            "super": "Meta",
            "ctrl": "Ctrl",
            "alt": "Alt",
            "shift": "Shift",
            "enter": "Return",
            "esc": "Escape",
            "sysrq": "Print",
            "period": "Period",
            "space": "Space",
            "tab": "Tab",
            "delete": "Delete",
            "slash": "Slash",
        }
        for key in swhkd_keys:
            parts = key.replace(" ", "").split("+")
            translated: list[str] = []
            for p in parts:
                translated.append(mapping.get(p, p if p.startswith("XF86") else p.upper()))
            kde_keys.add("+".join(translated))

        lines = kglobal_file.read_text(encoding="utf-8", errors="ignore").splitlines(keepends=True)
        out: list[str] = []
        changed = False
        for line in lines:
            if "=" in line and not line.strip().startswith("["):
                k, v = line.split("=", 1)
                parts = v.split(",")
                bindings = parts[0].split("\t")
                new_bindings: list[str] = []
                for bind in bindings:
                    bind_clean = bind.strip()
                    if bind_clean in kde_keys:
                        changed = True
                    else:
                        new_bindings.append(bind)
                parts[0] = "none" if not new_bindings else "\t".join(new_bindings)
                line = f"{k}={','.join(parts)}"
            out.append(line)

        if changed:
            kglobal_file.write_text("".join(out), encoding="utf-8")

    def _build_keyd_config(self, shortcuts_md: Path) -> str:
        mapping = {
            "super": "meta",
            "ctrl": "control",
            "alt": "alt",
            "shift": "shift",
            "return": "enter",
            "print": "sysrq",
            "xf86audioplay": "playpause",
            "xf86audionext": "nextsong",
            "xf86audioprev": "previoussong",
            "xf86audiomute": "mute",
            "xf86audiomicmute": "micmute",
            "xf86audiolowervolume": "volumedown",
            "xf86audioraisevolume": "volumeup",
            "xf86monbrightnessdown": "brightnessdown",
            "xf86monbrightnessup": "brightnessup",
            "delete": "delete",
            "escape": "esc",
            "space": "space",
            "tab": "tab",
            "period": "dot",
            "slash": "slash",
        }

        uid = os.environ.get("UID", str(os.getuid()))
        user = os.environ.get("USER", getpass.getuser())
        wayland = os.environ.get("WAYLAND_DISPLAY", "wayland-0")
        display = os.environ.get("DISPLAY", ":0")

        lines = shortcuts_md.read_text(encoding="utf-8", errors="ignore").splitlines()
        in_block = False
        parsed: list[str] = []
        for line in lines:
            s = line.strip()
            if s.startswith("```"):
                in_block = not in_block
                continue
            if in_block and s and not s.startswith("#"):
                parsed.append(s)

        sections: dict[str, list[str]] = {"main": []}
        idx = 0
        while idx < len(parsed):
            key = parsed[idx]
            idx += 1
            if idx >= len(parsed):
                break
            cmd = parsed[idx]
            idx += 1

            parts = [mapping.get(p.strip().lower(), p.strip().lower()) for p in key.split("+")]
            mods = [p for p in parts if p in {"meta", "control", "alt", "shift"}]
            keys = [p for p in parts if p not in {"meta", "control", "alt", "shift"}]
            if not keys:
                continue
            section = "+".join(mods) if mods else "main"
            sections.setdefault(section, [])

            cmd = cmd.replace("~", f"/home/{user}")
            wrapped = (
                f"sudo -iu {user} WAYLAND_DISPLAY={wayland} DISPLAY={display} "
                f"XDG_RUNTIME_DIR=/run/user/{uid} DBUS_SESSION_BUS_ADDRESS=unix:path=/run/user/{uid}/bus {cmd}"
            )
            sections[section].append(f"{keys[0]} = command({wrapped})")

        out = ["[ids]", "*", ""]
        for sec, items in sections.items():
            out.append(f"[{sec}]")
            out.extend(items)
            out.append("")
        return "\n".join(out)

    def _append_line(self, path: Path, line: str) -> None:
        path.parent.mkdir(parents=True, exist_ok=True)
        with path.open("a", encoding="utf-8") as fh:
            fh.write(line + "\n")

    def _q(self, path: Path) -> str:
        return "'" + str(path).replace("'", "'\\''") + "'"

    def _run_with_retries(
        self,
        command: list[str],
        *,
        attempts: int = 3,
        delay_seconds: int = 5,
    ) -> bool:
        for attempt in range(1, attempts + 1):
            if self._run(command, check=False) == 0:
                return True
            if attempt < attempts:
                UI.warn(f"Command failed (attempt {attempt}/{attempts}): {' '.join(command)}")
                UI.info(f"Retrying in {delay_seconds}s...")
                time.sleep(delay_seconds)
        return False

    def _run(
        self,
        command: list[str],
        *,
        check: bool = True,
        cwd: Path | None = None,
        shell: bool = False,
        input_text: str | None = None,
    ) -> int:
        if shell:
            cmd = " ".join(command)
            proc = subprocess.run(cmd, shell=True, cwd=cwd, env=self.env)
        else:
            proc = subprocess.run(
                command,
                cwd=cwd,
                env=self.env,
                input=(input_text.encode() if input_text is not None else None),
            )
        if check and proc.returncode != 0:
            raise RuntimeError(f"Command failed ({proc.returncode}): {' '.join(command)}")
        return proc.returncode
