# Matugen as the color pipeline

Draft, first step on the ticket [Owning the color pipeline](../../docs/wayfinder/parity/tickets/owning-the-color-pipeline.md). Nothing calls these files yet: they are the shape we are testing before the command gives up its hand-off to the upstream CLI.

## Why matugen

It generates Material You palettes from an image or a single color, using the same specification upstream's `python-materialyoucolor` implements, and it writes files through a template engine. That covers generation and, when the templates are written, the theming fan-out to terminals, GTK, Qt and the rest, which today lives in the upstream CLI's `theme.py`.

It is packaged in Arch's `extra`, and it is GPL-2.0-or-later, which combines with our GPL-3.0-or-later. Carrying the upstream CLI instead would force this package to `GPL-3.0-only`.

## The contract this template has to hit

`shell/services/Colours.qml` reads `$XDG_STATE_HOME/caelestia/scheme.json`:

- `name`, `flavour`, `mode` and `variant` are plain strings, trimmed on read;
- `colours` holds the roles. Each key becomes `m3<Key>` on the QML side, so the file carries `primary`, not `m3primary`. Keys beginning with `term` are used as they are, which is how `term0` to `term15` arrive;
- a value is the hex digits only. `Colours.qml` prepends the `#` itself, which is why the template asks for `hex_stripped` and not `hex`;
- a key that is absent leaves the shell's built-in default in place, so the template can grow instead of landing complete.

## Verified on Arch, matugen 4.2.0

Rendered against a real wallpaper on the CachyOS VM, end to end, with no errors:

- the role keywords are snake_case, 50 of them. This template uses 49, and every one renders;
- `{{ colors.<role>.default.hex_stripped }}` gives hex without the `#`, which is what the shell wants. Every value in the rendered file is exactly six characters;
- `{{ mode }}` renders `light` or `dark`, so the mode comes from matugen rather than from the command;
- `{{ base16.base00.default.hex_stripped }}` through `base0f` render the 16 `term` colors, so the terminals come from the same run;
- `--import-json-string '{"name":"dynamic","flavour":"default","variant":"tonalspot"}'` makes `{{ name }}`, `{{ flavour }}` and `{{ variant }}` resolve. The command supplies the metadata, matugen supplies the colors;
- the rendered file parses and carries 65 color keys: 49 roles plus 16 terminals.

One correction the run forced: the five `*_paletteKeyColor` roles the shell declares are not in matugen's role list, and nothing in the QML reads them, so the template omits them and they keep their built-in values.

## The palette will look different

Accepted on 2026-09-12 rather than compensated for. Against the same wallpaper and the same scheme
type, matugen's surfaces come out lighter than the current pipeline's and its accents brighter and
more saturated: background `101417` against `0b0f11`, primary `92cef5` against `a6cbe6`. matugen
follows the specification; the CLI post-processes its result.

Reproducing that adjustment, and tuning these roles back inside the template with matugen's filters,
were both considered and rejected: each leaves us maintaining a transform derived by
reverse-engineering someone else's post-processing. The release notes carry the change when it
ships.

## Still open

- the named catalogue, which becomes our own data;
- the command side: who writes the matugen config, where `--config` points, and the table that maps our variant names to matugen's, since `fruitsalad` is `scheme-fruit-salad` there.

The fan-out templates are vendored under `templates/`, with their provenance and the output path each one needs. The palette difference against the current pipeline is measured and accepted; both are recorded in the ticket.

## Two roles are not Material You

`m3success`, `m3onSuccess`, `m3successContainer` and `m3onSuccessContainer` are ours, not the specification's, and matugen has no keyword for them. They are absent from the template on purpose, so the shell keeps its defaults for now. They need a decision: a harmonized green derived from the scheme, or fixed values from `[config.custom_colors]`.

## Trying it

On an Arch box, with a wallpaper to hand:

    matugen image /path/to/wallpaper.jpg --config src/matugen/config.toml --dry-run

`--dry-run` shows the rendered output without writing it. Compare the result against a `scheme.json` produced by the current CLI, role by role, before trusting it. That comparison is still outstanding: the VM has neither the CLI nor the shell installed.
