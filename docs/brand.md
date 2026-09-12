# Brand rules

These rules are what make this repo read as a KDE Plasma port of
[caelestia-dots/shell](https://github.com/caelestia-dots/shell). They are binding
for anything a user reads: docs, release notes, installer output, badges and
in-app labels.

## Name

The project is called Caelestia. It has no product name of its own - it is
Caelestia, running on KDE Plasma.

- In prose and user-facing labels: `Caelestia`.
- In identifiers, always lowercase `caelestia`: paths, systemd units, packages,
  binaries, D-Bus interfaces, cache and state directories, the QML namespace,
  and repo slugs.
- The port relationship is stated once, in the README's upstream note.
- `Caelestia Shell` survives only as the label of the autostart desktop entry
  and its systemd unit.

There is no `Caelestia KDE`, `Caelestia KDE Port`, `Caelestia KWin`,
`Caelestia KWin Port`, and no letterspaced wordmark.

## Colors

The brand palette is the `caelestia` scheme the CLI ships, in both modes:

| Token | Dark | Light |
| --- | --- | --- |
| surface / background | `#0a0f0f` | `#f6faf9` |
| on surface | `#dce8e6` | `#2a3433` |
| primary | `#9bd0cc` | `#1c6a66` |
| on primary | `#0d4845` | `#e1fffc` |
| primary container | `#255b58` | `#a8f0eb` |
| secondary | `#b0ccc9` | `#4a6462` |
| tertiary | `#d5efff` | `#37647b` |
| outline | `#6d7876` | `#727d7c` |
| error | `#fa746f` | `#a83836` |
| success | `#B5CCBA` | `#4F6354` |

Every static surface that owns a palette - the installer TUI, the lock screen,
SDDM - presents this scheme. The shell's own palette is dynamic and is not
governed by this rule.

Two values have no scheme token, and are deliberate exceptions:

- `accent` is the logo's aqua `#6ae5e1`. The scheme has no saturated accent, and
  the TUI's figlet art needs one that reads against `#0a0f0f`.
- `warning` stays an amber (`#e8c87a`). The scheme ships no warning token, and no
  existing token means "warning".

## Assets

- Logo: `assets/logo.svg`. It is upstream's artwork with an adaptive fill, so it
  reads on both GitHub themes. Do not redraw it and do not add a second copy.
  The vendored `shell/assets/logo.svg` is upstream's own file - it is synced, not
  ours, and the running shell keeps using it.
- Banner: one artwork, defined once in `installer/data/theme.json`. The
  uninstaller and the fish greeting render the same lines; only the coloring
  differs per surface.

## Voice

- Terse and imperative. Say what a thing does, not how it feels.
- No marketing adjectives, no decorative Latin, no aesthetic copy.
- No emoji, except the single `## Stonks` heading that mirrors upstream.
- Plain hyphen `-`, never an em dash.
- No bold for emphasis in prose.
- No decorative rule or banner comments in source files. Plain comments only.
- US English spelling everywhere: `color`, `license`, `behavior`, `catalog`.
- Release notes end with the list of changes. No sign-off flourish.

## License and attribution

- `GPL-3.0-or-later`, everywhere: the `LICENSE` file, the README badge, and every
  SPDX header.
- Upstream is credited by name in the README, and the `caelestia` CLI, its scheme
  library and its authors stay attributed.
