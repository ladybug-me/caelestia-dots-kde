# Matugen as the colour pipeline

Draft, first step on the ticket [Owning the color pipeline](../../docs/wayfinder/parity/tickets/owning-the-color-pipeline.md). Nothing calls these files yet: they are the shape we are testing before the command gives up its hand-off to the upstream CLI.

## Why matugen

It generates Material You palettes from an image or a single colour, using the same specification upstream's `python-materialyoucolor` implements, and it writes files through a template engine. That covers generation and, when the templates are written, the theming fan-out to terminals, GTK, Qt and the rest, which today lives in the upstream CLI's `theme.py`.

It is packaged in Arch's `extra`, and it is GPL-2.0-or-later, which combines with our GPL-3.0-or-later. Carrying the upstream CLI instead would force this package to `GPL-3.0-only`.

## The contract this template has to hit

`shell/services/Colours.qml` reads `$XDG_STATE_HOME/caelestia/scheme.json`:

- `name`, `flavour`, `mode` and `variant` are plain strings, trimmed on read;
- `colours` holds the roles. Each key becomes `m3<Key>` on the QML side, so the file carries `primary`, not `m3primary`. Keys beginning with `term` are used as they are, which is how `term0` to `term15` arrive;
- a value is the hex digits only. `Colours.qml` prepends the `#` itself, which is why the template asks for `hex_stripped` and not `hex`;
- a key that is absent leaves the shell's built-in default in place, so the template can grow instead of landing complete.

## What is verified and what is not

Verified: the template syntax `{{ colors.<role>.<mode>.<format> }}` with `default`, `light` and `dark` as modes and `hex_stripped` as the format; per-template `type`, `input_path`, `output_path` and hooks; `--import-json` and `import_json_files` for custom keywords.

Not verified, and the first thing to do before wiring this up:

1. the exact snake_case spelling of every role in the template. Run `matugen image <wallpaper> --json` (or `--show-colors`) once on an Arch box and trim the template to the names that actually exist, because an unknown keyword fails the whole render;
2. the reference syntax for the imported `name`, `flavour` and `variant` strings. If imported JSON cannot be referenced as plain strings, the command writes those three fields itself and the template emits the colour map only;
3. whether `{{ mode }}` is a keyword, so light and dark come from matugen rather than from the command;
4. base16 output for `term0` to `term15`. If it is not reachable from the same run, the terms need a second pass or a mapping from the M3 roles.

## Two roles are not Material You

`m3success`, `m3onSuccess`, `m3successContainer` and `m3onSuccessContainer` are ours, not the specification's, and matugen has no keyword for them. They are absent from the template on purpose, so the shell keeps its defaults for now. They need a decision: a harmonized green derived from the scheme, or fixed values from `[config.custom_colors]`.

## Trying it

On an Arch box, with a wallpaper to hand:

    matugen image /path/to/wallpaper.jpg --config src/matugen/config.toml --dry-run

`--dry-run` shows the rendered output without writing it. Compare the result against a `scheme.json` produced by the current CLI, role by role, before trusting it.
