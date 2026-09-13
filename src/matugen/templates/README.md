# Vendored matugen templates

These are the theming templates from [InioX/matugen-themes](https://github.com/InioX/matugen-themes), copied unmodified.

- Source: `https://github.com/InioX/matugen-themes`
- Commit: `707c7b7d3550c9c21c0a8d72186748b1d205b88b`
- Vendored: 2026-09-12
- Licence: MIT, see `LICENSE` beside these files

Do not edit them here. They are upstream files, and a local edit becomes a silent divergence; re-vendor instead, with the file list below and the commit recorded above.

Refresh with:

    git clone --depth 1 https://github.com/InioX/matugen-themes /tmp/mt
    # copy the files named below from /tmp/mt/templates, then update the commit above

## What each one is for

| Template | Target | Output |
| --- | --- | --- |
| `kvantum-colors.kvconfig`, `kvantum-colors.svg` | Kvantum | `~/.config/Kvantum/matugen/matugen.kvconfig` and `.svg` |
| `Matugen.colors` | the KDE and Qt color scheme | `~/.local/share/color-schemes/Matugen.colors` |
| `qtct-colors.conf` | qt5ct and qt6ct | `~/.config/qt5ct/colors/matugen.conf`, same for qt6ct |
| `gtk-colors.css` | GTK 3 and GTK 4 | `~/.config/gtk-3.0/colors.css`, `~/.config/gtk-4.0/colors.css` |
| `terminal-sequences` | every running terminal | `~/.cache/terminal-sequences`, then `tee /dev/pts/[0-9]*` |
| `btop.theme` | btop | `~/.config/btop/themes/matugen.theme` |
| `cava-colors.ini` | cava | `~/.config/cava/themes/matugen` |
| `starship-colors.toml` | starship | merged into `~/.config/starship.toml` |
| `midnight-discord.css` | Vesktop or Equibop | `~/.config/vesktop/themes/midnight-discord.css` |
| `system24.css` | Vesktop or Equibop, the alternative Discord theme | `~/.config/vesktop/themes/system24.css` |
| `spicetify.ini` | Spicetify, Sleek theme | `~/.config/spicetify/Themes/Sleek/color.ini` |
| `vscode-colors`, `vscode-colors.json` | VS Code and VSCodium, with the Matugen Theme extension | `~/.cache/matugen/vscode-colors` and `.json` |
| `zed-colors.json` | Zed | `~/.config/zed/themes/matugen.json` |
| `papirus-color` | Papirus folder icons | feeds `papirus-folders -C {{ closest_color }}` from a post hook |
| `rofi-colors.rasi` | rofi | `~/.config/rofi/colors.rasi` |
| `fuzzel.ini` | fuzzel | `~/.config/fuzzel/colors.ini` |
| `foot-colors.ini` | foot | `~/.config/foot/foot-colors.ini` |
| `kitty-colors.conf` | kitty | `~/.config/kitty/themes/Matugen.conf` |

Each of these also needs a `[templates.<name>]` block with its `input_path`, `output_path` and any `post_hook` that makes the running application pick the file up. That wiring is the command's job, and it is the next piece of work on the ticket.
