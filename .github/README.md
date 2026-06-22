<div align="center">
    <h1>【 end_4's dotfiles — KDE Plasma Port 】</h1>
    <h3>A KDE adaptation of the illogical-impulse aesthetic</h3>
</div>

<div align="center"> 

![Arch Linux](https://img.shields.io/badge/Arch_Linux-1793d1?logo=arch-linux&logoColor=white&style=for-the-badge)
![Fedora](https://img.shields.io/badge/Fedora-51A2DA?logo=fedora&logoColor=white&style=for-the-badge)
![KDE Plasma](https://img.shields.io/badge/KDE_Plasma-1D99F3?logo=kde&logoColor=white&style=for-the-badge)
![Quickshell](https://img.shields.io/badge/Quickshell-FF6B6B?style=for-the-badge)
![License: GPLv3](https://img.shields.io/badge/License-GPLv3-blue?style=for-the-badge&color=86dbce)

</div>

<div align="center">
    <h2>• what is this •</h2>
    <h3></h3>
</div>

> [!NOTE]  
> This is a **community KDE port** of [end-4's Hyprland dotfiles](https://github.com/end-4/dots-hyprland), adapted by **ladybug-me** to run on **KDE Plasma** instead of Hyprland.

<details> 
  <summary>What this is/isn't</summary>

  - Technically: A collection of KDE Plasma configuration files, custom widgets, and installation scripts
  - Visually: The illogical-impulse aesthetic ported to KDE Plasma with Quickshell widgets
  - NOT: A replacement for the original Hyprland dotfiles (which are superior for minimal window managers)
  - NOT: A system setup script (only packages and configs, no drivers, zram, etc.)
  
</details>

<details> 
  <summary>Why KDE instead of Hyprland?</summary>

  - KDE Plasma offers better compatibility with existing tools and ecosystems
  - Familiar desktop environment for users transitioning from Windows/GNOME
  - Strong integration with Arch Linux community and AUR
  - Still maintains the illogical-impulse aesthetic and customization spirit
  
</details>

<details> 
  <summary>Key features</summary>
     
  - **Material Design 3 theming**: Cohesive dark theme with Darkly + Kvantum + custom colors
  - **Quickshell widgets**: Native KDE integration with modern Qt-based widget system
  - **10 virtual desktops**: Pre-configured with Meta+0–9 shortcuts
  - **Custom KDE bridge**: Quickshell-KDE integration via KWin script for seamless widget interaction
  - **Custom hyprctl**: Rewritten to integrate with hyprland calls by quickshell
  - **Transparent installation**: Every command shown before execution; idempotent and safe to run multiple times
  - **AI integration**: Ready for Gemini, Ollama, and other AI backends
  - **QoL features**: Screen translation, anti-flashbang, color-picked themes
  - **Window tiling**: Optional Polonium support for tiling window management
  
</details>

<details> 
  <summary>Installation</summary>

  1. Clone this repo:
     ```bash
     git clone https://github.com/ladybug-me/end-4dots-KDE ~/end-4dots-KDE
     cd ~/end-4dots-KDE
     ```
  2. Run the installer:
     ```bash
     bash ./setup.sh
     ```
  3. Follow the interactive prompts (you can retry/ignore errors)
     
     **NOTE:** Due to some bugs, the installer might ask you multiple times for passwd or some other interaction.
     This will be fixed in future. **Please contribute to fixing this issue.**
  
  **Requirements:**
  - Arch Linux or Arch-based distro (Endeavour OS, Manjaro, etc.), or Fedora Linux
  - KDE Plasma 6.0+

  **Tested on:**
  - CachyOS
  - Manjaro KDE
  - Fedora 44 KDE Edition


  
</details>

<div align="center">
    <h2>• screenshots •</h2>
    <h3></h3>
</div>

<div align="center">
    <img src="assets/illogical-impulse.svg" alt="illogical-impulse logo" style="max-width: 400px;">
</div>

| KDE Plasma | MaterialYouColor with Icons |
|:---|:---|
| <img width="1920" height="1080" alt="screenshot1" src="https://github.com/user-attachments/assets/475bf418-c68f-4411-9c26-c6eaac2f2f49" /> | <img width="1920" height="1080" alt="screenshot2" src="https://github.com/user-attachments/assets/46958e34-c675-4daf-b53f-ec14b8d5ba65" /> |
| **Illogical Impulse Settings** | **KDE + Keyd Shortcuts** |
| <img width="1920" height="1080" alt="screenshot3" src="https://github.com/user-attachments/assets/3c6d4dfc-17a4-475c-aa78-753342d5f2f4" /> | <img width="1920" height="1080" alt="screenshot4" src="https://github.com/user-attachments/assets/cb205aa6-2ade-4d28-ba27-afe7f1f82e8f" /> |

<div align="center">
    <h2>• software stack •</h2>
    <h3></h3>
</div>

| Component | Purpose | Notes |
| --- | --- | --- |
| [KDE Plasma](https://kde.org/plasma/) | Desktop environment | Full-featured modern DE |
| [Quickshell](https://quickshell.outfoxxed.me/) | Widget system | Qt-based, replaces AGS for this port |
| [Darkly](https://github.com/vinceliuice/Darkly) | Theme framework | Used for Plasma style + window decoration |
| [Kvantum](https://github.com/tsujan/Kvantum) | Qt theme engine | For consistent application styling |
| [KWin](https://invent.kde.org/plasma/kwin) | Window manager | KDE's compositing window manager |
| [Polonium](https://github.com/zeroxoneafour/polonium) | Window tiling | Optional KDE tiling plugin (available during install) |
| [Hyprpicker](https://github.com/hyprwm/hyprpicker) | Color picker | For wallpaper color extraction |
| [Matugen](https://github.com/InioX/matugen) | Color generation | Generates Material Design 3 palettes |

<details> 
  <summary>Full dependencies</summary>

  See [sdata/arch-dist/](https://github.com/ladybug-me/end-4dotsKDE/tree/main/sdata/arch-dist/) for custom PKGBUILDs:
  
  - **illogical-impulse-audio**: PipeWire + Wireplumber audio setup
  - **illogical-impulse-basic**: Core utilities and system tools
  - **illogical-impulse-backlight**: Backlight control utilities
  - **illogical-impulse-fonts-themes**: Material Design 3 themes and fonts
  - **illogical-impulse-kde**: KDE Plasma specific packages
  - **illogical-impulse-python**: Python environment for scripts
  - **illogical-impulse-quickshell-git**: Quickshell from git (latest)
  - **illogical-impulse-toolkit**: Development tools and utilities

</details>

<details>
  <summary>Packages installed by the installer</summary>

  The setup scripts install a comprehensive suite of packages organized by category. This list is provided for reference and tracking purposes.

  #### Audio System
  - **cava** — Audio visualizer used in Quickshell widgets
  - **pavucontrol-qt** — Qt-based PulseAudio volume control
  - **wireplumber** — PipeWire session and policy manager
  - **pipewire-pulse** — PipeWire PulseAudio compatibility layer
  - **libdbusmenu-gtk3** — DBus menu support library
  - **playerctl** — Media player control utility

  #### Backlight & Power
  - **geoclue** — Geolocation service for automatic color temperature
  - **brightnessctl** — Backlight brightness control
  - **ddcutil** — Monitor brightness control via DDC

  #### Core Utilities
  - **bc** — Basic calculator for scripts
  - **coreutils** — GNU core utilities
  - **cliphist** — Clipboard history manager
  - **cmake** — Build system generator
  - **curl** — Data transfer tool
  - **wget** — HTTP/HTTPS file downloader
  - **ripgrep** — Fast text search utility
  - **jq** — JSON query processor (widely used)
  - **xdg-user-dirs** — XDG user directory manager
  - **rsync** — File synchronization tool
  - **go-yq** — YAML/JSON/XML processor

  #### Fonts & Themes
  - **adw-gtk-theme-git** — Adwaita GTK theme variant
  - **breeze** — KDE Breeze theme
  - **breeze-plus** — Enhanced Breeze theme
  - **darkly-bin** — Modern dark Qt theme
  - **eza** — Modern `ls` replacement with icons
  - **fish** — User-friendly shell (used throughout config)
  - **fontconfig** — Font configuration library
  - **kitty** — GPU-based terminal emulator (configs included)
  - **matugen-bin** — Material Design 3 color generator from wallpaper
  - **otf-space-grotesk** — Space Grotesk font
  - **starship** — Customizable shell prompt
  - **ttf-jetbrains-mono-nerd** — JetBrains Mono with Nerd Font glyphs
  - **ttf-material-symbols-variable-git** — Material Design symbols font
  - **ttf-readex-pro** — Readex Pro font family
  - **ttf-rubik-vf** — Rubik variable font
  - **ttf-gabarito** — Gabarito geometric font
  - **ttf-twemoji** — Twitter emoji font (emoji fallback support)

  #### KDE & Desktop
  - **bluedevil** — KDE Bluetooth manager
  - **gnome-keyring** — Credential storage and management
  - **networkmanager** — Network connection manager
  - **plasma-nm** — KDE NetworkManager integration
  - **polkit-kde-agent** — KDE PolicyKit authentication agent
  - **dolphin** — KDE file manager
  - **systemsettings** — KDE system configuration tool
  - **kvantum** — Qt style engine for consistent app theming
  - **kvantum-qt5** — Kvantum Qt5 support
  - **kde-material-you-colors** — Dynamic Material You color theming

  #### Desktop Portal
  - **xdg-desktop-portal** — Desktop integration standardization
  - **xdg-desktop-portal-kde** — KDE portal backend
  - **xdg-desktop-portal-gtk** — GTK portal backend
  - **xdg-desktop-portal-hyprland** — Hyprland portal backend

  #### Python Environment
  - **clang** — C/C++ compiler (for building Python packages)
  - **uv** — Fast Python package manager and venv tool
  - **gtk4** — GTK4 library
  - **libadwaita** — Adwaita widgets library
  - **libsoup3** — HTTP library
  - **libportal-gtk4** — XDG portal GTK4 support
  - **gobject-introspection** — GObject introspection framework

  #### Screen Capture & OCR
  - **hyprshot** — Hyprland screenshot tool
  - **slurp** — Screen area selection tool
  - **swappy** — Screenshot annotation tool
  - **tesseract** — Optical character recognition engine
  - **tesseract-data-eng** — English language data for Tesseract
  - **wf-recorder** — Wayland screen recorder

  #### Utilities & Tools
  - **upower** — Power management interface
  - **wtype** — Type text on Wayland
  - **ydotool** — Keyboard/mouse automation tool
  - **fuzzel** — Application launcher (used in Quickshell)
  - **glib2** — GLib utilities (provides `gsettings`)
  - **imagemagick** — Image manipulation suite
  - **hypridle** — Idle timeout manager
  - **hyprlock** — Screen locker (fallback)
  - **hyprpicker** — Color picker for wallpaper extraction
  - **songrec** — Music recognition tool
  - **translate-shell** — Command-line translation utility
  - **wlogout** — Wayland logout interface
  - **libqalculate** — Advanced calculator library (for searchbar math)

  #### Optional Features
  - **polonium** — KDE tiling window manager plugin (optional, enabled during install)
  - **bibata-cursor-theme** — Modern cursor theme

  #### Custom KDE Packages
  - **illogical-impulse-quickshell-git** — Quickshell widget system from latest git (includes Qt6 deps)

</details>

<div align="center">
    <h2>• keybinds •</h2>
    <h3></h3>
</div>

| Key | Action |
| --- | --- |
| `Super` + `/` | Show keybind list |
| `Super` + `Enter` | Open terminal (Kitty) |
| `Super` + `Ctrl` + `T` | Open Wallpaper picker |
| `Super` + `1`–`0` | Switch to workspace 1–10 |
| `Super` + `Space` | Application launcher (Fuzzel) |
| `Super` + `V` | Clipboard History |
| Color picker | Available via the widgets|

<div align="center">
    <h2>• customization •</h2>
    <h3></h3>
</div>

- **Wallpaper**: Press `Super + Ctrl + T` to change the wallpaper and update the theme colors. (Press `Super + Ctrl + Alt + T` for random wallpapers in `~/Pictures/Wallpapers/`)
- **Theme colors**: Edit [src/config/matugen/templates/](https://github.com/ladybug-me/end-4dotsKDE/tree/main/src/config/matugen/templates/) to customize color generation
- **Keyboard shortcuts**: Modify [src/keyboardshortcuts/shortcuts.md](https://github.com/ladybug-me/end-4dotsKDE/blob/main/src/keyboardshortcuts/shortcuts.md) and then run [src/keyboardshortcuts/register.sh](https://github.com/ladybug-me/end-4dotsKDE/blob/main/src/keyboardshortcuts/register.sh)
  - **Note**: You may need to update ~/.local/bin/hyprctl for `Super + /` keybindings display
- **Widgets**: Edit Quickshell configs in [src/quickshell/](https://github.com/ladybug-me/end-4dotsKDE/tree/main/src/quickshell/) or in `~/.config/quickshell/`

<div align="center">
    <h2>• troubleshooting •</h2>
    <h3></h3>
</div>

<details>
  <summary>Quickshell widgets not appearing</summary>
  
  - Log out and log back in.
  - Run: `qs -c ii` and check for any errors.
  
</details>

<details>
  <summary>Colors not applying</summary>
    
  - Run `kde-material-you-colors` in terminal and check for errors.
    If its installation failed, check instructions at [Kde-material-you-colors](https://github.com/luisbocanegra/kde-material-you-colors)
  - Reruning the installer is the best choice, see `Installation failed at step X` instructions.
  - DO NOT USE KDE WALLPAPER MANAGER. Use quickshell built in wallpaper manager (Super + Ctrl + T).
  
</details>

<details>
  <summary>Installation failed at step X / something's not right</summary>

  - sudo timeout: If system update took a long time, sudo must have timedout incase no passwd was provided again, `causing many packages' installation to fail`
  - Rerun the installer: `bash ./setup.sh` and check for **RED colored errors**. Manual intervention might be required there. There is also a message that tells about installation of all packages
    
        ======================================================
          Installation summary
        ======================================================
          Installed : 60
          Skipped   : 38 (already present)
          Failed    : 0
        ======================================================
    
     **Number of packages vary in each distribution.**

  - It will prompt you to retry, ignore, or exit on errors
  - Report in Issues with logs.
  
</details>

<details>
  <summary>Reverting changes & backup restoration</summary>

  The installer creates automatic backups before modifying critical KDE configuration files. These backups are stored in:
  ```
  end-4dots-KDE/backups/
  ```

  **Backed up files include:**
  - `config/` — Your .config folder before the installer was run.
  - `kglobalshortcutsrc` — KDE global keyboard shortcuts configuration
  - `kwinrc` — KWin window manager configuration
  - `local/` — Local KDE configuration files
### Restoring Your Previous KDE Configuration

Follow these steps to safely backup your current setup and restore your previous configuration.

#### 1. Backup Existing Configurations
Rename your current configuration folders to prevent data loss:
```bash
mv ~/.config ~/.configBACKUP
mv ~/.local ~/.localBACKUP
```

#### 2. Restore Configuration Folders
Copy the backup directories from the installer's root directory to your home folder:
```bash
cp -r config ~/.config
cp -r local ~/.local
```

#### 3. Restore Specific Configuration Files
Copy the remaining shortcut and window manager settings into place:
```bash
cp kglobalshortcutsrc ~/.config/
cp kwinrc ~/.config/
```


</details>

<details>
  <summary>Shell shortcuts not working</summary>
  
  Most probable cause is `keyd` service failure.
  Run: `systemctl restart keyd`.
  
  **Special case**: If a kernel update happened, you will see `no uinput device` on running sudo keyd.
  Rebooting will fix this.

</details>
<div align="center">
    <h2>• credits •</h2>
    <h3></h3>
</div>

**Original project:**
- [end-4](https://github.com/end-4) for the incredible illogical-impulse design and original dotfiles

**This KDE port:**
- [ladybug-me](https://github.com/ladybug-me) for adapting the dotfiles to KDE Plasma

**Related projects & inspiration:**
- [Quickshell](https://quickshell.outfoxxed.me/) — Qt widget framework
- [Matugen](https://github.com/InioX/matugen) — Material Design 3 color generation
- [Darkly](https://github.com/vinceliuice/Darkly) — KDE theme
- [KDE Plasma](https://kde.org/plasma/) — Desktop environment
- Original acknowledgments in [dots-hyprland](https://github.com/end-4/dots-hyprland)

<div align="center">
    <h2>• support & community •</h2>
    <h3></h3>
</div>

- **Issues & bugs**: [GitHub Issues](https://github.com/ladybug-me/end-4dotsKDE/issues)
- **Original project**: [end-4/dots-hyprland](https://github.com/end-4/dots-hyprland)
- **Quickshell docs**: [outfoxxed.me](https://quickshell.outfoxxed.me/)
- **KDE community**: [KDE Forums](https://www.reddit.com/r/kde/)

<div align="center">
    <h2>• license •</h2>
    <h3></h3>
</div>

This project is licensed under the **GNU General Public License v3.0** — the same license as the original [end-4/dots-hyprland](https://github.com/end-4/dots-hyprland) project.

- You are free to use, modify, and distribute this project
- Any derivative work must also be licensed under GPLv3
- See [LICENSE](https://github.com/ladybug-me/end-4dotsKDE/blob/main/LICENSE) for the full text
