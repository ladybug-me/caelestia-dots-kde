pragma Singleton

import ".."
import QtQuick
import Quickshell
import Quickshell.Io
import Caelestia.Config
import qs.services
import qs.utils

Searcher {
    id: root

    function transformSearch(search: string): string {
        return search.slice(`${GlobalConfig.launcher.actionPrefix}variant `.length);
    }

    function previewVariant(variant: string): void {
        const cmd = `import json\nfrom caelestia.utils.scheme import get_scheme\nscheme = get_scheme()\nscheme._variant = "${variant}"\nscheme._update_colours()\nprint(json.dumps({"name": scheme.name, "flavour": scheme.flavour, "mode": scheme.mode, "variant": scheme.variant, "colours": scheme.colours}))`;
        getPreviewColoursProc.command = ["python3", "-c", cmd];
        getPreviewColoursProc.running = true;
    }

    Process {
        id: getPreviewColoursProc

        stdout: StdioCollector {
            onStreamFinished: {
                Colours.load(text, true);
                Colours.showPreview = true;
            }
        }
    }

    list: [
        Variant {
            variant: "vibrant"
            icon: "sentiment_very_dissatisfied"
            name: I18n.tr("Vibrant")
            description: I18n.tr("A high chroma palette. The primary palette's chroma is at maximum.")
        },
        Variant {
            variant: "tonalspot"
            icon: "android"
            name: I18n.tr("Tonal Spot")
            description: Strings.localizeEnglishSpelling(I18n.tr("Default for Material theme colours. A pastel palette with a low chroma."))
        },
        Variant {
            variant: "expressive"
            icon: "compare_arrows"
            name: I18n.tr("Expressive")
            description: Strings.localizeEnglishSpelling(I18n.tr("A medium chroma palette. The primary palette's hue is different from the seed colour, for variety."))
        },
        Variant {
            variant: "fidelity"
            icon: "compare"
            name: I18n.tr("Fidelity")
            description: Strings.localizeEnglishSpelling(I18n.tr("Matches the seed colour, even if the seed colour is very bright (high chroma)."))
        },
        Variant {
            variant: "content"
            icon: "sentiment_calm"
            name: I18n.tr("Content")
            description: I18n.tr("Almost identical to fidelity.")
        },
        Variant {
            variant: "fruitsalad"
            icon: "nutrition"
            name: I18n.tr("Fruit Salad")
            description: Strings.localizeEnglishSpelling(I18n.tr("A playful theme - the seed colour's hue does not appear in the theme."))
        },
        Variant {
            variant: "rainbow"
            icon: "looks"
            name: I18n.tr("Rainbow")
            description: Strings.localizeEnglishSpelling(I18n.tr("A playful theme - the seed colour's hue does not appear in the theme."))
        },
        Variant {
            variant: "neutral"
            icon: "contrast"
            name: I18n.tr("Neutral")
            description: I18n.tr("Close to grayscale, a hint of chroma.")
        },
        Variant {
            variant: "monochrome"
            icon: "filter_b_and_w"
            name: I18n.tr("Monochrome")
            description: Strings.localizeEnglishSpelling(I18n.tr("All colours are grayscale, no chroma."))
        }
    ]

    useFuzzy: GlobalConfig.launcher.useFuzzy.variants

    component Variant: QtObject {
        required property string variant
        required property string icon
        required property string name
        required property string description

        function onClicked(list: var): void {
            if (list) {
                list.visibilities.launcher = false;
            }
            Quickshell.execDetached(["caelestia", "scheme", "set", "-v", variant]);
        }
    }
}
