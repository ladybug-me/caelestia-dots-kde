pragma Singleton
pragma ComponentBehavior: Bound

import ".."
import QtQuick
import Quickshell
import Caelestia.Config
import Caelestia.Services
import qs.utils

Searcher {
    id: root

    property string currentScheme: SchemeLoader.currentScheme
    property string currentVariant: SchemeLoader.currentVariant

    function transformSearch(search: string): string {
        return search.slice(`${GlobalConfig.launcher.actionPrefix}scheme `.length);
    }

    function selector(item: var): string {
        return `${item.name} ${item.flavour}`;
    }

    function reload(): void {
        SchemeLoader.reloadCurrent();
    }

    list: schemes.instances
    useFuzzy: GlobalConfig.launcher.useFuzzy.schemes
    keys: ["name", "flavour"]
    weights: [0.9, 0.1]

    Variants {
        id: schemes
        model: SchemeLoader.schemes
        
        Scheme {}
    }

    component Scheme: QtObject {
        required property var modelData
        readonly property string name: modelData.name
        readonly property string flavour: modelData.flavour
        readonly property var colours: modelData.colours

        function onClicked(list: var): void {
            if (list) {
                list.visibilities.launcher = false;
            }
            Quickshell.execDetached(["caelestia", "scheme", "set", "-n", name, "-f", flavour]);
        }
    }
}
