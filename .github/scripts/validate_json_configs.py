#!/usr/bin/env python3
"""Validate JSON configuration files for schema and internal consistency.

Validates:
  1. installer/theme.json - required top-level keys, color references are valid,
     ANSI codes match expected pattern.
  2. installer/menu.json - valid menu tree, unique IDs, all action IDs are recognized,
     select options are non-empty, text defaults are strings.
"""

import json
import re
import sys
from pathlib import Path
from typing import Any

ROOT = Path(__file__).resolve().parents[2]

RED = "\033[0;31m"
GREEN = "\033[0;32m"
YELLOW = "\033[0;33m"
BOLD = "\033[1m"
RESET = "\033[0m"

EXIT_CODE = 0


def error(msg: str) -> None:
    global EXIT_CODE
    print(f"{RED}[ERR]{RESET}  {msg}")
    EXIT_CODE = 1


def warn(msg: str) -> None:
    print(f"{YELLOW}[WARN]{RESET} {msg}")


def ok(msg: str) -> None:
    print(f"{GREEN}[OK]{RESET}   {msg}")


# ─── theme.json validation ───

ANSI_SGR_RE = re.compile(r"^\d+(;\d+)*m$")

REQUIRED_THEME_COLORS = {
    "default", "cyan", "magenta", "green", "red", "yellow", "white",
}

REQUIRED_THEME_SECTIONS = {
    "colors",
    "splash_screen",
    "layout",
    "strings",
}

LAYOUT_BOXES = {
    "progress_box", "step_list", "sudo_prompt",
    "distro_select", "config_checklist", "summary_screen",
}

BOX_COLOR_KEYS = {"color", "title_color", "text_color"}
BOX_OPTIONAL_KEYS = {"padding_x", "padding_y", "offset_x", "offset_y", "spacing_x", "prompt_color"}


def validate_theme(filepath: Path) -> None:
    print(f"\n{BOLD}=== Validating {filepath.relative_to(ROOT)} ==={RESET}")

    try:
        data = json.loads(filepath.read_text(encoding="utf-8"))
    except json.JSONDecodeError as e:
        error(f"{filepath}: invalid JSON - {e}")
        return

    # Top-level sections
    for section in REQUIRED_THEME_SECTIONS:
        if section not in data:
            error(f"theme.json: missing required section '{section}'")

    # Validate colors
    colors = data.get("colors", {})
    if isinstance(colors, dict):
        for name, code in colors.items():
            if not isinstance(code, str) or not ANSI_SGR_RE.match(code):
                error(f"theme.json: color '{name}' has invalid ANSI code: {code!r}")

        # Check that referenced colors exist
        defined_colors = set(colors.keys())

        def check_color_ref(value: str, context: str) -> None:
            if isinstance(value, str) and value in ("default", "dim"):
                return  # special values OK
            if isinstance(value, str) and value not in defined_colors:
                error(f"theme.json: {context} references undefined color '{value}'")

        # Check splash_screen art_color
        splash = data.get("splash_screen", {})
        if isinstance(splash, dict):
            art_color = splash.get("art_color", "")
            check_color_ref(art_color, "splash_screen.art_color")
            loading_color = splash.get("loading_text_color", "")
            if loading_color != "dim":
                check_color_ref(loading_color, "splash_screen.loading_text_color")

        # Check layout boxes
        layout = data.get("layout", {})
        if isinstance(layout, dict):
            for box_name, box_config in layout.items():
                if isinstance(box_config, dict):
                    for color_key in BOX_COLOR_KEYS:
                        if color_key in box_config:
                            check_color_ref(
                                box_config[color_key],
                                f"layout.{box_name}.{color_key}",
                            )

        # Warn about extra colors that are never referenced
        all_text = json.dumps(data)
        for color_name in defined_colors:
            # Count how many times the color name appears as a value (not as a key)
            # Simple heuristic: count occurrences of "color_name" as a JSON string value
            if all_text.count(f'"{color_name}"') <= 1:  # 1 = the definition itself
                warn(f"theme.json: color '{color_name}' is defined but may be unused")

    # Validate splash_screen
    if isinstance(splash, dict):
        art = splash.get("art")
        if not isinstance(art, list) or len(art) == 0:
            error("theme.json: splash_screen.art must be a non-empty array of strings")
        elif not all(isinstance(line, str) for line in art):
            error("theme.json: all splash_screen.art elements must be strings")

        speed = splash.get("animation_speed_ms")
        if not isinstance(speed, (int, float)):
            warn("theme.json: splash_screen.animation_speed_ms should be a number")

    # Validate strings section
    strings = data.get("strings", {})
    if isinstance(strings, dict):
        valid_status_keys = {"status_pending", "status_running", "status_ok", "status_error"}
        for key in strings:
            if key not in valid_status_keys:
                warn(f"theme.json: unrecognized string key '{key}'")

    # Validate layout boxes
    if isinstance(layout, dict):
        for box_name, box_config in layout.items():
            if not isinstance(box_config, dict):
                error(f"theme.json: layout.{box_name} must be an object")
                continue
            if "title" not in box_config and box_name in LAYOUT_BOXES:
                warn(f"theme.json: layout.{box_name} is missing 'title'")
            for prop in BOX_COLOR_KEYS:
                if prop in box_config and not isinstance(box_config[prop], str):
                    error(f"theme.json: layout.{box_name}.{prop} must be a string")

    ok("theme.json passed validation")


