<div align="center">

# C A E L E S T I A <img src="assets/caelestia.svg" width="35" align="top">

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
  <summary><b>What this is / isn't</b></summary>
  <br/>

  - **Technically:** A curated collection of KDE Plasma configuration files, custom widgets, and idempotent installation scripts.
  - **Visually:** The ethereal caelestia aesthetic seamlessly ported to KDE Plasma utilizing cutting-edge Quickshell widgets.
  - **NOT:** A direct replacement for the original Hyprland dotfiles (which remain superior for dedicated minimal window managers).
  - **NOT:** A fully unattended system setup script (installs packages and configs, but no low-level system drivers or core tuning).
  
</details>

<details> 
  <summary><b>Why KDE instead of Hyprland?</b></summary>
  <br/>

  - KDE Plasma offers broader compatibility with existing tools, hardware, and ecosystems.
  - Provides a familiar, highly robust desktop environment.
  - Integrates strongly with the Arch Linux community and the AUR.
  - Proves that heavy DEs can still achieve an ultra-customized, highly aesthetic ricing spirit.
  
</details>

<details> 
  <summary><b>Key Features</b></summary>
  <br/>

  - **Works on Real KDE Setups:** Built and tested on current Plasma versions across Arch-based distros and Fedora.
  - **Fast to Install, Safe to Re-run:** Idempotent scripts let you retry installation without wrecking your existing setup.
  - **Clean Rollback:** Dedicated uninstaller makes it easy to revert if you do not like the result.
  - **Consistent Theming:** Darkly + Kvantum + dynamic color extraction keep apps and shell visuals in sync.
  - **Deep KDE Integration:** Custom KWin bridge and Quickshell modules provide tight desktop-level behavior.
  - **Daily-Use Tools Included:** Screenshot, screen recording with audio, color picker, clipboard history, and emoji picker are ready out of the box.
  - **Simple Update Path:** Update from UI or command line without overwriting your shell settings.
  - **Optional Tiling Workflow:** Polonium support is available if you want dynamic tiling on Plasma.
  
</details>

