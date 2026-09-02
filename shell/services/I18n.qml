pragma Singleton
pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Io
import qs.utils

// In-shell UI translation service.
//
// Quickshell has no native QTranslator integration (see quickshell-mirror
// /quickshell#933), so qsTr()-wrapped strings cannot be swapped at runtime by
// Qt itself. This singleton provides a lightweight, JSON-backed alternative:
// every user-facing string is looked up through I18n.tr("English source"),
// which returns the translated form for the currently selected language, or
// the original English when no translation exists (or "system" is chosen).
//
// Translations live in assets/translations/<code>.json as a flat
// { "English source": "Çeviri" } map. Adding a language is just dropping a new
// JSON file and appending an entry to `languages` below — no C++ changes.
Singleton {
    id: root

    // Available UI languages. `code` "system" means: don't translate, follow
    // the original English strings (which themselves fall back to the system
    // locale for dates/numbers via Qt). Each other code maps to a JSON file in
    // assets/translations/<code>.json.
    readonly property var languages: [
        ({ code: "system", name: "System default", nativeName: "System default" }),
        ({ code: "en", name: "English", nativeName: "English" }),
        ({ code: "tr", name: "Turkish", nativeName: "Türkçe" })
    ]

    // Currently selected language code (persisted to language.json).
    property string language: "system"

    // Loaded translation map for the active language ({} when system/en).
    property var translations: ({})

    // Bumped every time the active translation map changes. UI text that binds
    // to I18n.tr(...) also references this so the binding re-evaluates and the
    // whole shell updates live when the language switches.
    property int revision: 0

    // Translate an English source string to the active language. Returns the
    // original string when untranslated so partial translations degrade
    // gracefully and new upstream strings never render blank.
    function tr(source: string): string {
        // Touch revision so callers binding to tr() re-run on language change.
        void root.revision;
        const map = root.translations;
        if (map && map[source] !== undefined && map[source] !== "")
            return map[source];
        return source;
    }

    // Convenience: display name for a language code.
    function nameFor(code: string): string {
        for (let i = 0; i < languages.length; i++)
            if (languages[i].code === code)
                return languages[i].nativeName;
        return code;
    }

    function setLanguage(code: string): void {
        if (code === root.language)
            return;
        root.language = code;
        prefFile.setText(JSON.stringify({ language: code }, null, 2));
        root.reloadTranslations();
    }

    function reloadTranslations(): void {
        if (root.language === "system" || root.language === "en") {
            root.translations = ({});
            root.revision++;
            return;
        }
        translationFile.path = `${Quickshell.shellDir}/assets/translations/${root.language}.json`;
        translationFile.reload();
    }

    function applyTranslations(raw: string): void {
        try {
            root.translations = JSON.parse(raw) || ({});
        } catch (e) {
            root.translations = ({});
        }
        root.revision++;
    }

    Component.onCompleted: root.reloadTranslations()

    // Persisted language preference.
    FileView {
        id: prefFile

        path: `${Paths.config}/language.json`
        watchChanges: true
        onFileChanged: reload()
        onLoaded: {
            try {
                const data = JSON.parse(text());
                if (data && data.language && data.language !== root.language) {
                    root.language = data.language;
                    root.reloadTranslations();
                }
            } catch (e) {
                // keep current selection on parse error
            }
        }
    }

    // Active language's translation map.
    FileView {
        id: translationFile

        watchChanges: true
        onFileChanged: reload()
        onLoaded: root.applyTranslations(text())
        onLoadFailed: {
            // Missing/broken file: fall back to English, don't crash.
            root.translations = ({});
            root.revision++;
        }
    }
}
