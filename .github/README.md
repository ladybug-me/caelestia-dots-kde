# Caelestia for KDE Plasma

Premium KDE Plasma desktop environment with celestial aesthetic, custom Quickshell widgets, Material Design 3 theming, and extensive system integration.

![Arch Linux](https://img.shields.io/badge/Arch_Linux-1793d1?logo=arch-linux&logoColor=white&style=for-the-badge)
![Fedora](https://img.shields.io/badge/Fedora-51A2DA?logo=fedora&logoColor=white&style=for-the-badge)
![KDE Plasma](https://img.shields.io/badge/KDE_Plasma-1D99F3?logo=kde&logoColor=white&style=for-the-badge)
![Quickshell](https://img.shields.io/badge/Quickshell-FF6B6B?style=for-the-badge)
![License: GPLv3](https://img.shields.io/badge/License-GPLv3-blue?style=for-the-badge&color=86dbce)

![logo](https://github.com/user-attachments/assets/5662c83d-7181-4846-9fb8-79d0363c8c4f)

## Quick Start

### Requirements

- Arch Linux / Fedora Linux / Arch-based derivative (EndeavourOS, CachyOS, Manjaro, etc.)
- KDE Plasma 6.0+

### Installation

```bash
git clone https://github.com/ladybug-me/caelestia-dots-kde ~/caelestia-dots-kde
cd ~/caelestia-dots-kde
bash ./setup.sh
```

The installer is idempotent and prints all commands before execution. Follow the interactive prompts—you can safely retry or skip errors as needed.

### Uninstallation

```bash
bash ./uninstall.sh
```

Restoration backups are stored in `caelestia-dots-kde/backups/`. For manual restoration:

```bash
mv ~/.configBACKUP ~/.config
mv ~/.localBACKUP ~/.local
```

### Updates

Clone the latest version and run `setup.sh` again. Shell settings are preserved during updates.

## Features

- **Material Design 3 Theming** — Dark theme with Darkly + Kvantum + dynamic color extraction
- **Quickshell Widgets** — Native Qt-based custom widget system for KDE
- **Custom KWin Bridge** — Seamless Quickshell-KDE integration
- **Quality-of-Life Tools** — Screenshot, screen recording, color picker, emoji selector, clipboard history, dino game, Google Lens
- **Optional Tiling** — Polonium support for dynamic window management
- **Transparent Installation** — Every command logged; safe and repeatable

## Gallery

| Desktop | Theming |
|:---:|:---:|
| <img width="460" height="259" alt="shell" src="https://github.com/user-attachments/assets/14681aaf-77d9-4a65-af7d-8a4fc0b795cc" /> | <img width="460" height="259" alt="theme" src="https://github.com/user-attachments/assets/d1b73dcb-82c9-465d-ba7e-da79ce263917" /> |

## Technology Stack

| Component | Purpose |
| --- | --- |
| [KDE Plasma](https://kde.org/plasma/) | Desktop Environment |
| [Quickshell](https://quickshell.outfoxxed.me/) | Widget System |
| [Darkly](https://github.com/vinceliuice/Darkly) | Theme Framework |
| [Kvantum](https://github.com/tsujan/Kvantum) | Qt Theme Engine |
| [KWin](https://invent.kde.org/plasma/kwin) | Window Manager |
| [Polonium](https://github.com/zeroxoneafour/polonium) | Window Tiling (optional) |

## Keybinds

| Shortcut | Action |
| --- | --- |
| `Super + /` | Show keybind cheatsheet |
| `Super + Enter` | Open terminal |
| `Super + Space` | Application launcher |
| `Super + B` | Toggle sidebar |
| `Super + V` | Clipboard history |
| `Super + Shift + S` | Screenshot |
| `Super + Shift + A` | Google Lens |
| `Super + Shift + C` | Color picker |

## Customization

Press `Super + Space` to launch the app menu, then type `>` to access Caelestia Tweaks.

**Wallpaper** — Use the built-in wallpaper manager (do not use KDE's default manager to ensure color extraction)

**Theme Colors** — Select schemes with dynamic color support for automatic color updates based on wallpaper

**Keyboard Shortcuts** — Edit [`src/keyboardshortcuts/shortcuts.md`](https://github.com/ladybug-me/caelestia-dots-kde/blob/main/src/keyboardshortcuts/shortcuts.md) and run [`src/keyboardshortcuts/register.sh`](https://github.com/ladybug-me/caelestia-dots-kde/blob/main/src/keyboardshortcuts/register.sh)

**Greeter GIFs** — Replace GIF files in [`shell/assets/`](https://github.com/ladybug-me/caelestia-dots-kde/tree/main/shell/assets/) and rebuild with `setup.sh`

## Troubleshooting

**Widgets not appearing**
- Log out and back in
- Run `caelestia shell -d` to check for diagnostic errors

**Colors not updating**
- Check status: `systemctl status --user kde-material-you-colors.service`
- Verify only dynamic-supported color schemes are selected
- Use the Caelestia wallpaper manager, not KDE's default manager

**Installation failed**
- Rerun `bash ./setup.sh` -- the installer is idempotent and safe to retry
- Follow installer prompts for error handling

**Restoration from backups**
- Backups are stored in `caelestia-dots-kde/backups/`
- To restore: `cp -r caelestia-dots-kde/backups/config ~/.config`

**Shell shortcuts not working**
- Restart the keyd service: `systemctl restart keyd`
- After kernel updates, reboot if you see "no uinput device" errors

## Credits

- **[Caelestia](https://github.com/caelestia)** — Original design and dotfiles
- **[ladybug-me](https://github.com/ladybug-me)** — KDE Plasma port
- **[KDE Plasma](https://kde.org/plasma/)** — Desktop environment
- **[Quickshell](https://quickshell.outfoxxed.me/)** — Widget framework
- **[Darkly](https://github.com/vinceliuice/Darkly)** — Theme base

## Links

- **GitHub:** [ladybug-me/caelestia-dots-kde](https://github.com/ladybug-me/caelestia-dots-kde)
- **Issues:** [GitHub Issues](https://github.com/ladybug-me/caelestia-dots-kde/issues)
- **Original:** [caelestia-dots/caelestia](https://github.com/caelestia-dots/caelestia)

## License

GNU General Public License v3.0. See [LICENSE](https://github.com/ladybug-me/caelestia-dots-kde/blob/main/LICENSE) for details.
