# Translations

The shell UI is translatable through Qt Linguist. Source strings live in the QML
files wrapped in `qsTr()`, the catalogues live in `shell/translations/`, and the
`Translations` singleton loads them at runtime.

English is the source language, so it needs no catalogue. Turkish (`tr`) ships as
the first translation.

## How it fits together

| Piece | Where | What it does |
|-------|-------|--------------|
| Source strings | `shell/**/*.qml` | Anything user-facing is wrapped in `qsTr("...")` |
| Catalogues | `shell/translations/caelestia_<code>.ts` | Qt Linguist XML, one per language |
| Extraction | `scripts/update-translations.sh` | Runs `lupdate` over the shell sources |
| Compilation | `shell/CMakeLists.txt` | Runs `lrelease`, installs `caelestia_<code>.qm` next to the shell |
| Loading | `shell/plugin/src/Caelestia/translations.{hpp,cpp}` | `Translations` singleton, installs a `QTranslator` and retranslates the engine |
| Setting | `general.language` in `shell.json` | `"system"` (default) or a locale code such as `"tr"` |
| UI | Nexus -> Language & region -> Shell language | Writes `general.language` |

Switching languages takes effect immediately - the singleton calls
`QQmlEngine::retranslate()`, so bindings that use `qsTr()` re-evaluate without a
shell restart. Strings a catalogue does not cover fall back to English.

Catalogues are looked up in this order:

1. `$CAELESTIA_TRANSLATIONS_DIR` (colon separated, handy for testing)
2. `<shell>/translations/` next to the running `shell.qml` (repo checkout or install tree)
3. The path baked in at build time (`<INSTALL_QSCONFDIR>/translations`)

## Adding a language

1. Create the catalogue (this also refreshes every existing one):

   ```bash
   scripts/update-translations.sh es
   ```

   `es` is the locale code. Region specific codes work too (`pt_BR`), and the
   loader falls back from `pt_BR` to `pt` when only the bare catalogue exists.

2. Translate `shell/translations/caelestia_es.ts` - with Qt Linguist
   (`linguist6 shell/translations/caelestia_es.ts`) or any text editor. Leave an
   entry untranslated to keep the English text.

3. Rebuild and install the shell:

   ```bash
   bash scripts/08-build-shell.sh
   ```

4. Pick the language in Nexus -> Language & region -> Shell language. It appears
   automatically once the `.qm` file is installed.

Qt's Linguist tools are needed to compile catalogues. The installer and
`caelestia-update` pull them in automatically (`qt6-tools` on Arch,
`qt6-qttools-devel` on Fedora, `qt6-l10n-tools` + `qt6-tools-dev` on Debian).
Without them the build installs the committed `caelestia_<code>.qm` files as
they are, so every language still ships; with them the `.ts` files are
recompiled and take precedence.

## Translating on Crowdin

Translators do not need a checkout. The project is synchronized with Crowdin, so
a language can be worked on in the browser and arrives here as a pull request.

`crowdin.yml` maps the catalogues; `.github/workflows/crowdin.yml` runs the
synchronization on every push to `dev` that touches the shell sources, and can
be triggered by hand.

Two details are worth knowing before touching that setup:

- **The source catalogue is generated, not committed.** Crowdin needs an English
  `.ts` to slice into the target languages, but a file of several thousand empty
  translations does not belong in the repository. The workflow rebuilds
  `caelestia_en.ts` from the QML immediately before uploading and never commits
  it.
- **A Crowdin pull request carries `.ts` files only.** Since a build without
  Linguist tools installs the committed `.qm` as-is, a `.ts` arriving without its
  `.qm` would quietly ship the previous translation. The workflow recompiles them
  on the localization branch so the pair always moves together.

The project lives at <https://crowdin.com/project/caelestia-kde>, and the README
badge reports its progress.

The repository needs two secrets for this, both from a Crowdin account with at
least Manager rights on the project: `CROWDIN_PROJECT_ID` and
`CROWDIN_PERSONAL_TOKEN`. The job is skipped on forks, where they do not exist.

### First run

Crowdin starts empty. A run that only uploads sources and then downloads would
export every target file untranslated and open a pull request replacing the
Turkish catalogue with a blank one, so the committed translations have to be
seeded first: trigger the workflow by hand once with **Also upload the committed
catalogues** enabled. Every run after that leaves it off, so translations edited
in Crowdin are not overwritten by whatever happens to be committed here.

Delete the `i18n/crowdin` branch before seeding if one is already there. The
branch is where the workflow accumulates downloaded translations, and one left
over from an earlier run carries that run's files into the next pull request.

Only languages someone has actually translated are exported
(`skip_untranslated_files`). Without it Crowdin writes a file for every target
language on the project, and a catalogue of nothing but untranslated entries
still compiles and still appears in the language picker as a language that
renders in English.

English must not be added as a target language on the project. It is the source,
so there is nothing to translate into it: Crowdin lists it at 0% forever, and
its export would be named `caelestia_en.ts` -- the generated source catalogue,
which is ignored, so it would be quietly discarded on every run. If the project
shows English (or English, United States) among the target languages, remove it
under Settings -> Languages.

Catalogues are named by the two-letter code, so Turkish is `caelestia_tr.ts`.
Two variants of one language -- `pt-BR` and `pt-PT`, `zh-CN` and `zh-TW` --
would both want the bare code; give them explicit names through
`languages_mapping` in `crowdin.yml` if both are ever translated.

`CROWDIN_PROJECT_ID` is the numeric project ID from Crowdin's project settings,
not the `caelestia-kde` identifier that appears in the URL and the badge.

Create the token under Account Settings -> API with **Granular access**, limited
to this project and to the scopes the synchronization needs. A Crowdin personal
token otherwise carries its owner's permissions across every project they can
reach, and this one lives in a repository whose write access is not the same set
of people -- anyone who can add a workflow can read a secret. Scoping it keeps
that reach to one project.

Adding a language is done in Crowdin's own settings; the catalogue appears here
on the next synchronization. Nothing about the local workflow changes -- a
language added by hand with `update-translations.sh` is picked up by Crowdin on
the next upload just the same.

## Keeping catalogues current

After adding or changing `qsTr()` strings, run:

```bash
scripts/update-translations.sh
```

With no arguments it updates every existing catalogue. New strings land as
`type="unfinished"`, obsolete ones are dropped.

## Writing translatable strings

- Wrap user-facing text in `qsTr()`: `text: qsTr("Wallpapers")`.
- Keep placeholders out of the sentence structure - use `%1` with `.arg()`
  rather than concatenation, so translators can reorder them:

  ```qml
  // Good
  text: qsTr("Saved weather coordinates: %1").arg(coords)
  // Bad
  text: qsTr("Saved weather coordinates: ") + coords
  ```

- Do not translate identifiers: Material Symbol icon names (`text: "search"` on
  a `MaterialIcon`), config keys, class names, or command placeholders like
  `ghp_...`.
- `qsTr()` context is the QML file's base name, so the same English word in two
  files can be translated differently.
