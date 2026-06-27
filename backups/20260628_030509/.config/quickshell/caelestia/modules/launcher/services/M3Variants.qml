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
        const cmd = `import json\nfrom caelestia.utils.scheme import get_scheme\nscheme = get_scheme()\nscheme.variant = "${variant}"\nscheme.update_colours()\nprint(json.dumps({"name": scheme.name, "flavour": scheme.flavour, "mode": scheme.mode, "variant": scheme.variant, "colours": scheme.colours}))`;
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
            name: qsTr("Vibrant")
            description: qsTr("A high chroma palette. The primary palette's chroma is at maximum.")
        },
        Variant {
            variant: "tonalspot"
            icon: "android"
            name: qsTr("Tonal Spot")
            description: qsTr("Default for Material theme colours. A pastel palette with a low chroma.")
        },
        Variant {
            variant: "expressive"
            icon: "compare_arrows"
            name: qsTr("Expressive")
            description: qsTr("A medium chroma palette. The primary palette's hue is different from the seed colour, for variety.")
        },
        Variant {
            variant: "fidelity"
            icon: "compare"
            name: qsTr("Fidelity")
            description: qsTr("Matches the seed colour, even if the seed colour is very bright (high chroma).")
        },
        Variant {
            variant: "content"
            icon: "sentiment_calm"
            name: qsTr("Content")
            description: qsTr("Almost identical to fidelity.")
        },
        Variant {
            variant: "fruitsalad"
            icon: "nutrition"
            name: qsTr("Fruit Salad")
            description: qsTr("A playful theme - the seed colour's hue does not appear in the theme.")
        },
        Variant {
            variant: "rainbow"
            icon: "looks"
            name: qsTr("Rainbow")
            description: qsTr("A playful theme - the seed colour's hue does not appear in the theme.")
        },
        Variant {
            variant: "neutral"
            icon: "contrast"
            name: qsTr("Neutral")
            description: qsTr("Close to grayscale, a hint of chroma.")
        },
        Variant {
            variant: "monochrome"
            icon: "filter_b_and_w"
            name: qsTr("Monochrome")
            description: qsTr("All colours are grayscale, no chroma.")
        }
    ]
    useFuzzy: GlobalConfig.launcher.useFuzzy.variants

    component Variant: QtObject {
        required property string variant
        required property string icon
        required property string name
        required property string description

        function onClicked(list: AppList): void {
            list.visibilities.launcher = false;
            Quickshell.execDetached(["caelestia", "scheme", "set", "-v", variant]);
        }
    }
}
