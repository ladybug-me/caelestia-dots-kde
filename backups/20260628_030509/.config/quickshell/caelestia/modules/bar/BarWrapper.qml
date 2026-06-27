pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Controls
import Quickshell
import Caelestia.Config
import qs.components
import qs.components.controls
import qs.utils
import qs.modules.bar.popouts as BarPopouts

Item {
    id: root

    required property ShellScreen screen
    required property DrawerVisibilities visibilities
    required property BarPopouts.Wrapper popouts
    required property bool fullscreen

    Config.screen: screen.name

    readonly property bool disabled: Strings.testRegexList(Config.bar.excludedScreens, screen.name)
    readonly property string position: Config.bar.position

    readonly property int padding: Math.max(Tokens.padding.small, Config.border.thickness)
    readonly property int contentWidth: Tokens.sizes.bar.innerWidth + padding * 2
    readonly property int exclusiveZone: !disabled && (Config.bar.persistent || visibilities.bar) ? contentWidth : Config.border.thickness
    readonly property bool shouldBeVisible: !fullscreen && !disabled && (Config.bar.persistent || visibilities.bar || isHovered)
    property bool isHovered

    readonly property bool isHorizontal: Config.bar.position === "top" || Config.bar.position === "bottom"
    readonly property int clampedThickness: Math.max(Config.border.minThickness, isHorizontal ? implicitHeight : implicitWidth)
    readonly property int clampedWidth: isHorizontal ? root.width : clampedThickness
    readonly property int clampedHeight: isHorizontal ? clampedThickness : root.height

    function closeTray(): void {
        (content.item as Bar)?.closeTray();
    }

    function checkPopout(y: real): void {
        (content.item as Bar)?.checkPopout(y);
    }

    function handleWheel(y: real, angleDelta: point): void {
        (content.item as Bar)?.handleWheel(y, angleDelta);
    }

    clip: true
    visible: isHorizontal ? height > Config.border.thickness : width > Config.border.thickness
    implicitWidth: isHorizontal ? 0 : (fullscreen ? 0 : Config.border.thickness)
    implicitHeight: isHorizontal ? (fullscreen ? 0 : Config.border.thickness) : 0

    states: State {
        name: "visible"
        when: root.shouldBeVisible

        PropertyChanges {
            target: root
            implicitWidth: root.isHorizontal ? 0 : root.contentWidth
            implicitHeight: root.isHorizontal ? root.contentWidth : 0
        }
    }

    transitions: [
        Transition {
            from: ""
            to: "visible"

            Anim {
                target: root
                property: root.isHorizontal ? "implicitHeight" : "implicitWidth"
                type: Anim.DefaultSpatial
            }
        },
        Transition {
            from: "visible"
            to: ""

            Anim {
                target: root
                property: root.isHorizontal ? "implicitHeight" : "implicitWidth"
                type: Anim.Emphasized
            }
        }
    ]

    Component {
        id: horizontalBar

        Bar {
            anchors.fill: parent
            anchors.leftMargin: root.padding
            anchors.rightMargin: root.padding
            width: root.contentWidth
            screen: root.screen
            visibilities: root.visibilities
            popouts: root.popouts // qmllint disable incompatible-type
            fullscreen: root.fullscreen
        }
    }

    Component {
        id: verticalBar

        Bar {
            anchors.fill: parent
            anchors.topMargin: root.padding
            anchors.bottomMargin: root.padding
            screen: root.screen
            visibilities: root.visibilities
            popouts: root.popouts // qmllint disable incompatible-type
            fullscreen: root.fullscreen
        }
    }

    Loader {
        id: content

        active: root.shouldBeVisible || root.visible
        sourceComponent: root.isHorizontal ? horizontalBar : verticalBar

        width: root.isHorizontal ? root.width : root.contentWidth
        height: root.isHorizontal ? root.contentWidth : root.height

        states: [
            State {
                name: "left"
                Config.screen: root.screen.name
                when: Config.bar.position === "left"

                AnchorChanges {
                    target: content
                    anchors.left: undefined
                    anchors.right: parent.right
                    anchors.top: parent.top
                    anchors.bottom: undefined
                }
            },
            State {
                name: "right"
                Config.screen: root.screen.name
                when: Config.bar.position === "right"

                AnchorChanges {
                    target: content
                    anchors.left: parent.left
                    anchors.right: undefined
                    anchors.top: parent.top
                    anchors.bottom: undefined
                }
            },
            State {
                name: "top"
                Config.screen: root.screen.name
                when: Config.bar.position === "top"

                AnchorChanges {
                    target: content
                    anchors.left: parent.left
                    anchors.right: undefined
                    anchors.top: undefined
                    anchors.bottom: parent.bottom
                }
            },
            State {
                name: "bottom"
                Config.screen: root.screen.name
                when: Config.bar.position === "bottom"

                AnchorChanges {
                    target: content
                    anchors.left: parent.left
                    anchors.right: undefined
                    anchors.top: parent.top
                    anchors.bottom: undefined
                }
            }
        ]
    }
}
