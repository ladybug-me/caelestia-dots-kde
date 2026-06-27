<h1 align=center>caelestia-shell</h1>

<div align=center>

![GitHub last commit](https://img.shields.io/github/last-commit/dim-ghub/caelestia-shell?style=for-the-badge&labelColor=101418&color=9ccbfb)
![GitHub Repo stars](https://img.shields.io/github/stars/dim-ghub/caelestia-shell?style=for-the-badge&labelColor=101418&color=b9c8da)
![GitHub repo size](https://img.shields.io/github/repo-size/dim-ghub/caelestia-shell?style=for-the-badge&labelColor=101418&color=d3bfe6)
[![Discord invite](https://img.shields.io/badge/dynamic/json?url=https%3A%2F%2Fdiscordapp.com%2Fapi%2Finvites%2FBGDCFCmMBk%3Fwith_counts%3Dtrue&query=approximate_member_count&style=for-the-badge&logo=discord&logoColor=ffffff&label=discord&labelColor=101418&color=96f1f1&link=https%3A%2F%2Fdiscord.gg%2FBGDCFCmMBk)](https://discord.gg/BGDCFCmMBk)

</div>

> [!NOTE]
> This is a fork of the official [caelestia-shell](https://github.com/caelestia-dots/shell) with additional features. All new features are listed below.

https://github.com/user-attachments/assets/0840f496-575c-4ca6-83a8-87bb01a85c5f

## Fork Features

This fork adds the following features on top of the official shell:

- **Launchers**: Emoji Picker, Clipboard History, Window Switcher, and Hyprland Keybinds.
- **Wallpapers**: GIF/video support with auto-pause, plus Wallhaven integration.
- **Bad Apple Easter Egg**: A custom shader effect that plays Bad Apple directly through the shell's UI material by masking the background and preserving the shell's native translucent blur and shadow effects.
- **Games**: Playable Chrome Dino runner embedded in the notification dock.
- **Dashboard**: Developer console terminal tab with history and autocomplete.
- **Bar**: MacOS-style app dock, Material workspace icons, DND toggle, and a live drag-and-drop components editor.
- **Desktop**: Floating lyrics, Shimeji pets, dynamic wallpaper recoloring, and Bezel Mode.
- **Lock Screen**: Configurable auto-lock on startup (`lockOnStartup`), redesigned profile and clock layout, and improved forecast UI.
- **Hyprland**: Full support for the new Lua-based window focus and dispatching commands (`hl.dsp`).

## Installation

> [!NOTE]
> This repo is for the desktop shell of the caelestia dots. If you want installation instructions
> for the entire dots, head to [the main repo](https://github.com/caelestia-dots/caelestia) instead.
> This fork is available at [dim-ghub/caelestia-shell](https://github.com/dim-ghub/caelestia-shell).

### Arch Linux / Manual (this fork)

Dependencies:

-   [`caelestia-cli` (this fork is recommended and required for some features to work)](https://github.com/dim-ghub/caelestia-cli)
-   [`quickshell-git`](https://quickshell.outfoxxed.me) - this has to be the git version, not the latest tagged version
-   [`ddcutil`](https://github.com/rockowitz/ddcutil)
-   [`brightnessctl`](https://github.com/Hummer12007/brightnessctl)
-   [`app2unit`](https://github.com/Vladimir-csp/app2unit)
-   [`libcava`](https://github.com/LukashonakV/cava)
-   [`networkmanager`](https://networkmanager.dev)
-   [`lm-sensors`](https://github.com/lm-sensors/lm-sensors)
-   [`fish`](https://github.com/fish-shell/fish-shell)
-   [`aubio`](https://github.com/aubio/aubio)
-   [`libpipewire`](https://pipewire.org)
-   `glibc`
-   `qt6-declarative`
-   `gcc-libs`
-   [`material-symbols`](https://fonts.google.com/icons)
-   [`caskaydia-cove-nerd`](https://www.nerdfonts.com/font-downloads)
-   [`swappy`](https://github.com/jtheoof/swappy)
-   [`libqalculate`](https://github.com/Qalculate/libqalculate)
-   [`bash`](https://www.gnu.org/software/bash)
-   `qt6-base`
-   `qt6-declarative`
Build dependencies:

-   [`cmake`](https://cmake.org)
-   [`ninja`](https://github.com/ninja-build/ninja)

To install the shell manually, install all dependencies and clone **this fork** to `$XDG_CONFIG_HOME/quickshell/caelestia`.
Then simply run the install script:

```sh
sudo pacman -Rdd caelestia-shell

cd $XDG_CONFIG_HOME/quickshell
git clone https://github.com/dim-ghub/caelestia-shell.git caelestia

cd caelestia
./scripts/install.sh
```

Alternatively, this fork can be installed and managed via [`pkgmgr`](https://github.com/dim-ghub/pkgmgr)'s
`gh` plugin:

```sh
pkg install gh/dim-ghub/caelestia-shell-git
```

> [!TIP]
> By default, the script will use the latest version tag from [upstream](https://github.com/caelestia-dots/shell) to set the version number for the build. It does not download anything from upstream - it builds your local fork. You can also specify a version manually: `./scripts/install.sh 2.0.2`

### Nix

You can run the shell directly via `nix run`:

```sh
nix run github:caelestia-dots/shell
```

Or add it to your system configuration:

```nix
{
  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs/nixos-unstable";

    caelestia-shell = {
      url = "github:caelestia-dots/shell";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };
}
```

The package is available as `caelestia-shell.packages.<system>.default`, which can be added to your
`environment.systemPackages`, `users.users.<username>.packages`, `home.packages` if using home-manager,
or a devshell. The shell can then be run via `caelestia-shell`.

> [!TIP]
> The default package does not have the CLI enabled by default, which is required for full funcionality.
> To enable the CLI, use the `with-cli` package.

For home-manager, you can also use the Caelestia's home manager module (explained in [configuring](https://github.com/caelestia-dots/shell?tab=readme-ov-file#home-manager-module)) that installs and configures the shell and the CLI.

## Components

-   Widgets: [`Quickshell`](https://quickshell.outfoxxed.me)
-   Window manager: [`Hyprland`](https://hyprland.org)
-   Dots: [`caelestia`](https://github.com/caelestia-dots)

## Global Shortcuts

All keybinds are accessible via Hyprland [global shortcuts](https://wiki.hyprland.org/Configuring/Binds/#dbus-global-shortcuts).

### Available Shortcuts

| Shortcut Name | Description |
|---------------|-------------|
| `caelestia:controlCenter` | Open control center |
| `caelestia:launcher` | Toggle launcher |
| `caelestia:dashboard` | Toggle dashboard |
| `caelestia:session` | Toggle session menu |
| `caelestia:sidebar` | Toggle sidebar |
| `caelestia:utilities` | Toggle utilities panel |
| `caelestia:emoji` | Open emoji picker |
| `caelestia:clipboard` | Open clipboard history |
| `caelestia:windowSwitcher` | Open window switcher |
| `caelestia:keybinds` | Open keybinds list |
| `caelestia:wallpaper` | Open wallpaper picker |
| `caelestia:showall` | Toggle all UI elements |
| `caelestia:terminal` | Toggle terminal drawer |

### Hyprland Keybind Examples

To bind these shortcuts in Hyprland, add to your config:

```conf
# Launcher and UI elements
bind = SUPER, SPACE, global, caelestia:launcher
bind = SUPER, RETURN, global, caelestia:launcher
bind = SUPER, S, global, caelestia:controlCenter

# New features in this fork
bind = SUPER, E, global, caelestia:emoji
bind = SUPER, V, global, caelestia:clipboard
bind = SUPER, W, global, caelestia:windowSwitcher
bind = SUPER, K, global, caelestia:keybinds
bind = SUPER, B, global, caelestia:wallpaper
bind = SUPER, T, global, caelestia:terminal

# Other toggles
bind = SUPER, D, global, caelestia:dashboard
bind = SUPER, N, global, caelestia:sidebar
bind = SUPER, M, global, caelestia:utilities
```

## Migration from Official Caelestia

If you're migrating from the official caelestia shell to this fork, you may need to update your `shell.json` to include the new configuration options:

```json
"launcher": {
    "favouriteEmojis": [],
    "favouriteClips": []
},
"shimeji": {
    "enabled": false,
    "path": "root:/assets/shimeji/pusheen/",
    "count": 1,
    "autoHide": true,
    "excludedScreens": [],
    "screenCounts": {}
},
"background": {
    "videoWallpaperPaused": false,
    "videoWallpaperSoundEnabled": false,
    "videoWallpaperPauseOnFullscreen": false,
    "videoWallpaperPauseOnTiled": false,
    "videoWallpaperPauseOnAllDisplays": false,
    "videoWallpaperMuteOnMedia": false,
    "desktopLyrics": {
        "enabled": false,
        "autoHide": true,
        "scale": 1.0,
        "position": "bottom-center",
        "alignment": 1,
        "invertColors": false,
        "background": {
            "enabled": false,
            "opacity": 0.7,
            "blur": true
        },
        "shadow": {
            "enabled": true,
            "opacity": 0.7,
            "blur": 0.4
        }
    }
},
"utilities": {
    "quickToggles": [
        { "id": "wallpaper", "enabled": true },
        { "id": "badapple", "enabled": true },
        { "id": "pauseWallpaper", "enabled": true }
    ]
}
```

## Usage

The shell can be started via the `caelestia shell -d` command or `qs -c caelestia`.
If the entire caelestia dots are installed, the shell will be autostarted on login
via an `exec-once` in the hyprland config.

### Shortcuts/IPC

All keybinds are accessible via Hyprland [global shortcuts](https://wiki.hyprland.org/Configuring/Binds/#dbus-global-shortcuts).
If using the entire caelestia dots, the keybinds are already configured for you.
Otherwise, [this file](https://github.com/caelestia-dots/caelestia/blob/main/hypr/hyprland/keybinds.conf#L1-L39)
contains an example on how to use global shortcuts.

All IPC commands can be accessed via `caelestia shell ...`. For example

```sh
caelestia shell mpris getActive trackTitle
```

The list of IPC commands can be shown via `caelestia shell -s`:

```
$ caelestia shell -s
target drawers
  function toggle(drawer: string): void
  function list(): string
target notifs
  function clear(): void
target lock
  function lock(): void
  function unlock(): void
  function isLocked(): bool
target mpris
  function playPause(): void
  function getActive(prop: string): string
  function next(): void
  function stop(): void
  function play(): void
  function list(): string
  function pause(): void
  function previous(): void
target picker
  function openFreeze(): void
  function open(): void
target wallpaper
  function set(path: string): void
  function get(): string
  function list(): string
```

### PFP/Wallpapers

The profile picture for the dashboard is read from the file `~/.face`, so to set
it you can copy your image to there or set it via the dashboard.

The wallpapers for the wallpaper switcher are read from `~/Pictures/Wallpapers`
by default. To change it, change the wallpapers path in `~/.config/caelestia/shell.json`.

To set the wallpaper, you can use the command `caelestia wallpaper`. Use `caelestia wallpaper -h` for more info about
the command.

## Updating

If installed via the AUR package, simply update your system (e.g. using `yay`).

If installed via [`pkgmgr`](https://github.com/dim-ghub/pkgmgr), run:

```sh
pkg update
```

If installed manually, pull the latest changes and re-run the install script:

```sh
cd $XDG_CONFIG_HOME/quickshell/caelestia
git pull
./scripts/install.sh
```

## Configuring

All configuration options should be put in `~/.config/caelestia/shell.json`. This file is _not_ created by
default, you must create it manually. Options that you omit from the config file will use their default
values.

### Per-monitor configuration

You can configure options per-monitor in `~/.config/caelestia/monitors/<screen-name>/shell.json`. Options
set in this file will **override** the respective options in the global config. Otherwise, the options will
use their values from the global config.

For example, to disable the bar on DP-1:

**`~/.config/caelestia/monitors/DP-1/shell.json`**

```json
{
    "bar": {
        "persistent": false
    }
}
```

> [!NOTE]
> Not all options are respect per-monitor overrides. Most notably, the following options will only read
> from the global config, and ignore the respective option in per-monitor config files.
>
> <details><summary>Ignored options</summary>
>
> - `appearance` (`anim`, `transparency`)
> - `general` (`logo`, `apps`, `idle`, `battery`)
> - `bar.workspaces` (`perMonitorWorkspaces`, `specialWorkspaceIcons`, `windowIcons`, `wsIcons`)
> - `bar.tray` (`iconSubs`, `hiddenIcons`)
> - `dashboard` (`mediaUpdateInterval`, `resourceUpdateInterval`)
> - `launcher` (`specialPrefix`, `actionPrefix`, `enableDangerousActions`, `vimKeybinds`,
>   `favouriteApps`, `hiddenApps`, `actions`)
> - `launcher.useFuzzy` (`apps`, `actions`, `schemes`, `variants`, `wallpapers`)
> - `notifs` (`expire`, `fullscreen`, `defaultExpireTimeout`, `fullscreenExpireTimeout`, `actionOnClick`)
> - `lock` (`enableFprint`, `maxFprintTries`)
> - `nexus` (`networkRescanInterval`)
> - `utilities.toasts` (all except `fullscreen`)
> - `utilities.vpn` (`enabled`, `provider`)
> - `services` (`weatherLocation`, `useFahrenheit`, `useFahrenheitPerformance`, `useTwelveHourClock`,
>   `gpuType`, `visualiserBars`, `audioIncrement`, `brightnessIncrement`, `maxVolume`, `smartScheme`,
>   `defaultPlayer`, `playerAliases`, `lyricsBackend`)
> - `paths` (`wallpaperDir`, `lyricsDir`)
>
> </details>

### Example configuration

> [!NOTE]
> The example configuration includes ALL configuration options in `shell.json`. You are
> **not** recommended to copy and paste this entire configuration into `shell.json`.
> This is meant to serve as a reference of all the available options, and you should
> only add the ones you want to change to `shell.json`.

<details><summary>Example</summary>

```json
{
    "ai": {
        "activeOllamaModel": "llama3",
        "activeProvider": "ollama",
        "defaultOllamaModel": "llama3",
        "defaultProvider": "ollama",
        "enableCelestialMode": false,
        "enableOllama": true,
        "ollamaHistoryJson": "[]",
        "ollamaModel": "llama3",
        "ollamaUrl": "http://localhost:11434",
        "saveChatHistory": true,
        "snapToDefaultOllama": true
    },
    "appearance": {
        "anim": {
            "durations": {
                "scale": 1
            }
        },
        "deformScale": 1,
        "font": {
            "body": {
                "family": "GoogleSansFlex",
                "large": {
                    "family": "",
                    "italic": false,
                    "size": 16,
                    "vaxes": {
                        "ROND": 25
                    },
                    "weight": 400
                },
                "medium": {
                    "family": "",
                    "italic": false,
                    "size": 14,
                    "vaxes": {
                        "ROND": 25
                    },
                    "weight": 400
                },
                "small": {
                    "family": "",
                    "italic": false,
                    "size": 12,
                    "vaxes": {
                        "ROND": 25
                    },
                    "weight": 400
                }
            },
            "clock": "Rubik",
            "headline": {
                "family": "GoogleSansFlex",
                "large": {
                    "family": "",
                    "italic": false,
                    "size": 32,
                    "vaxes": {
                        "ROND": 25
                    },
                    "weight": 500
                },
                "medium": {
                    "family": "",
                    "italic": false,
                    "size": 28,
                    "vaxes": {
                        "ROND": 25
                    },
                    "weight": 500
                },
                "small": {
                    "family": "",
                    "italic": false,
                    "size": 24,
                    "vaxes": {
                        "ROND": 25
                    },
                    "weight": 500
                }
            },
            "icon": {
                "extraLarge": {
                    "family": "",
                    "italic": false,
                    "size": 36,
                    "vaxes": {},
                    "weight": 400
                },
                "family": "Material Symbols Rounded",
                "large": {
                    "family": "",
                    "italic": false,
                    "size": 24,
                    "vaxes": {},
                    "weight": 400
                },
                "medium": {
                    "family": "",
                    "italic": false,
                    "size": 18,
                    "vaxes": {},
                    "weight": 400
                },
                "small": {
                    "family": "",
                    "italic": false,
                    "size": 15,
                    "vaxes": {},
                    "weight": 400
                }
            },
            "label": {
                "family": "GoogleSansFlex",
                "large": {
                    "family": "",
                    "italic": false,
                    "size": 14,
                    "vaxes": {
                        "ROND": 25
                    },
                    "weight": 500
                },
                "medium": {
                    "family": "",
                    "italic": false,
                    "size": 12,
                    "vaxes": {
                        "ROND": 25
                    },
                    "weight": 500
                },
                "small": {
                    "family": "",
                    "italic": false,
                    "size": 11,
                    "vaxes": {
                        "ROND": 25
                    },
                    "weight": 400
                }
            },
            "mono": {
                "family": "CaskaydiaCove NF",
                "large": {
                    "family": "",
                    "italic": false,
                    "size": 16,
                    "vaxes": {},
                    "weight": 400
                },
                "medium": {
                    "family": "",
                    "italic": false,
                    "size": 14,
                    "vaxes": {},
                    "weight": 400
                },
                "small": {
                    "family": "",
                    "italic": false,
                    "size": 12,
                    "vaxes": {},
                    "weight": 400
                }
            },
            "scale": 1,
            "title": {
                "family": "GoogleSansFlex",
                "large": {
                    "family": "",
                    "italic": false,
                    "size": 22,
                    "vaxes": {
                        "ROND": 25
                    },
                    "weight": 500
                },
                "medium": {
                    "family": "",
                    "italic": false,
                    "size": 16,
                    "vaxes": {
                        "ROND": 25
                    },
                    "weight": 500
                },
                "small": {
                    "family": "",
                    "italic": false,
                    "size": 14,
                    "vaxes": {
                        "ROND": 25
                    },
                    "weight": 500
                }
            },
            "workspaces": "Rubik"
        },
        "padding": {
            "scale": 1
        },
        "pitchBlack": false,
        "rounding": {
            "scale": 1
        },
        "spacing": {
            "scale": 1
        },
        "transparency": {
            "base": 0.85,
            "enabled": false,
            "layers": 0.4
        }
    },
    "audio": {
        "sounds": {
            "cameraClick": true,
            "chargingStarted": true,
            "disabledNotifApps": [],
            "effectTick": true,
            "enabled": true,
            "lock": true,
            "lowBattery": true,
            "notificationSound": "Iapetus.wav",
            "notificationVolume": 1,
            "screenRecord": true,
            "sfxVolume": 1,
            "unlock": true
        }
    },
    "background": {
        "desktopClock": {
            "background": {
                "blur": true,
                "enabled": false,
                "opacity": 0.7
            },
            "enabled": false,
            "invertColors": false,
            "position": "bottom-right",
            "scale": 1,
            "shadow": {
                "blur": 0.4,
                "enabled": true,
                "opacity": 0.7
            }
        },
        "desktopLyrics": {
            "alignment": 1,
            "autoHide": true,
            "background": {
                "blur": true,
                "enabled": false,
                "opacity": 0.7
            },
            "enabled": false,
            "invertColors": false,
            "position": "bottom-center",
            "scale": 1,
            "shadow": {
                "blur": 0.4,
                "enabled": true,
                "opacity": 0.7
            }
        },
        "enabled": true,
        "videoWallpaperMuteOnMedia": false,
        "videoWallpaperPauseOnAllDisplays": false,
        "videoWallpaperPauseOnFullscreen": false,
        "videoWallpaperPauseOnTiled": false,
        "videoWallpaperPaused": false,
        "videoWallpaperSoundEnabled": false,
        "visualiser": {
            "autoHide": true,
            "blur": false,
            "enabled": false,
            "rounding": 1,
            "spacing": 1
        },
        "wallpaperEnabled": true
    },
    "bar": {
        "activeWindow": {
            "compact": false,
            "inverted": false,
            "showOnHover": true
        },
        "clock": {
            "background": false,
            "showDate": false,
            "showIcon": true
        },
        "dock": {
            "monitorCenter": true,
            "recolourIcons": false
        },
        "dragThreshold": 20,
        "entries": [
            {
                "enabled": true,
                "id": "logo"
            },
            {
                "enabled": true,
                "id": "workspaces"
            },
            {
                "enabled": true,
                "id": "github"
            },
            {
                "enabled": true,
                "id": "spacer"
            },
            {
                "enabled": true,
                "id": "activeWindow"
            },
            {
                "enabled": true,
                "id": "spacer"
            },
            {
                "enabled": true,
                "id": "tray"
            },
            {
                "enabled": true,
                "id": "clock"
            },
            {
                "enabled": true,
                "id": "statusIcons"
            },
            {
                "enabled": true,
                "id": "power"
            }
        ],
        "excludedScreens": [],
        "github": {
            "background": false,
            "token": ""
        },
        "persistent": true,
        "popouts": {
            "activeWindow": true,
            "statusIcons": true,
            "tray": true
        },
        "position": "left",
        "scrollActions": {
            "brightness": true,
            "volume": true,
            "workspaces": true
        },
        "showOnHover": true,
        "status": {
            "showAudio": false,
            "showBattery": true,
            "showBluetooth": true,
            "showKbLayout": false,
            "showLockStatus": true,
            "showMicrophone": false,
            "showNetwork": true,
            "showNotifications": true,
            "showPeripheralBattery": true,
            "peripheralBatteryExcluded": [],
            "showWifi": true
        },
        "tray": {
            "background": false,
            "compact": false,
            "hiddenIcons": [],
            "iconSubs": [],
            "recolour": false
        },
        "workspaces": {
            "activeIndicator": true,
            "activeLabel": " \udb82\udfaf",
            "activeTrail": false,
            "capitalisation": "preserve",
            "label": "\uf444 ",
            "maxWindowIcons": 5,
            "occupiedBg": false,
            "occupiedLabel": " \udb82\udfaf",
            "perMonitorWorkspaces": true,
            "showWindows": true,
            "showWindowsOnSpecialWorkspaces": true,
            "shown": 5,
            "specialWorkspaceIcons": [],
            "useIcon": true,
            "windowIcons": [
                {
                    "icon": "sports_esports",
                    "regex": "steam(_app_(default|[0-9]+))?"
                }
            ],
            "wsIcons": []
        }
    },
    "border": {
        "rounding": 25,
        "smoothing": 20,
        "thickness": 10
    },
    "dashboard": {
        "colorizeMediaGif": true,
        "dragThreshold": 50,
        "enabled": true,
        "mediaUpdateInterval": 500,
        "performance": {
            "showBattery": true,
            "showCpu": true,
            "showGpu": true,
            "showMemory": true,
            "showNetwork": true,
            "showStorage": true
        },
        "profilePicShape": 9,
        "resourceUpdateInterval": 1000,
        "showDashboard": true,
        "showHyprlandSplash": false,
        "showMedia": true,
        "showOnHover": true,
        "showPerformance": true,
        "showTerminal": true,
        "showWeather": true
    },
    "enabled": true,
    "general": {
        "apps": {
            "audio": [
                "pavucontrol"
            ],
            "explorer": [
                "thunar"
            ],
            "playback": [
                "mpv"
            ],
            "terminal": [
                "foot"
            ]
        },
        "battery": {
            "criticalLevel": 3,
            "warnLevels": [
                {
                    "icon": "battery_android_frame_2",
                    "level": 20,
                    "message": "You might want to plug in a charger",
                    "title": "Low battery"
                },
                {
                    "icon": "battery_android_frame_1",
                    "level": 10,
                    "message": "You should probably plug in a charger <b>now</b>",
                    "title": "Did you see the previous message?"
                },
                {
                    "critical": true,
                    "icon": "battery_android_alert",
                    "level": 5,
                    "message": "PLUG THE CHARGER RIGHT NOW!!",
                    "title": "Critical battery level"
                }
            ]
        },
        "idle": {
            "inhibitWhenAudio": true,
            "lockBeforeSleep": true,
            "timeouts": [
                {
                    "idleAction": "lock",
                    "timeout": 180
                },
                {
                    "idleAction": "dpms off",
                    "returnAction": "dpms on",
                    "timeout": 300
                },
                {
                    "idleAction": [
                        "loginctl",
                        "suspend"
                    ],
                    "timeout": 600
                }
            ]
        },
        "logo": "",
        "mediaGifSpeedAdjustment": 300,
        "sessionGifSpeed": 0.7,
        "showOverFullscreen": false
    },
    "launcher": {
        "actionPrefix": ">",
        "actions": [
            {
                "command": [
                    "autocomplete",
                    "calc"
                ],
                "description": "Do simple math equations (powered by Qalc)",
                "icon": "calculate",
                "name": "Calculator"
            },
            {
                "command": [
                    "autocomplete",
                    "scheme"
                ],
                "description": "Change the current colour scheme",
                "icon": "palette",
                "name": "Scheme"
            },
            {
                "command": [
                    "autocomplete",
                    "wallpaper"
                ],
                "description": "Change the current wallpaper",
                "icon": "image",
                "name": "Wallpaper"
            },
            {
                "command": [
                    "autocomplete",
                    "variant"
                ],
                "description": "Change the current scheme variant",
                "icon": "colors",
                "name": "Variant"
            },
            {
                "command": [
                    "caelestia",
                    "wallpaper",
                    "-r"
                ],
                "description": "Switch to a random wallpaper",
                "icon": "casino",
                "name": "Random"
            },
            {
                "command": [
                    "setMode",
                    "light"
                ],
                "description": "Change the scheme to light mode",
                "icon": "light_mode",
                "name": "Light"
            },
            {
                "command": [
                    "setMode",
                    "dark"
                ],
                "description": "Change the scheme to dark mode",
                "icon": "dark_mode",
                "name": "Dark"
            },
            {
                "command": [
                    "loginctl",
                    "poweroff"
                ],
                "dangerous": true,
                "description": "Shutdown the system",
                "icon": "power_settings_new",
                "name": "Shutdown"
            },
            {
                "command": [
                    "loginctl",
                    "reboot"
                ],
                "dangerous": true,
                "description": "Reboot the system",
                "icon": "cached",
                "name": "Reboot"
            },
            {
                "command": [
                    "hyprctl",
                    "dispatch",
                    "exit"
                ],
                "dangerous": true,
                "description": "Log out of the current session",
                "icon": "exit_to_app",
                "name": "Logout"
            },
            {
                "command": [
                    "loginctl",
                    "lock-session"
                ],
                "description": "Lock the current session",
                "icon": "lock",
                "name": "Lock"
            },
            {
                "command": [
                    "loginctl",
                    "suspend"
                ],
                "description": "Suspend then hibernate",
                "icon": "bedtime",
                "name": "Sleep"
            },
            {
                "command": [
                    "caelestia",
                    "shell",
                    "nexus",
                    "open"
                ],
                "description": "Configure the shell",
                "icon": "settings",
                "name": "Settings"
            },
            {
                "command": [
                    "autocomplete",
                    "emoji"
                ],
                "description": "Pick an emoji to copy",
                "icon": "emoji_emotions",
                "name": "Emoji"
            },
            {
                "command": [
                    "autocomplete",
                    "clipboard"
                ],
                "description": "View clipboard history",
                "icon": "content_paste",
                "name": "Clipboard"
            },
            {
                "command": [
                    "autocomplete",
                    "windows"
                ],
                "description": "Switch to another window",
                "enabled": true,
                "icon": "apps",
                "name": "Windows"
            },
            {
                "command": [
                    "autocomplete",
                    "keybinds"
                ],
                "description": "View all keybinds",
                "icon": "keyboard",
                "name": "Keybinds"
            }
        ],
        "dragThreshold": 50,
        "enableDangerousActions": false,
        "enabled": true,
        "favouriteApps": [],
        "favouriteClips": [],
        "favouriteEmojis": [],
        "hiddenApps": [],
        "maxShown": 7,
        "maxWallpapers": 9,
        "showOnHover": false,
        "specialPrefix": "@",
        "useFuzzy": {
            "actions": false,
            "apps": false,
            "clipboard": false,
            "emoji": false,
            "schemes": false,
            "variants": false,
            "wallpapers": false
        },
        "vimKeybinds": false
    },
    "lock": {
        "enableFprint": true,
        "hideNotifs": false,
        "maxFprintTries": 3,
        "profilePicShape": 12,
        "recolourLogo": true
    },
    "nexus": {
        "networkRescanInterval": 15000,
        "wallpapersPerRow": 4
    },
    "notifs": {
        "actionOnClick": false,
        "clearThreshold": 0.3,
        "defaultExpireTimeout": 5000,
        "expandThreshold": 20,
        "expire": true,
        "fullscreen": "on",
        "fullscreenExpireTimeout": 2000,
        "groupPreviewNum": 3,
        "openExpanded": false
    },
    "osd": {
        "enableBrightness": true,
        "enableMicrophone": false,
        "enabled": true,
        "hideDelay": 2000
    },
    "paths": {
        "cacheDir": "/home/dim/.cache/caelestia",
        "lockNoNotifsPic": "root:/assets/dino.png",
        "lyricsDir": "/home/dim/Music/Lyrics/",
        "mediaGif": "root:/assets/bongocat.gif",
        "noNotifsPic": "root:/assets/dino.png",
        "sessionGif": "root:/assets/kurukuru.gif",
        "wallpaperDir": "/home/dim/Pictures/Wallpapers"
    },
    "services": {
        "audioIncrement": 0.1,
        "brightnessIncrement": 0.1,
        "defaultPlayer": "Spotify",
        "gpuType": "",
        "lyricsBackend": "Auto",
        "maxVolume": 1,
        "playerAliases": [
            {
                "from": "com.github.th_ch.youtube_music",
                "to": "YT Music"
            }
        ],
        "smartScheme": true,
        "useFahrenheit": true,
        "useFahrenheitPerformance": false,
        "useTwelveHourClock": true,
        "visualiserBars": 60,
        "weatherLocation": ""
    },
    "session": {
        "commands": {
            "hibernate": [
                "loginctl",
                "hibernate"
            ],
            "logout": [
                "hyprctl",
                "dispatch",
                "exit"
            ],
            "reboot": [
                "loginctl",
                "reboot"
            ],
            "shutdown": [
                "loginctl",
                "poweroff"
            ]
        },
        "dragThreshold": 30,
        "enabled": true,
        "icons": {
            "hibernate": "downloading",
            "logout": "logout",
            "reboot": "cached",
            "shutdown": "power_settings_new"
        },
        "vimKeybinds": false
    },
    "shimeji": {
        "autoHide": true,
        "count": 1,
        "enabled": true,
        "excludedScreens": [],
        "path": "root:/assets/shimeji/pusheen/",
        "screenCounts": {}
    },
    "sidebar": {
        "dragThreshold": 80,
        "enabled": true
    },
    "utilities": {
        "enabled": true,
        "maxToasts": 4,
        "quickToggles": [
            {
                "enabled": true,
                "id": "wifi"
            },
            {
                "enabled": true,
                "id": "bluetooth"
            },
            {
                "enabled": true,
                "id": "mic"
            },
            {
                "enabled": true,
                "id": "settings"
            },
            {
                "enabled": true,
                "id": "gameMode"
            },
            {
                "enabled": true,
                "id": "dnd"
            },
            {
                "enabled": false,
                "id": "vpn"
            },
            {
                "enabled": true,
                "id": "wallpaper"
            },
            {
                "enabled": true,
                "id": "badapple"
            }
        ],
        "toasts": {
            "audioInputChanged": true,
            "audioOutputChanged": true,
            "capsLockChanged": true,
            "chargingChanged": true,
            "configLoaded": true,
            "dndChanged": true,
            "fullscreen": "off",
            "gameModeChanged": true,
            "kbLayoutChanged": true,
            "kbLimit": true,
            "nowPlaying": false,
            "numLockChanged": true,
            "transparency": false,
            "transparencyBase": 0.85,
            "vpnChanged": true
        },
        "vpn": {
            "enabled": false,
            "provider": []
        }
    },
    "winfo": {}
}
```

</details>

### Advanced configuration

> [!WARNING]
> Do NOT change any of these options if you do not know what you are doing. These options control the
> tokens used internally within the shell, and can cause visual issues if changed. The existence of
> the options are also not guaranteed across versions, and may change or be removed without notice.

A separate `~/.config/caelestia/shell-tokens.json` file allows editing the internal tokens without
touching the source code of the shell. These tokens affect, for example, individual rounding,
spacing, padding, font size, animation duration and easing curves tokens, and the sizes of certain
components. The appearance scale values in `shell.json` are multiplied against these base
token values to produce the final computed values.

Per-monitor token overrides are also available at
`~/.config/caelestia/monitors/<screen-name>/shell-tokens.json`.

### Home Manager Module

For NixOS users, a home manager module is also available.

<details><summary><code>home.nix</code></summary>

```nix
programs.caelestia = {
  enable = true;
  systemd = {
    enable = false; # if you prefer starting from your compositor
    target = "graphical-session.target";
    environment = [];
  };
  settings = {
    bar.status = {
      showBattery = false;
    };
    paths.wallpaperDir = "~/Images";
  };
  cli = {
    enable = true; # Also add caelestia-cli to path
    settings = {
      theme.enableGtk = false;
    };
  };
};
```

The module automatically adds Caelestia shell to the path with **full functionality**. The CLI is not required, however you have the option to enable and configure it.

</details>

## FAQ

### Need help or support?

You can join the community Discord server for assistance and discussion:
https://discord.gg/BGDCFCmMBk

### My screen is flickering, help pls!

Try disabling VRR in the hyprland config. You can do this by adding the following to `~/.config/caelestia/hypr-user.conf`:

```conf
misc {
    vrr = 0
}
```

### How do I enable blur for the Polkit dialog?

Add the following layer rule to your `~/.config/caelestia/hypr-user.conf`:

```conf
layerrule = no_anim true, match:namespace caelestia-polkit, blur true, ignore_alpha 0.1
```

### I want to make my own changes to the hyprland config!

You can add your custom hyprland configs to `~/.config/caelestia/hypr-user.conf`.

### I want to make my own changes to other stuff!

See the [manual installation](https://github.com/caelestia-dots/shell?tab=readme-ov-file#manual-installation) section
for the corresponding repo.

### I want to disable XXX feature!

Please read the [configuring](https://github.com/caelestia-dots/shell?tab=readme-ov-file#configuring) section in the readme.
If there is no corresponding option, make feature request.

### How do I make my colour scheme change with my wallpaper?

Set a wallpaper via the launcher or `caelestia wallpaper` and set the scheme to the dynamic scheme via the launcher
or `caelestia scheme set`. e.g.

```sh
caelestia wallpaper -f <path/to/file>
caelestia scheme set -n dynamic
```

### My wallpapers aren't showing up in the launcher!

The launcher pulls wallpapers from `~/Pictures/Wallpapers` by default. You can change this in the config. Additionally,
the launcher only shows an odd number of wallpapers at one time. If you only have 2 wallpapers, consider getting more
(or just putting one).

## Credits

Thanks to the Hyprland discord community (especially the homies in #rice-discussion) for all the help and suggestions
for improving these dots!

A special thanks to [@outfoxxed](https://github.com/outfoxxed) for making Quickshell and the effort put into fixing issues
and implementing various feature requests.

Another special thanks to [@end_4](https://github.com/end-4) for his [config](https://github.com/end-4/dots-hyprland)
which helped me a lot with learning how to use Quickshell.

Finally another thank you to all the configs I took inspiration from (only one for now):

-   [Axenide/Ax-Shell](https://github.com/Axenide/Ax-Shell)

## Stonks 📈

<a href="https://www.star-history.com/#caelestia-dots/shell&Date">
 <picture>
   <source media="(prefers-color-scheme: dark)" srcset="https://api.star-history.com/svg?repos=dim-ghub/caelestia-shell&type=Date&theme=dark" />
   <source media="(prefers-color-scheme: light)" srcset="https://api.star-history.com/svg?repos=caelestia-dots/shell&type=Date" />
   <img alt="Star History Chart" src="https://api.star-history.com/svg?repos=caelestia-dots/shell&type=Date" />
 </picture>
</a>
