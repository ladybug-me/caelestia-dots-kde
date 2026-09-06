# Configuring the Caelestia TUI Installer

The installer TUI (`caelestia-install`) is a Go program built on charmbracelet Bubble Tea. It is data-driven: three JSON files under `installer/` define its look and behavior, and the step list comes from a manifest consumed by the runner.

| File | Purpose |
|------|---------|
| `installer/theme.json` | Color palette, splash art, and status glyphs |
| `installer/menu.json` | The Configure screen: submenus, toggles, and selects |
| `installer/steps.json` | Phases and steps the runner executes |

`menu.json` ids become exported environment variables that the step scripts read. The installer persists the final answers to `~/.config/caelestia-kde/install.env` so `update.sh` can restore them later.

## theme.json

```json
{
  "palette": {
    "primary": "#ffb0ca",
    "accent": "#ff4c8a",
    "muted": "#8e6f78"
  },
  "splash_screen": {
    "art": ["  line one", "  line two"],
    "author": "By @ladybug-me",
    "co_author": "Co-maintainer: 0xSolanaceae",
    "art_color": "accent"
  },
  "glyphs": {
    "pending": "[ ]",
    "ok": "[OK]"
  }
}
```

- `palette`: logical color names mapped to `#rrggbb` hex values. Every color referenced by the UI resolves here.
- `splash_screen.art`: lines of ASCII art shown on the Welcome screen. `art_color` names a palette entry.
- `glyphs`: status and checkbox markers. Keys are `pending`, `running`, `ok`, `warn`, `failed`, `skipped`, `checkbox_on`, `checkbox_off`, `select_left`, `select_right`. Missing keys fall back to defaults.

## menu.json

The root is a `menu` array. Each item has a `type` and a `title`; items that collect data also have an `id`, which becomes the exported environment variable name.

| Type | Description | Required fields |
|------|-------------|-----------------|
| `submenu` | A nested group of items | `items` (array) |
| `boolean` | A checkbox toggle exported as `true` or `false` | `id`, optional `default` |
| `select` | Cycles through predefined options | `id`, `options` (array), optional `default` |
| `action` | A built-in navigation action | `id` (`action_back` or `action_review`) |

`action_back` returns to the parent menu; `action_review` (at the root) opens the Review screen and begins installation. `validate_json_configs.py` checks this schema.

## steps.json

```json
{
  "phases": [
    { "id": "prepare", "name": "Prepare" }
  ],
  "steps": [
    { "name": "Refresh mirrors", "script": "scripts/00-refresh-mirrors.sh", "phase": "prepare" }
  ]
}
```

- `phases`: named groups of steps, in display order.
- `steps`: one entry per install unit. `name` is the display name, `script` is the path under the bundle root, and `phase` must match a phase id.

This file is the single source of truth for the step list. `test_repo_integrity.py` validates it (scripts exist, no duplicate names, phase references) and `validate_json_configs.py` checks its schema.

## Environment variables exported to step scripts

The installer sets these before running steps:

| Variable | Description |
|----------|-------------|
| `PATH` | Prepended with the per-run sudo wrapper directory |
| `SUDO_PASS` | Password for steps that need it |
| `CACHE_DIR` | Primary cache directory, usually `~/.cache/caelestia-kde` |
| `BUILDDIR` | AUR build directory (`makepkg-build`) |
| `PKGDEST` | Destination for built packages |
| `SRCDEST` | Destination for downloaded sources |
| `SRCPKGDEST` | Destination for source packages |
| `BASE_DISTRO` | Detected base distribution (e.g. `arch`, `fedora`, `debian`) |
| `BUNDLE_DIR` | Repository root (parent of `scripts/setup.sh`) |
| `CONFIRM_ARG` | Set to `--noconfirm` |

Plus every `menu.json` item id, exported with its chosen value.
