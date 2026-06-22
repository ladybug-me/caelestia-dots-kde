# Contributing to end-4dotsKDE

Thanks for your interest in contributing to the KDE Plasma port!

## Guidelines

- Please make **multiple PRs** if you have many features/fixes—don't combine unrelated changes
- Don't include your personal configuration defaults in PRs
- We can accept features we don't personally use, but they **must be configurable** (off by default for experimental features)
- For **big changes**, please open an issue first to discuss—it saves effort for everyone

## Translations

See `src/config/quickshell/ii/translations/tools` for translation files.

# Code

## Dynamic loading

- If something's not always necessary, especially when guarded by a config option to enable/disable, put it in a `Loader`
  - Note that you will need to declare positioning properties (like `anchors`) in the `Loader`, not the `sourceComponent`
  - When something that's to be dynamically loaded doesn't affect its parent layout, you can have a fading animation by using FadeLoader and set the `shown` prop instead of `active` and `visible`

## Practical concerns

- Make sure what you add does not require significant resources for a minor purpose or harm usability just for the sake of looking nice. The dotfiles must remain practical for daily driving.
- If there is something really fancy and impractical anyway, add a config option for it and make sure it's disabled by default (example: constantly rotating background clock)

## Style

- Spaces
  - Space properties and children data into meaningful groups. (but of course, don't use 2+ blanks in a row)
  - Put spaces between text and operators: `if (condition) { ... } else { ... }` instead of `if(condition){ ... }else{ ... }`
- As you can see, it's pretty easy to use lots of nesting. There's no hard limit, end-4 himself nests a lot too, but avoid/mitigate that:
  - Prefer early return: Use something like `if (!condition) return; doStuff();` instead of `if (condition) { doStuff() }`
  - If you feel it's a bother to refractor something into a new file, remember there's `component` to declare reusable components in the same file.

## Setting up for Development

These instructions assume **Arch Linux** or an Arch-based distro.

### Full Installation (Recommended)

- Clone this repo: `git clone https://github.com/ladybug-me/end-4dotsKDE ~/end-4dotsKDE`
- Run the installer: `bash ~/end-4dotsKDE/setup.sh`
- Make your changes in the cloned repo
- Test locally, then push to your fork and create a PR

### Development-Only Setup

_For testing Quickshell widget changes without a full KDE installation:_

- Install KDE Plasma 6+ and Quickshell: `yay -S plasma-desktop quickshell-git`
- Copy `src/config/quickshell` folder to `~/.config/quickshell`
- Most widgets will work, but KDE integration may be limited

### Quickshell Development

- **LSP setup**: Run `touch ~/.config/quickshell/ii/.qmlls.ini` for QML language server support
- **VSCode**: Install the official "Qt Qml" extension, then set `qmlls` custom exe path to `/usr/bin/qmlls6` in settings
- **Live reload**: Changes to `.qml` files reload automatically when saved

### Python Scripts

If your changes involve Python scripts or packages:
- Use the virtual environment created by `uv` (see `sdata/uv/README.md`)
- Run: `cd sdata/uv && nix-shell` (or use `uv venv`)

## Testing Your Changes

**For KDE widgets:**
- Restart Plasmashell: `kquitapp6 plasmashell && kstart6 plasmashell`
- Or restart the Quickshell service: `systemctl --user restart qs-kwin-bridge`

**For Quickshell shell:**
- In a terminal: `pkill qs; qs -c ii` (shows logs for debugging)
- Edit files in `~/.config/quickshell/ii`, changes reload live

**For KDE settings:**
- Re-run the relevant installation step or manually test with `kwriteconfig6`
