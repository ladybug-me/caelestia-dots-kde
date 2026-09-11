# Catalogues

`caelestia_<code>.ts` files are Qt Linguist catalogues for the shell UI. English
is the source language and needs no catalogue of its own; a new one is generated
from the sources by the script below.

`caelestia_<code>.qm` next to each source is the compiled catalogue, committed
so that a build without Qt's Linguist tools still ships every language rather
than silently falling back to English. The script below recompiles it; do not
edit it by hand.

Refresh them after changing `qsTr()` strings, or start a new language:

```bash
scripts/update-translations.sh          # update every catalogue here
scripts/update-translations.sh es       # add Spanish
```

Translations are also synchronized with Crowdin, so a language can be worked on
in the browser instead; it arrives here as a pull request.

See [../../docs/translations.md](../../docs/translations.md) for
the full guide.
