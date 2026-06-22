<div align="center">

# ✧ C A E L E S T I A <img src="assets/caelestia.svg" width="35" align="top"> ✧
### A KDE adaptation of the celestial aesthetic

![Arch Linux](https://img.shields.io/badge/Arch_Linux-1793d1?logo=arch-linux&logoColor=white&style=for-the-badge)
![Fedora](https://img.shields.io/badge/Fedora-51A2DA?logo=fedora&logoColor=white&style=for-the-badge)
![KDE Plasma](https://img.shields.io/badge/KDE_Plasma-1D99F3?logo=kde&logoColor=white&style=for-the-badge)
![Quickshell](https://img.shields.io/badge/Quickshell-FF6B6B?style=for-the-badge)
![License: GPLv3](https://img.shields.io/badge/License-GPLv3-blue?style=for-the-badge&color=86dbce)

<br/>
<img width="400" height="230" alt="logo" src="https://github.com/user-attachments/assets/5662c83d-7181-4846-9fb8-79d0363c8c4f" />

<br/>
<br/>

> *“Ad astra per aspera.”*

</div>

---

<div align="center">
    <h2>✦ What is this? ✦</h2>
</div>

> [!NOTE]  
> This is a **community KDE port** of the beautiful [Caelestia Hyprland dotfiles](https://github.com/caelestia-dots/caelestia), meticulously adapted by **[ladybug-me](https://github.com/ladybug-me)** to bring the heavens to **KDE Plasma**.

<details> 
  <summary><b>✨ What this is / isn't</b></summary>
  <br/>

  - **Technically:** A curated collection of KDE Plasma configuration files, custom widgets, and idempotent installation scripts.
  - **Visually:** The ethereal caelestia aesthetic seamlessly ported to KDE Plasma utilizing cutting-edge Quickshell widgets.
  - **NOT:** A direct replacement for the original Hyprland dotfiles (which remain superior for dedicated minimal window managers).
  - **NOT:** A fully unattended system setup script (installs packages and configs, but no low-level system drivers or core tuning).
  
</details>

<details> 
  <summary><b>🌌 Why KDE instead of Hyprland?</b></summary>
  <br/>

  - KDE Plasma offers broader compatibility with existing tools, hardware, and ecosystems.
  - Provides a familiar, highly robust desktop environment.
  - Integrates strongly with the Arch Linux community and the AUR.
  - Proves that heavy DEs can still achieve an ultra-customized, highly aesthetic ricing spirit.
  
</details>

<details> 
  <summary><b>🚀 Key Features</b></summary>
  <br/>

  - **Material Design 3 Theming:** Cohesive dark theme driven by Darkly + Kvantum + dynamic color extraction.
  - **Quickshell Widgets:** Native, robust KDE integration with a modern Qt-based widget system.
    
  - **Kde Plasma 6.7:** Built to work with the latest release.
  - **Custom KDE Bridge:** Quickshell-KDE integration via a custom KWin script for fluid widget interaction.
  - **Custom Hyprctl:** Rewritten to integrate Hyprland-like calls seamlessly via Quickshell.
  - **Transparent Installation:** Every command is printed before execution. Safe and idempotent.
  - **QoL Features:** Dino Game with Kuru Kuru Runner 🦖 , Google lens 📸 , Screenshot tool 📷 , Screen recording with sound 📹 , Color picker 🎨 , Emoji picker 😂 , Clipboard history , Shortcuts Cheatsheet 📝.
  - **Window Tiling:** Optional *Polonium* support for dynamic tiling window management on Plasma.
  
</details>

<details> 
  <summary><b>📥 Installation</b></summary>
  <br/>

  1. **Clone this repository:**
     ```bash
     git clone https://github.com/ladybug-me/caelestia-dots-kde ~/caelestia-dots-kde
     cd ~/caelestia-dots-kde
     ```
  2. **Run the installer:**
     ```bash
     bash ./setup.sh
     ```
  3. **Follow the interactive prompts:** You can safely retry or ignore errors as needed.
     
  > **Note:** The installer might occasionally prompt for your password multiple times due to sudo timeouts. This is a known quirk and will be optimized in future releases.
  
  **Requirements:**
  - Arch Linux or an Arch-based distro (EndeavourOS, CachyOS, Manjaro, etc.), or Fedora Linux.
  - KDE Plasma 6.0+

  **Tested on:**
  - CachyOS
  - Manjaro KDE
  - Fedora 44 KDE Edition
  
</details>

<details> 
  <summary><b>💫 Updates</b></summary>
  <br/>

  - Updating is simple, just clone the latest version and run the installer.
  - Shell settings are **not** changed during updates. 


</details>


<div align="center">
    <h2>✦ Visuals ✦</h2>
</div>

| Caelestia on KDE Plasma Shell | Theming in Action |
|:---:|:---:|
| <img width="460" height="259" alt="shell" src="https://github.com/user-attachments/assets/14681aaf-77d9-4a65-af7d-8a4fc0b795cc" /> | <img width="460" height="259" alt="Rengoku" src="https://github.com/user-attachments/assets/d1b73dcb-82c9-465d-ba7e-da79ce263917" /> |

---

<div align="center">
    <h2>✦ Software Stack ✦</h2>
</div>


| Component | Purpose | Notes |
| --- | --- | --- |
| **[KDE Plasma](https://kde.org/plasma/)** | Desktop Environment | Full-featured modern DE |
| **[Quickshell](https://quickshell.outfoxxed.me/)** | Widget System | Qt-based, replaces AGS for this port |
| **[Darkly](https://github.com/vinceliuice/Darkly)** | Theme Framework | Used for Plasma style + window decoration |
| **[Kvantum](https://github.com/tsujan/Kvantum)** | Qt Theme Engine | For consistent, deep application styling |
| **[KWin](https://invent.kde.org/plasma/kwin)** | Window Manager | KDE's robust compositing window manager |
| **[Polonium](https://github.com/zeroxoneafour/polonium)** | Window Tiling | Optional KDE tiling plugin |


<details> 
  <summary><b>📦 Expand to view the comprehensive package lists</b></summary>
  <br/>

  The setup scripts install a curated suite of packages organized by category.

  - **Audio:** `cava`, `pavucontrol-qt`, `wireplumber`, `pipewire-pulse`, `playerctl`
  - **Backlight & Power:** `geoclue`, `brightnessctl`, `ddcutil`, `upower`
  - **Core Utilities:** `bc`, `coreutils`, `cliphist`, `ripgrep`, `jq`, `rsync`, `go-yq`
  - **Fonts & Themes:** `breeze-plus`, `darkly-bin`, `eza`, `starship`, `matugen-bin`, `ttf-jetbrains-mono-nerd`, `ttf-material-symbols-variable-git`, `otf-space-grotesk`
  - **KDE & Desktop:** `kvantum`, `systemsettings`, `kde-material-you-colors`, `xdg-desktop-portal-kde`
  - **Screen Capture & OCR:** `hyprshot`, `slurp`, `swappy`, `tesseract`, `wf-recorder`
  - **Optional Features:** `polonium`
  - **Custom Build:** `caelestia-quickshell-git`

  See [`sdata/`](https://github.com/ladybug-me/caelestia-dots-kde/tree/main/sdata/) for the complete custom PKGBUILDs structure.
</details>

---

<div align="center">
    <h2>✦ Keybinds ✦</h2>
</div>

| Shortcut | Action |
| --- | --- |
| `Super + /` | Show keybind list (cheatsheet) |
| `Super + Enter` | Open terminal (Foot) |
| `Super + 1–5` | Switch to workspace 1–5 |
| `Super + Space` | Application launcher (Fuzzel) |
| `Super + B` | Toggle notification panel (Sidebar) |
| `Super + V` | Open Clipboard History |
| `Super + Shift + A` | Open Google lens |
| `Super + Shift + S` | Open Screenshot tool |
| `Super + Ctrl + S` | Open Screen Recorder |
| `Super + Shift + C` | Open Color Picker |
| `Super + Shift + V` | Open Emoji Selector |

---

<div align="center">
    <h2>✦ Customization ✦</h2>
</div>

- **Wallpaper:** Press `Super + Space` to open the App launcher. Then type `>` to open Caelestia Tweaks and select Wallpaper.
- **Theme Colors:** Type `>` in app launcher and select `Scheme`. **NOTE:** When switching between dark and light theme, you need to go to `Kde Settings -> Colors & Themes -> Colors` and select Material You Dark or Light based on your preference.
- **Keyboard Shortcuts:** Modify [`src/keyboardshortcuts/shortcuts.md`](https://github.com/ladybug-me/caelestia-dots-kde/blob/main/src/keyboardshortcuts/shortcuts.md) and execute [`src/keyboardshortcuts/register.sh`](https://github.com/ladybug-me/caelestia-dots-kde/blob/main/src/keyboardshortcuts/register.sh) to apply them.
  - *Note:* You may need to update `~/.local/bin/hyprctl` for `Super + /` keybindings display.
- **The Greeter:** The gifs that play on popout of `Good Morning, User` can be customized by going to [`shell/assets/`](https://github.com/ladybug-me/caelestia-dots-kde/tree/main/shell/assets/) and replacing the [morning.gif](https://github.com/ladybug-me/caelestia-dots-kde/blob/main/shell/assets/morning.gif), [evening.gif](https://github.com/ladybug-me/caelestia-dots-kde/blob/main/shell/assets/evening.gif), [afternoon.gif](https://github.com/ladybug-me/caelestia-dots-kde/blob/main/shell/assets/afternoon.gif) and [night.gif](https://github.com/ladybug-me/caelestia-dots-kde/blob/main/shell/assets/night.gif) files.
---

<div align="center">
    <h2>✦ Troubleshooting ✦</h2>
</div>

<details>
  <summary><b>🛠️ Caelestia widgets not appearing</b></summary>
  <br/>
  
  - Log out and log back in.
  - Run: `caelestia shell -d` in the terminal and check for any diagnostic errors.
  
</details>

<details>
  <summary><b>🎨 Colors not applying correctly</b></summary>
  <br/>
    
  - Run `systemctl status --user kde-material-you-colors.service` to check for errors.
  - Rerunning the installer is often the easiest fix if a dependency was missed.
  - Only the Color Schemes labeled with dynamic support color change with wallpaper. (In app launcher, type `>` to open Caelestia Tweaks > Scheme)
  - **IMPORTANT:** Do not use the default KDE wallpaper manager. Use the Caelestia built-in wallpaper manager to ensure colors are extracted and applied.
  
</details>

<details>
  <summary><b>⚠️ Installation failed at step X</b></summary>
  <br/>

  - Sudo timeout: If a system update takes a long time, sudo might time out. 
  - Rerun the installer: `bash ./setup.sh` and look for **red errors**. The installer is idempotent and safe to run multiple times.
  - It will prompt you to retry, ignore, or exit on errors.

</details>

<details>
  <summary><b>⏪ Reverting changes & backup restoration</b></summary>
  <br/>

  The installer creates automatic backups before modifying critical KDE configuration files. These are stored in `caelestia-dots-kde/backups/`.

  **To safely restore your previous configuration:**

  1. **Rename current configs:**
     ```bash
     mv ~/.config ~/.configBACKUP
     mv ~/.local ~/.localBACKUP
     ```
  2. **Restore backed-up folders:**
     ```bash
     cp -r caelestia-dots-kde/backups/config ~/.config
     cp -r caelestia-dots-kde/backups/local ~/.local
     ```
  3. **Restore specific settings:**
     ```bash
     cp caelestia-dots-kde/backups/kglobalshortcutsrc ~/.config/
     cp caelestia-dots-kde/backups/kwinrc ~/.config/
     ```

</details>

<details>
  <summary><b>⌨️ Shell shortcuts not working</b></summary>
  <br/>
  
  The most probable cause is a `keyd` service failure.
  Run: `systemctl restart keyd`.
  
  *Special case:* If a kernel update happened, you might see "no uinput device" when running `sudo keyd`. Rebooting will fix this.

</details>

<details>
  <summary><b>😟 Note for Fedora users: </b></summary>
  <br/>
  
  - I have done everything, everypatch, every script possible to make it work on fedora but maybe for someone it might require manual intervention. Follow the installer's carefully placed logs to find any issue and fix it manually.

  - Know that it **works on Fedora** 😄.

</details>

---

<div align="center">
    <h2>✦ Credits ✦</h2>
</div>

- **[Caelestia](https://github.com/caelestia)** for the incredible, otherworldly design language and the original dotfiles.
- **[ladybug-me](https://github.com/ladybug-me)** for meticulously adapting the dotfiles to KDE Plasma.
- **[Quickshell](https://quickshell.outfoxxed.me/)** — The robust Qt widget framework.
- **[Darkly](https://github.com/vinceliuice/Darkly)** — For the gorgeous KDE theme base.
- **[KDE Plasma](https://kde.org/plasma/)** — The powerhouse desktop environment.

---

<div align="center">
    <h2>✦ Support & License ✦</h2>
</div>

- **Issues & Bugs:** [GitHub Issues](https://github.com/ladybug-me/caelestia-dots-kde/issues)
- **Original Project:** [caelestia-dots/caelestia](https://github.com/caelestia-dots/caelestia)
- **KDE Community:** [r/kde](https://www.reddit.com/r/kde/)

This project is licensed under the **GNU General Public License v3.0** — the same license as the original Caelestia project. 
Feel free to use, modify, and distribute this work, provided any derivative work is also licensed under GPLv3. See the [LICENSE](https://github.com/ladybug-me/caelestia-dots-kde/blob/main/LICENSE) for full details.

<div align="center">
    <br/>
    <p><i>May your desktop always reflect the stars.</i></p>
</div>
