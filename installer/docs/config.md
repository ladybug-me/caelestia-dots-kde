# Configuring Caelestia TUI Installer

## Quick Start

1. Open `installer/theme.json`
2. Modify the JSON values to your liking
3. Run `./setup.sh` to see the changes instantly—no C++ recompilation required!

**Minimal config structure:**
```json
{
  "colors": {
    "cyan": "36m",
    "magenta": "35m"
  },
  "splash_screen": {
    "art": [
      "   _____            _           _   _       ",
      "  / ____|          | |         | | (_)      "
    ],
    "animation_speed_ms": 3,
    "art_color": "magenta"
  },
  "layout": {
    "progress_box": {
      "title": "INSTALLATION PROGRESS",
      "color": "cyan",
      "title_color": "white",
      "text_color": "cyan"
    }
  },
  "strings": {
    "status_ok": "[OK]"
  }
}
```

---

## Configuration Reference

The `theme.json` file is broken down into four main configuration objects:

| Object | Description |
|--------|-------------|
| `colors` | Map of logical color names to raw ANSI escape sequences |
| `splash_screen` | Boot animation ASCII art and timing |
| `layout` | Mathematical layout coordinates, colors, and titles for UI boxes |
| `strings` | Localization/customization for common text strings |

---

## Colors

### `colors`

Defines the color palette used by the rest of the configuration. Values must be valid ANSI SGR (Select Graphic Rendition) color codes.

```json
"colors": {
    "cyan": "36m",
    "magenta": "35m",
    "green": "32m",
    "red": "31m",
    "yellow": "33m",
    "white": "1;37m"
}
```

---

## Splash Screen

### `splash_screen`

Controls the intro animation that plays before the main installer UI appears.

| Field | Type | Default | Description |
|-------|------|---------|-------------|
| `art` | array of strings | Caelestia Logo | The ASCII art lines to display |
| `animation_speed_ms` | int | `3` | Milliseconds to pause between drawing each line |
| `art_color` | string | `"magenta"` | The color name to apply to the ASCII art |
| `author` | string | `"By @ladybug-me"` | Author text displayed below the art |

```json
"splash_screen": {
    "art": [
        "My Custom Logo Line 1",
        "My Custom Logo Line 2"
    ],
    "animation_speed_ms": 5,
    "art_color": "cyan"
}
```

---

## Layout Configurations

### `layout`

Controls the exact pixel-perfect positioning and coloring of every UI box. Every box supports the following base color properties:

| Field | Type | Description |
|-------|------|-------------|
| `title` | string | The text displayed in the top border `[TITLE]` |
| `color` | string | The color of the outer border lines `+---|` |
| `title_color` | string | The color of the title text |
| `text_color` | string | The color of the inner text or progress bar |

### `layout.progress_box`
The main outer box wrapping the progress bar.
* **Additional fields:** `padding_x`, `padding_y`

### `layout.step_list`
The scrolling list of installation steps.
* **Additional fields:** `offset_x`, `offset_y`, `spacing_x`

### `layout.sudo_prompt`
The password prompt popup.
* **Additional fields:** `prompt_color`

### `layout.distro_select`
The OS detection confirmation box.

### `layout.config_checklist`
The interactive space-to-toggle menu for optional components.

### `layout.summary_screen`
The final success screen.

**Example of a fully customized box:**
```json
"progress_box": {
    "title": "SYSTEM DEPLOYMENT",
    "color": "magenta",
    "title_color": "white",
    "text_color": "green",
    "padding_x": 2,
    "padding_y": 1
}
```

---

## Strings

### `strings`

Allows overriding of standard status indicators used in the `step_list`.

| Field | Default | Description |
|-------|---------|-------------|
| `status_pending` | `"[ ]"` | Step hasn't started yet |
| `status_running` | `"[*]"` | Step is currently executing |
| `status_ok` | `"[OK]"` | Step completed successfully |
| `status_error` | `"[ERR]"` | Step failed |

```json
"strings": {
    "status_running": "[~]",
    "status_ok": "[✓]",
    "status_error": "[x]"
}
```