<details> 
  <summary><b>Installation</b></summary>
  <br/>

  1. **Clone this repository:**
     ```bash
     git clone -b main --single-branch --depth 1 https://github.com/ladybug-me/caelestia-dots-kde ~/caelestia-dots-kde
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
  <summary><b>Updates</b></summary>
  <br/>
    
    NOTE: You must backup your ~/.config if you have made changes to the dot or shell files
  - Updating is simple now with integrated experience.
  - **Gui**: Open Shell settings -> Updates -> Select the update type (stable or bleeding edge) -> Install Updates
  - **Manual**: just run `bash update.sh` and select the branch from which you want to update. 
  - branches: main (stable) and dev (bleeding edge)
  - Shell settings are **not** changed during updates. 


</details>

<div align="center">
    <h2>✦ Visuals ✦</h2>
</div>



https://github.com/user-attachments/assets/9ad2e5f5-f80e-48c0-b65b-a4084bb363c6


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
  <summary><b>Expand to view the comprehensive package lists</b></summary>
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

<details>
  <summary><b>Wallpaper & Slideshow</b></summary></br>

  - Press `Super + Space` to open the App launcher. Then type `>` to open Caelestia Tweaks and select Wallpaper.
  - For Slideshow, Open `Caelestia Settings -> Wallpaper & style -> Wallpaper slideshow`.
</details>
<details>
  <summary><b>Theme Colors</b></summary></br>
 
  - Type `>` in app launcher and select `Scheme`.
  - *Note: When switching between dark and light theme, you need to go to `Kde Settings -> Colors & Themes -> Colors` and select Material You Dark or Light based on your preference.*
</details>
<details>
  <summary><b>Keyboard Shortcuts</b></summary></br>

  - Modify [`src/keyboardshortcuts/shortcuts.md`](https://github.com/ladybug-me/caelestia-dots-kde/blob/main/src/keyboardshortcuts/shortcuts.md) and execute [`src/keyboardshortcuts/register.sh`](https://github.com/ladybug-me/caelestia-dots-kde/blob/main/src/keyboardshortcuts/register.sh) to apply them.
  
  - *Note: You may need to update `~/.local/bin/hyprctl` for `Super + /` keybindings display.*
</details>
<details>
  <summary><b>The Greeter</b></summary></br>

   - The gifs that play on popout of `Good Morning, User` can be customized by going to [`shell/assets/`](https://github.com/ladybug-me/caelestia-dots-kde/tree/main/shell/assets/) and replacing the [morning.gif](https://github.com/ladybug-me/caelestia-dots-kde/blob/main/shell/assets/morning.gif), [evening.gif](https://github.com/ladybug-me/caelestia-dots-kde/blob/main/shell/assets/evening.gif), [afternoon.gif](https://github.com/ladybug-me/caelestia-dots-kde/blob/main/shell/assets/afternoon.gif) and [night.gif](https://github.com/ladybug-me/caelestia-dots-kde/blob/main/shell/assets/night.gif) files.
Then rebuild the shell by running setup.sh again.
</details>

---
<div align="center">
    <h2>✦ Instructions ✦</h2>
</div>
<details>
  <summary><b>Removing the bottom panel </b></summary>
  <br/>
  
  - The bottom panel might hide behind the quickshell bar. 
  - In that case, Press Super+D → Right-click the panel → "Panel configuration" → remove every existing KDE panel for optimal behaviour with the Quickshell bar.
  
</details>

<details>
  <summary><b>Using the AI Assistant </b></summary>
  </br>

  - The AI assistant is powered by Ollama.
  - Run `bash ollama_setup.sh` for automatic installation.
  - Manual:
      - Check instructions for ollama installation at [Ollama](https://ollama.com/)
      - Download any model you want by using the command `ollama pull <model name>` 
      - e.g. `ollama pull gemma4` 
  - **If you want to use cloud models**
     - Open terminal and run `ollama run gemma4:cloud` or anyother model (see [cloud models](https://ollama.com/search?c=cloud) for available models).
     - Sign in to ollama using the link provided in the terminal.
     - Close the terminal and open AI assistant from the sidebar and select the cloud model and start chatting!
  
</details>  

---

<div align="center">
    <h2>✦ Troubleshooting ✦</h2>
</div>

<details>
  <summary><b>Critical Error Handling</b></summary>
  <br/>

  If something got **really messed up** (setup broken, build error, great panic..)

  **Complete Shell Reset**
  1. **Get Access to a terminal**: Win+Enter or Alt+Ctl+T or The last hope tty: Ctl + Alt + F3 or any other Fn key that works.
  2. **Uninstall.sh**: Open terminal where setup.sh is, run `bash uninstall.sh`. **NOTE**: Enter `0` when it asks for which backup to restore.
  3. **Delete all shell files**: Run `rm -rf ~/.config/caelestia ~/.config/quickshell`. Also delete the cloned repo folder.
  4. **Reboot**: Run `reboot` (May be a laggy one, if stuck, do a power on off). You will be seeing a wallpaper only after restarting with light theme. Its the normal KDE shell without any panels. You can add any panels if you want by `Right Click -> Edit Mode`.
  5. **Clone the latest main repo**: Run
     ```bash
     git clone -b main --single-branch --depth 1 https://github.com/ladybug-me/caelestia-dots-kde ~/caelestia
     cd ~/caelestia
     bash setup.sh
     ```
  7. **Reboot**: Run `reboot` and you are back with a stable environment once again.
    
</details>
<details>
  <summary><b>Viewing Debug Logs & Supported Components</b></summary>
  <br/>

  Caelestia includes a built-in Debug Mode that enables verbose console logging for various internal components.

  **Enabling Debug Mode:**
  1. **Via UI**: Open the Nexus settings panel, navigate to the **About** page, and toggle **Debug Mode** under the **Advanced** section.
  2. **Via Config**: Add `"debugLogs": true` under the `"general"` block in your `~/.config/caelestia/shell.json`.

  After enabling it, reload the shell (`caelestia shell -k` followed by `caelestia shell -d`).

  **Viewing the Logs:**
  To view the live debug stream in your terminal, run the following command:
  ```bash
  caelestia shell -l
  ```

  **Supported Components:**
  Currently, the following components log verbose output when Debug Mode is enabled:
  - **AiAssistant**: Logs tool executions, JSON parsing errors, and Ollama connection statuses.
  - **WallhavenSearcher**: Logs API requests, search queries, and wallpaper download/move operations.
  - **DiscordRPC**: Logs connection states and errors for the Discord Rich Presence service.
  - **BluetoothReconnect**: Logs background device reconnection attempts on startup.
  - **Nexus StackPage**: Logs internal UI navigation states and errors.

</details>

<details>
  <summary><b>Caelestia widgets not appearing</b></summary>
  <br/>
  
  - Log out and log back in.
  - Run: `caelestia shell -d` in the terminal and check for any diagnostic errors.
  
</details>

<details>
  <summary><b>Colors not applying correctly</b></summary>
  <br/>
    
  - Run `systemctl status --user kde-material-you-colors.service` to check for errors.
  - Rerunning the installer is often the easiest fix if a dependency was missed.
  - Only the Color Schemes labeled with dynamic support color change with wallpaper. (In app launcher, type `>` to open Caelestia Tweaks > Scheme)
  - **IMPORTANT:** Do not use the default KDE wallpaper manager. Use the Caelestia built-in wallpaper manager to ensure colors are extracted and applied.
  
</details>

<details>
  <summary><b>Installation failed at step X</b></summary>
  <br/>

  - Sudo timeout: If a system update takes a long time, sudo might time out. 
  - Rerun the installer: `bash ./setup.sh` and look for **red errors**. The installer is idempotent and safe to run multiple times.
  - It will prompt you to retry, ignore, or exit on errors.

</details>

<details>
  <summary><b>Uninstallation & Reverting Changes</b></summary>
  <br/>

  The easiest way to revert changes and uninstall the Caelestia KDE theme is to use the dedicated uninstallation script:
  ```bash
  bash ./uninstall.sh
  ```

  > [!WARNING]  
  > At Remove packages step (optional), the script will prompt for your confirmation before proceeding. Once confirmed, it will **remove all packages** associated with the Caelestia setup. This includes any packages that were already pre-installed on your system but happen to match the setup requirements. Please review the **Software Stack** section above for the comprehensive list of packages that will be uninstalled.

</details>

<details>
  <summary><b>Shell shortcuts not working</b></summary>
  <br/>
  
  The most probable cause is a `keyd` service failure.
  Run: `systemctl restart keyd`.
  
  Another cause is you ran setup.sh or register.sh with sudo.
  See [Issue#5](https://github.com/ladybug-me/caelestia-dots-kde/issues/5) for this.

  Another common cause is a conflict with other key remappers (for example: Kanata, KMonad, input-remapper, xremap).
  During keyboard shortcut setup, the installer now disables known conflicting remapper services before enabling keyd.
  If a conflicting remapper process is still running, keyd is disabled as a safety guard and the step exits with an actionable error.

  MangoHud hotkeys can also be affected by keyd keycode behavior on some systems.
  The generated keyd config includes the workaround below by default:
  ```ini
  [main]
  rightshift = rightshift
  ```
  
  *Special case:* If a kernel update happened, you might see "no uinput device" when running `sudo keyd`. Rebooting will fix this.

</details>

<details>
  <summary><b>Note for Asahi Linux (MacOS) users: </b></summary>
  <br/>
  
  - The quickshell version for [Asahi Linux](https://asahilinux.org/) is < 3.0.0 causing the following error:

  ```bash
