<div align="center">

<img src="assets/caelestia.svg" width="64" alt="Caelestia logo" />

# C A E L E S T I A

### A KDE Plasma port of the caelestia shell

[![Arch Linux](https://img.shields.io/badge/Arch_Linux-1793d1?logo=arch-linux&logoColor=white&style=flat-square)](https://archlinux.org)
[![Fedora](https://img.shields.io/badge/Fedora-51A2DA?logo=fedora&logoColor=white&style=flat-square)](https://fedoraproject.org)
[![Debian](https://img.shields.io/badge/Debian-A81D33?logo=debian&logoColor=white&style=flat-square)](https://debian.org)
[![KDE Plasma](https://img.shields.io/badge/Plasma_6-1D99F3?logo=kde&logoColor=white&style=flat-square)](https://kde.org/plasma-desktop)
[![License: GPLv3](https://img.shields.io/badge/License-GPLv3-86dbce?style=flat-square)](LICENSE)


</div>

---

## About

A community port of the [Caelestia Hyprland dotfiles](https://github.com/caelestia-dots/caelestia) to **KDE Plasma 6**, bringing the ethereal caelestia aesthetic to a full desktop environment with broader hardware and software compatibility.

## Installation

**Requirements:** Arch-based distro, Fedora, or Debian · KDE Plasma 6.0+

```bash
curl -fsSL https://raw.githubusercontent.com/ladybug-me/caelestia-dots-kde/main/install.sh | sh
```

### Updating

- **GUI:** Shell Settings -> Updates -> select branch -> Install Updates
- **CLI:** `bash update.sh` and choose `main` (stable) or `dev` (bleeding edge)

Shell settings are preserved across updates.

### Uninstalling

```bash
bash ./uninstall.sh
```

## Screenshots

https://github.com/user-attachments/assets/4c3e20c9-5050-4cc8-8e9c-32fd0594ac8b

| Shell | Theming |
|:---:|:---:|
| <img width="460" alt="shell" src="assets/shell-screenshot.png" /> | <img width="460" alt="theming" src="assets/theming-screenshot.png" /> |

## Keybinds

| Shortcut | Action |
| --- | --- |
| `Super + /` | Keybind cheatsheet |
| `Super + Enter` | Terminal |
| `Super + 1–5` | Switch workspace |
| `Super + Space` | App launcher |
| `Super + B` | Notification sidebar |
| `Super + V` | Clipboard history |
| `Super + Shift + S` | Screenshot |
| `Super + Shift + A` | Google Lens |
| `Super + Shift + D` | Text recognition |
| `Super + Ctrl + S` | Screen recorder |
| `Super + Shift + C` | Color picker |
| `Super + Shift + V` | Emoji selector |

## Tech Stack

| Component | Role |
| --- | --- |
| [KDE Plasma 6](https://kde.org/plasma-desktop) | Desktop environment |
| [Quickshell](https://quickshell.outfoxxed.me/) | Widget system |
| [Darkly](https://github.com/vinceliuice/Darkly) | Plasma style & window decoration |
| [Kvantum](https://github.com/tsujan/Kvantum) | Qt application theming |
| [Krohnkite](https://github.com/esjeon/krohnkite) | Optional tiling |

## Customization

<details>
<summary><b>Wallpaper & colors</b></summary>

Use the built-in wallpaper manager (`Super`, then `>Wallpaper`). Dynamic color schemes update automatically with your wallpaper. Do **not** use the default KDE wallpaper manager.

To browse all settings, `Super`, then `>Settings` to launch the Nexus settings panel - navigate to **Appearance** for wallpaper, colors, and themes.

</details>

<details>
<summary><b>Keyboard shortcuts</b></summary>

Use the built-in keyboard shortcut manager (`Super`, then `>Settings` to launch the Nexus settings panel - navigate to **Shortcuts**).

</details>

<details>
<summary><b>Greeter animations</b></summary>

Replace `morning.gif`, `afternoon.gif`, `evening.gif`, and `night.gif` in `shell/assets/`, then run `bash scripts/08-build-shell.sh`.

</details>

## Troubleshooting

| Problem | Fix |
| --- | --- |
| Widgets not appearing | Log out and back in, or run `caelestia shell -d` |
| Colors not applying | Run `systemctl status --user kde-material-you-colors.service`; re-run installer if needed |
| Install failed mid-way | Re-run `bash ./scripts/setup.sh` |
| Full reset needed | See [TROUBLESHOOTING.md](docs/TROUBLESHOOTING.md) |

For detailed debug logs, enable Debug Mode in Nexus -> About -> Advanced, then run `caelestia shell -l`.

## Thanks to

<!-- contributors-start -->
<table><tr>
<td width="50%">

### PRs

| Contributor | PRs |
| --- | ---: |
| [WinTone01](https://github.com/WinTone01) | 40 |
| [Vinax89](https://github.com/Vinax89) | 5 |
| [caelestia-automation[bot]](https://github.com/caelestia-automation[bot]) | 2 |
| [0x0nYx](https://github.com/0x0nYx) | 1 |
| [tomjod](https://github.com/tomjod) | 1 |
| [Peace-W](https://github.com/Peace-W) | 1 |
| [Klivan49](https://github.com/Klivan49) | 1 |
| [gitxpresso](https://github.com/gitxpresso) | 1 |

</td>
<td width="50%">

### Issues

| Contributor | Issues |
| --- | ---: |
| [0x0nYx](https://github.com/0x0nYx) | 106 |
| [Kyedae](https://github.com/Kyedae) | 17 |
| [bubbleo0](https://github.com/bubbleo0) | 11 |
| [RaceConditionWinner](https://github.com/RaceConditionWinner) | 10 |
| [KhanhNguyen1603](https://github.com/KhanhNguyen1603) | 9 |
| [arceus4526](https://github.com/arceus4526) | 6 |
| [RealNath](https://github.com/RealNath) | 6 |
| [francisco-tato](https://github.com/francisco-tato) | 5 |

</td>
</tr></table>

<!-- contributors-end -->

## Credits

- [Caelestia](https://github.com/caelestia-dots) - original design language and dotfiles
- [ladybug-me](https://github.com/ladybug-me) - KDE port lead & maintainer
- [0xSolanaceae](https://github.com/0xSolanaceae) - maintainer
- [dim-ghub](https://github.com/dim-ghub/caelestia-shell) - v2.0.0 features
- [nlohmann](https://github.com/nlohmann/json) - JSON parser
- [Haidir](https://bitbucket.org/dirn-typo/yet-another-monochrome-icon-set) - icon set

## License

[GPLv3](../LICENSE)

---

> *“Ad astra per aspera.”*
