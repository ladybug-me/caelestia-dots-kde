# Retire kde-material-you-colors and apply the palette ourselves

The colour pipeline generated its palette with matugen and then handed it to
`kde-material-you-colors`, which themed Plasma, Konsole and pywal from it. That left two
programs writing the same state. KMY derived a palette of its own from the wallpaper it
found by polling Plasma, wrote its own colour scheme files and applied them itself, so a
scheme chosen with `caelestia scheme set` could be undone by its next poll; its reload
workaround, two scheme files applied in sequence, is why System Settings showed duplicate
Material You entries and why every change flickered; and when it got stuck it re-applied
an identical scheme about once a second, which is what `KMYGuard.qml` existed to survive.

We decided that the program which owns the palette owns the apply as well.
`caelestia-color` writes the scheme files and applies them, KMY is neither installed nor
started, and the guard, its Advanced Colors settings page and its sync script are gone.
Where KMY did something we had no equivalent for, Konsole theming is taken over by
rendering its `R,G,B` scheme format from the palette, and the rest is dropped: pywal,
syntax highlighting for Kate and KWrite, icon theme switching, the Klassy and SierraBreeze
tints, the applet, and the hue and chroma knobs that lived on the Advanced Colors page.

The alternative was to keep KMY and coordinate with it, which means one program deciding
when the other may write - and the failure mode of getting that wrong is a desktop that
changes colours on its own. The costs we accepted are the extras listed above, and that an
install which predates this has its KMY unit removed rather than left to fight ours, which
`scripts/10-autostart.sh` does on the next install or update.

Two smaller decisions came with it. Plasma's own accent color is cleared from `kdeglobals`
when the palette is applied, because Plasma rewrites the focus, link and selection colors
from it on top of the scheme it has just been given, which would replace part of the
palette with a colour chosen at some other time. And the palette is applied under two
names, `Matugen` and `Matugen Alt`, because `plasma-apply-colorscheme` does nothing when
handed the scheme already in effect; the duplicate entry in System Settings is the price
of a reload through KDE's own tool rather than one of our own.
