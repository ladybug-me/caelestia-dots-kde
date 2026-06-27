pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Caelestia.Config
import qs.components
import qs.components.containers
import qs.components.controls
import qs.services
import qs.modules.launcher.items
import qs.modules.launcher.services

StyledListView {
    id: root

    required property StyledTextField search
    required property DrawerVisibilities visibilities

    model: ScriptModel {
        id: model

        onValuesChanged: root.currentIndex = 0
    }

    spacing: Tokens.spacing.small
    orientation: Qt.Vertical
    implicitHeight: Math.max(0, (Tokens.sizes.launcher.itemHeight + spacing) * Math.min(Config.launcher.maxShown, count) - spacing)

    preferredHighlightBegin: 0
    preferredHighlightEnd: height
    highlightRangeMode: ListView.ApplyRange

    highlightFollowsCurrentItem: false
    highlight: StyledRect {
        radius: Tokens.rounding.large
        color: Colours.palette.m3onSurface
        opacity: 0.08

        y: root.currentItem?.y ?? 0
        implicitWidth: root.width
        implicitHeight: root.currentItem?.implicitHeight ?? 0

        Behavior on y {
            Anim {}
        }
    }

    state: {
        const text = search.text;
        const prefix = GlobalConfig.launcher.actionPrefix;
        if (text.startsWith(prefix)) {
            const actionPrefixes = ["calc", "scheme", "variant", "emoji", "clipboard", "windows"];
            for (const action of actionPrefixes)
                if (text.startsWith(`${prefix}${action} `))
                    return action;

            return "actions";
        }

        return "apps";
    }

    onStateChanged: {
        if (state === "scheme" || state === "variant")
            Schemes.reload();
        if (state === "emoji")
            Emojis.reload();
        if (state === "clipboard")
            Clipboard.reload();
            
        if (state !== "scheme" && state !== "variant") {
            Colours.showPreview = false;
        }
    }

    onCurrentItemChanged: {
        if (state === "scheme" || state === "variant") {
            if (currentItem && currentItem.modelData)
                previewTimer.restart();
        }
    }

    Component.onDestruction: {
        Colours.showPreview = false;
    }

    Timer {
        id: previewTimer
        interval: 100
        onTriggered: {
            if (!root.currentItem || !root.currentItem.modelData) return;
            if (root.state === "scheme") {
                const schemeData = root.currentItem.modelData;
                Colours.load(JSON.stringify({ name: schemeData.name, flavour: schemeData.flavour, variant: Colours.variant, mode: Colours.light ? "light" : "dark", colours: schemeData.colours }), true);
                Colours.showPreview = true;
            } else if (root.state === "variant") {
                const variantData = root.currentItem.modelData;
                M3Variants.previewVariant(variantData.variant);
            }
        }
    }

    states: [
        State {
            name: "apps"

            PropertyChanges {
                target: model
                values: Apps.search(search.text)
            }
            PropertyChanges {
                target: root
                delegate: appItem
            }
        },
        State {
            name: "actions"

            PropertyChanges {
                target: model
                values: Actions.query(search.text)
            }
            PropertyChanges {
                target: root
                delegate: actionItem
            }
        },
        State {
            name: "calc"

            PropertyChanges {
                target: model
                values: [0]
            }
            PropertyChanges {
                target: root
                delegate: calcItem
            }
        },
        State {
            name: "scheme"

            PropertyChanges {
                target: model
                values: Schemes.query(search.text)
            }
            PropertyChanges {
                target: root
                delegate: schemeItem
            }
        },
        State {
            name: "variant"

            PropertyChanges {
                target: model
                values: M3Variants.query(search.text)
            }
            PropertyChanges {
                target: root
                delegate: variantItem
            }
        },
        State {
            name: "emoji"

            PropertyChanges {
                target: model
                values: {
                    const prefix = GlobalConfig.launcher.actionPrefix;
                    const text = root.search.text.slice((prefix + "emoji ").length).toLowerCase();
                    if (!text)
                        return Emojis.getSortedItems();
                    return Emojis.items.filter(function (item) {
                        return item.name.toLowerCase().includes(text);
                    });
                }
            }
            PropertyChanges {
                target: root
                delegate: emojiItem
            }
        },
        State {
            name: "clipboard"

            PropertyChanges {
                target: model
                values: {
                    const prefix = GlobalConfig.launcher.actionPrefix;
                    const text = root.search.text.slice((prefix + "clipboard ").length).toLowerCase();
                    if (!text)
                        return Clipboard.getSortedItems();
                    return Clipboard.items.filter(function (item) {
                        return item.preview.toLowerCase().includes(text);
                    });
                }
            }
            PropertyChanges {
                target: root
                delegate: clipItem
            }
        },
        State {
            name: "windows"

            PropertyChanges {
                target: model
                values: Windows.items
            }
            PropertyChanges {
                target: root
                delegate: windowsItem
            }
        }
    ]

    transitions: Transition {
        SequentialAnimation {
            ParallelAnimation {
                Anim {
                    target: root
                    property: "opacity"
                    from: 1
                    to: 0
                    duration: Tokens.anim.durations.small
                    easing: Tokens.anim.standardAccel
                }
                Anim {
                    target: root
                    property: "scale"
                    from: 1
                    to: 0.9
                    duration: Tokens.anim.durations.small
                    easing: Tokens.anim.standardAccel
                }
            }
            PropertyAction {
                targets: [model, root]
                properties: "values,delegate"
            }
            ParallelAnimation {
                Anim {
                    target: root
                    property: "opacity"
                    from: 0
                    to: 1
                    duration: Tokens.anim.durations.small
                    easing: Tokens.anim.standardDecel
                }
                Anim {
                    target: root
                    property: "scale"
                    from: 0.9
                    to: 1
                    duration: Tokens.anim.durations.small
                    easing: Tokens.anim.standardDecel
                }
            }
            PropertyAction {
                targets: [root.add, root.remove]
                property: "enabled"
                value: true
            }
        }
    }

    StyledScrollBar.vertical: StyledScrollBar {
        flickable: root
    }

    add: Transition {
        enabled: !root.state

        Anim {
            type: Anim.DefaultEffects
            property: "opacity"
            from: 0
            to: 1
        }
    }

    remove: Transition {
        enabled: !root.state

        Anim {
            type: Anim.DefaultEffects
            property: "opacity"
            from: 1
            to: 0
        }
    }

    move: Transition {
        Anim {
            property: "y"
        }
        Anim {
            type: Anim.DefaultEffects
            property: "opacity"
            to: 1
        }
    }

    addDisplaced: Transition {
        Anim {
            property: "y"
            type: Anim.StandardSmall
        }
        Anim {
            type: Anim.DefaultEffects
            property: "opacity"
            to: 1
        }
    }

    displaced: Transition {
        Anim {
            property: "y"
        }
        Anim {
            type: Anim.DefaultEffects
            property: "opacity"
            to: 1
        }
    }

    Component {
        id: appItem

        AppItem {
            visibilities: root.visibilities
        }
    }

    Component {
        id: actionItem

        ActionItem {
            list: root
        }
    }

    Component {
        id: calcItem

        CalcItem {
            list: root
        }
    }

    Component {
        id: schemeItem

        SchemeItem {
            list: root
        }
    }

    Component {
        id: variantItem

        VariantItem {
            list: root
        }
    }

    Component {
        id: emojiItem

        EmojiItem {
            list: root
        }
    }

    Component {
        id: clipItem

        ClipItem {
            list: root
        }
    }

    Component {
        id: windowsItem

        WindowSwitcherItem {
            list: root
        }
    }
}
