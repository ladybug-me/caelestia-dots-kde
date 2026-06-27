pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Quickshell
import Quickshell.Widgets
import Caelestia.Config
import qs.components
import qs.services

StackView {
    id: root

    required property PopoutState popouts
    required property QsMenuHandle trayItem

    implicitWidth: currentItem?.implicitWidth ?? 0
    implicitHeight: currentItem?.implicitHeight ?? 0

    initialItem: SubMenu {
        handle: root.trayItem
    }

    pushEnter: NoAnim {}
    pushExit: NoAnim {}
    popEnter: NoAnim {}
    popExit: NoAnim {}

    Component {
        id: subMenuComp

        SubMenu {}
    }

    component NoAnim: Transition {
        NumberAnimation {
            duration: 0
        }
    }

    component SubMenu: Column {
        id: menu

        required property QsMenuHandle handle
        property bool isSubMenu
        property bool shown

        padding: Tokens.padding.small
        spacing: Tokens.spacing.small

        opacity: shown ? 1 : 0
        scale: shown ? 1 : 0.8

        Component.onCompleted: shown = true
        StackView.onActivating: shown = true
        StackView.onDeactivating: shown = false
        StackView.onRemoved: destroy()

        Behavior on opacity {
            Anim {
                type: Anim.DefaultEffects
            }
        }

        Behavior on scale {
            Anim {}
        }

        QsMenuOpener {
            id: menuOpener
            menu: menu.handle
        }

        property var itemGroups: []

        function updateGroups() {
            let groups = [];
            let currentGroup = [];
            for (let i = 0; i < groupInstantiator.count; ++i) {
                let obj = groupInstantiator.objectAt(i);
                if (obj && obj.isSeparator) {
                    if (currentGroup.length > 0) {
                        groups.push(currentGroup);
                        currentGroup = [];
                    }
                } else if (obj) {
                    currentGroup.push(obj.entry);
                }
            }
            if (currentGroup.length > 0) {
                groups.push(currentGroup);
            }
            itemGroups = groups;
        }

        Instantiator {
            id: groupInstantiator
            model: menuOpener.children
            
            Item {
                required property QsMenuEntry modelData
                property bool isSeparator: modelData.isSeparator
                property var entry: modelData
            }

            onObjectAdded: menu.updateGroups()
            onObjectRemoved: menu.updateGroups()
            // In case the model itself changes completely
            onModelChanged: menu.updateGroups()
        }

        Repeater {
            model: menu.itemGroups

            StyledRect {
                id: groupCard

                required property var modelData

                implicitWidth: Tokens.sizes.bar.trayMenuWidth + Tokens.padding.medium * 2
                implicitHeight: groupLayout.implicitHeight + Tokens.padding.medium * 2

                radius: Tokens.rounding.medium
                color: Colours.tPalette.m3surfaceContainer
                clip: true

                Column {
                    id: groupLayout

                    x: Tokens.padding.medium
                    y: Tokens.padding.medium
                    width: parent.width - Tokens.padding.medium * 2
                    spacing: Tokens.spacing.small

                    Repeater {
                        model: groupCard.modelData

                        StyledRect {
                            id: item

                            required property var modelData

                            implicitWidth: parent.width
                            implicitHeight: childrenItem.implicitHeight

                            radius: Tokens.rounding.full
                            color: "transparent"

                            Loader {
                                id: childrenItem

                                asynchronous: true
                                anchors.left: parent.left
                                anchors.right: parent.right

                                sourceComponent: Item {
                                    implicitHeight: label.implicitHeight

                                    StateLayer {
                                        anchors.margins: -Tokens.padding.extraSmall / 2
                                        anchors.leftMargin: -Tokens.padding.small
                                        anchors.rightMargin: -Tokens.padding.small

                                        radius: item.radius
                                        disabled: !item.modelData.enabled

                                        onClicked: {
                                            const entry = item.modelData;
                                            if (entry.hasChildren)
                                                root.push(subMenuComp.createObject(null, {
                                                    handle: entry,
                                                    isSubMenu: true
                                                }));
                                            else {
                                                item.modelData.triggered();
                                                root.popouts.hasCurrent = false;
                                            }
                                        }
                                    }

                                    Loader {
                                        id: icon

                                        asynchronous: true
                                        anchors.left: parent.left

                                        active: item.modelData.icon !== ""

                                        sourceComponent: IconImage {
                                            asynchronous: true
                                            implicitSize: label.implicitHeight

                                            source: item.modelData.icon
                                        }
                                    }

                                    StyledText {
                                        id: label

                                        anchors.left: icon.right
                                        anchors.leftMargin: icon.active ? Tokens.spacing.medium : 0

                                        text: labelMetrics.elidedText
                                        color: item.modelData.enabled ? Colours.palette.m3onSurface : Colours.palette.m3outline
                                    }

                                    property int trayMenuWidth: Tokens.sizes.bar.trayMenuWidth
                                    TextMetrics {
                                        id: labelMetrics

                                        text: item.modelData.text
                                        font: label.font

                                        elide: Text.ElideRight
                                        elideWidth: root.popouts.isHorizontal ? trayMenuWidth - (icon.active ? icon.implicitWidth + label.anchors.leftMargin : 0) - (expand.active ? expand.implicitWidth + Tokens.spacing.medium : 0) : 200
                                    }

                                    Loader {
                                        id: expand

                                        asynchronous: true
                                        anchors.verticalCenter: parent.verticalCenter
                                        anchors.right: parent.right

                                        active: item.modelData.hasChildren

                                        sourceComponent: MaterialIcon {
                                            text: "chevron_right"
                                            color: item.modelData.enabled ? Colours.palette.m3onSurface : Colours.palette.m3outline
                                        }
                                    }
                                }
                            }
                        }
                    }
                }
            }
        }

        Loader {
            asynchronous: true
            active: menu.isSubMenu

            sourceComponent: Item {
                implicitWidth: back.implicitWidth
                implicitHeight: back.implicitHeight + Tokens.spacing.extraSmall

                Item {
                    anchors.bottom: parent.bottom
                    implicitWidth: back.implicitWidth
                    implicitHeight: back.implicitHeight

                    StyledRect {
                        anchors.fill: parent
                        anchors.margins: -Tokens.padding.extraSmall / 2
                        anchors.leftMargin: -Tokens.padding.small
                        anchors.rightMargin: -Tokens.padding.large

                        radius: Tokens.rounding.full
                        color: Colours.palette.m3secondaryContainer

                        StateLayer {
                            radius: parent.radius
                            color: Colours.palette.m3onSecondaryContainer
                            onClicked: root.pop()
                        }
                    }

                    Row {
                        id: back

                        anchors.verticalCenter: parent.verticalCenter

                        MaterialIcon {
                            anchors.verticalCenter: parent.verticalCenter
                            text: "chevron_left"
                            color: Colours.palette.m3onSecondaryContainer
                        }

                        StyledText {
                            anchors.verticalCenter: parent.verticalCenter
                            text: qsTr("Back")
                            color: Colours.palette.m3onSecondaryContainer
                        }
                    }
                }
            }
        }
    }
}
