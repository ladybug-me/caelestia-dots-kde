# Contributing to Caelestia KDE

We're glad you're here! This guide covers everything you need to start contributing.

## Quick start

```bash
git clone https://github.com/ladybug-me/caelestia-dots-kde ~/caelestia-dots-kde
cd ~/caelestia-dots-kde
bash scripts/setup.sh  # Full install - do this at least once
```

Make your changes in the cloned repo, test them (see below), then open a PR. That's it.

## What makes a good PR?

- **One thing at a time.** If you have three features, send three PRs - it's much faster to review.
- **Keep your personal config out.** Don't include your wallpaper path, custom keybinds, or local settings.
- **Experimental features off by default.** If it's flashy or niche, add a config toggle and default it to `false`.
- **Big ideas? Open an issue first.** It saves you from writing code we might not be able to accept.

## Where stuff lives

| Area | Directory | Tech |
| ------ | ----------- | ------ |
| Shell UI (launcher, bar, notifications, etc.) | `shell/` | QML + Quickshell |
| KWin plugin (window management, shortcuts) | `shell/plugin/` | C++ |
| TUI installer | `installer/src/` | C++ |
| Installer theme & menus | `installer/theme.json`, `installer/menu.json` | JSON |
| Install step scripts | `scripts/` | Bash |
| User-facing update scripts | `src/bin/` | Bash |

## Development workflow

### For QML / shell changes

Edit files in `~/.config/quickshell/caelestia/`. Changes reload automatically - no restart needed.

```bash
# View live logs
caelestia-shell-ipc log

# Restart the shell cleanly
caelestia shell -k && caelestia shell -d
```

**Editor setup:**

- Run `touch ~/.config/quickshell/caelestia/.qmlls.ini` for QML language server support
- In VS Code, install the "Qt Qml" extension and set the `qmlls` path to `/usr/bin/qmlls6`

### For C++ plugin changes

```bash
bash scripts/08-build-shell.sh   # Recompiles and installs the plugins
caelestia shell -k && caelestia shell -d   # Restart to pick up the new .so
```

The build keeps one core free and runs at a lower priority so the session stays
usable. Set `CAELESTIA_BUILD_JOBS` to override the job count.

### For installer changes

```bash
cd installer
cmake -B build && cmake --build build   # Compile
./build/caelestia-install               # Run (use with care!)
```

## Code style (the short version)

**QML:**

- Spaces between operators: `if (condition) {` not `if(condition){`
- Prefer early returns: `if (!ok) return;` over deep nesting
- Group related properties with blank lines
- Import order: QtQuick -> Qt -> Quickshell -> Caelestia -> qs.components -> qs.services -> qs.modules
- Run `python3 shell/scripts/qml-lint-conventions.py` - it catches most issues

**Shell scripts:**

- Use `set -euo pipefail` at the top
- Prefer `[[ ]]` over `[ ]`
- Quote variables: `"$VAR"` not `$VAR`
- Run `shellcheck` on your scripts

## Security

- When calling shell commands from QML, pass arguments as an array - never
  concatenate strings:

  ```js
  // Good
  Quickshell.execDetached(["bash", "-c", "echo \"$1\"", "--", myVar])
  // Bad
  Quickshell.execDetached(["bash", "-c", "echo " + myVar])
  ```

- Use `Paths.runtimeTemp("filename")` for temporary files - not hardcoded `/tmp/` paths.

## Architecture docs

- [KWin port architecture](docs/kwin_port_architecture.md) - C++ plugin design and QML APIs
- [Installer configuration](docs/installer_config.md) - theme.json and menu.json reference
- [Lock screen architecture](docs/lockscreen_architecture.md) - lockscreen.qml design

## Stuck?

Open a [Discussion](https://github.com/ladybug-me/caelestia-dots-kde/discussions) or ask in an issue - we're happy to help.