# ─── menu.json validation ───

VALID_MENU_TYPES = {"submenu", "boolean", "select", "text", "action"}
VALID_ACTION_IDS = {"action_proceed", "action_back"}


def validate_menu_items(items: list[Any], path: str = "menu", seen_ids: set[str] | None = None) -> None:
    if seen_ids is None:
        seen_ids = set()

    if not isinstance(items, list):
        error(f"menu.json: {path} must be an array")
        return

    for i, item in enumerate(items):
        item_path = f"{path}[{i}]"
        if not isinstance(item, dict):
            error(f"menu.json: {item_path} must be an object")
            continue

        item_type = item.get("type")
        if item_type not in VALID_MENU_TYPES:
            error(f"menu.json: {item_path} has invalid type: {item_type!r}")

        title = item.get("title")
        if not isinstance(title, str) or not title.strip():
            error(f"menu.json: {item_path} is missing a non-empty 'title'")

        item_id = item.get("id")

        if item_type == "submenu":
            if not isinstance(item_id, str):
                error(f"menu.json: {item_path} submenu must have a string 'id'")
            elif item_id in seen_ids:
                error(f"menu.json: {item_path} duplicate id '{item_id}'")
            else:
                seen_ids.add(item_id)
            sub_items = item.get("items")
            if not isinstance(sub_items, list) or len(sub_items) == 0:
                error(f"menu.json: {item_path} submenu 'items' must be a non-empty array")
            else:
                validate_menu_items(sub_items, f"{item_path}.items", seen_ids)

        elif item_type == "boolean":
            if not isinstance(item_id, str):
                error(f"menu.json: {item_path} boolean must have a string 'id'")
            default = item.get("default")
            if default is not None and not isinstance(default, bool):
                error(f"menu.json: {item_path} boolean 'default' must be a boolean")

        elif item_type == "select":
            if not isinstance(item_id, str):
                error(f"menu.json: {item_path} select must have a string 'id'")
            options = item.get("options")
            if not isinstance(options, list) or len(options) == 0:
                error(f"menu.json: {item_path} select 'options' must be a non-empty array")
            default = item.get("default")
            if default is not None and options and default not in options:
                warn(f"menu.json: {item_path} default '{default}' not in options {options}")

        elif item_type == "text":
            if not isinstance(item_id, str):
                error(f"menu.json: {item_path} text must have a string 'id'")
            default = item.get("default")
            if default is not None and not isinstance(default, str):
                error(f"menu.json: {item_path} text 'default' must be a string")

        elif item_type == "action":
            if item_id not in VALID_ACTION_IDS:
                error(f"menu.json: {item_path} action id must be one of {VALID_ACTION_IDS}, got: {item_id!r}")


def validate_menu(filepath: Path) -> None:
    print(f"\n{BOLD}=== Validating {filepath.relative_to(ROOT)} ==={RESET}")

    try:
        data = json.loads(filepath.read_text(encoding="utf-8"))
    except json.JSONDecodeError as e:
        error(f"menu.json: invalid JSON - {e}")
        return

    if not isinstance(data, dict):
        error("menu.json: root must be an object")
        return

    menu_items = data.get("menu")
    if not isinstance(menu_items, list):
        error("menu.json: missing 'menu' array")
        return

    if len(menu_items) == 0:
        error("menu.json: 'menu' array is empty")
        return

    # Check that root menu has at least one action_proceed
    has_proceed = any(
        isinstance(item, dict) and item.get("id") == "action_proceed"
        for item in menu_items
    )
    if not has_proceed:
        error("menu.json: root menu must include an 'action_proceed' item")

    validate_menu_items(menu_items)

    if EXIT_CODE == 0:
        ok("menu.json passed validation")


def main() -> int:
    theme_path = ROOT / "installer" / "theme.json"
    menu_path = ROOT / "installer" / "menu.json"

    if theme_path.is_file():
        validate_theme(theme_path)
    else:
        error(f"{theme_path.relative_to(ROOT)} not found")

    if menu_path.is_file():
        validate_menu(menu_path)
    else:
        error(f"{menu_path.relative_to(ROOT)} not found")

    print()
    if EXIT_CODE == 0:
        print(f"{BOLD}{GREEN}All JSON config validations passed.{RESET}")
    else:
        print(f"{BOLD}{RED}Some JSON config validations failed.{RESET}")

    return EXIT_CODE


if __name__ == "__main__":
    sys.exit(main())
