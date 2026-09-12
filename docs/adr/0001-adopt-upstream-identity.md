# Adopt upstream's identity instead of inventing a port identity

This repo is a KDE Plasma port of `caelestia-dots/shell`, but it had invented its
own product nouns (`Caelestia KDE`, `Caelestia KWin Port`), shipped four unrelated
palettes, rendered its name in three different ASCII fonts, and opened with a
marketing paragraph that framed the port as its own project rather than as
Caelestia running on Plasma. We decided to adopt upstream's identity wholesale:
one name (Caelestia, lowercase in identifiers), one palette (the `caelestia`
scheme), one logo, upstream's terse README voice, and no port-specific product
name anywhere. The rules are in [brand.md](../brand.md).

The alternative was a distinct port identity with its own name and colours, which
would have read as a separate project and turned every future upstream sync into
a translation exercise. The cost we accepted is that the repo's own name no
longer says "KDE"; the README states the port relationship once instead.