$ caelestia shell -d
No running instances for "/home/v0iddd/.config/quickshell/caelestia/shell.qml"
  INFO: Launching config: "/home/v0iddd/.config/quickshell/caelestia/shell.qml"
ERROR: Unrecognized pragma "DefaultEnv QS_NO_RELOAD_POPUP=1"
```
  - Open `~/.config/quickshell/caelestia/shell.qml`
  - Change the following lines
  ```bash
  //@ pragma DefaultEnv QS_NO_RELOAD_POPUP=1
  //@ pragma DefaultEnv QS_DROP_EXPENSIVE_FONTS=1
  //@ pragma DefaultEnv QSG_RENDER_LOOP=threaded
  //@ pragma DefaultEnv QT_QUICK_FLICKABLE_WHEEL_DECELERATION=10000
  ```
  to
  ```bash
  //@ pragma Env QS_NO_RELOAD_POPUP=1
  //@ pragma Env QS_DROP_EXPENSIVE_FONTS=1
  //@ pragma Env QSG_RENDER_LOOP=threaded
  //@ pragma Env QT_QUICK_FLICKABLE_WHEEL_DECELERATION=10000
  ```

</details>

---

<div align="center">
    <h2>✦ Credits ✦</h2>
</div>

- **[Caelestia](https://github.com/caelestia)** for the incredible, otherworldly design language and the original dotfiles.
- **[ladybug-me](https://github.com/ladybug-me)** for meticulously adapting the dotfiles to KDE Plasma.
- **[0xSolanaceae](https://github.com/0xSolanaceae)** for showing direction the project needed.
- **[Content-Swordfish751](https://www.reddit.com/user/Content-Swordfish751/)** for many important contributions.
- **[Peace-W](https://github.com/Peace-W)** for Nobara fix.
- **[dim-ghub](https://github.com/dim-ghub/caelestia-shell)** for the added features in v2.0.0 from his fork.
- **[nlohmann](https://github.com/nlohmann/json)** for the JSON parser used in the project.
- **[Quickshell](https://quickshell.outfoxxed.me/)** — The robust Qt widget framework.
- **[Darkly](https://github.com/vinceliuice/Darkly)** — For the gorgeous KDE theme base.
- **[KDE Plasma](https://kde.org/plasma/)** — The powerhouse desktop environment.

---

<div align="center">
    <h2>✦ Maintainers ✦</h2>
</div>

- **[ladybug-me](https://github.com/ladybug-me)** — Project owner and KDE port lead; oversees the project while actively maintaining it, resolving issues, and developing new features.
- **[0xSolanaceae](https://github.com/0xSolanaceae)** — Co-maintainer; actively maintains the project, works on issues, improves tooling and QA, and develops new features.

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
