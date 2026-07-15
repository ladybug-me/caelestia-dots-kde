pragma ComponentBehavior: Bound

import QtQuick
import Caelestia.Config
import qs.components
import qs.components.controls
import qs.services
Item {
    id: root

    // Array of { id: string, label: string, state: "available"|"current"|"past", subject: string }
    required property var entries
    property string selectedId: ""

    signal entryClicked(string entryId, string entryState)

    readonly property int rowHeight: 48
    readonly property int gutterWidth: 32
    readonly property real dotRadius: 5
    readonly property real currentDotRadius: 9

    implicitWidth: 200
    implicitHeight: root.entries.length * root.rowHeight

    // Vertical connector line behind all dots
    Rectangle {
        visible: root.entries.length > 1
        x: root.gutterWidth / 2 - 1
        y: root.rowHeight / 2
        width: 2
        height: Math.max(0, root.entries.length - 1) * root.rowHeight
        color: Colours.palette.m3outlineVariant
        opacity: 0.45
    }

    Repeater {
        model: root.entries

        delegate: Item {
            id: entry

            required property int index
            required property var modelData

            readonly property bool isCurrent: modelData.state === "current"
            readonly property bool isAvailable: modelData.state === "available"
            readonly property bool isPast: modelData.state === "past"
            readonly property bool isSelected: root.selectedId === modelData.id
            readonly property bool isClickable: (isAvailable || isPast) && modelData.id !== "##current##"
            readonly property bool isMerge: !!modelData.isMerge
            readonly property string tooltipText: {
                const author = modelData.author || "";
                const date = modelData.date || "";
                if (author === "" && date === "")
                    return "";
                return author !== "" && date !== "" ? `${author} • ${date}` : (author || date);
            }

            property bool hovered: false

            x: 0
            y: index * root.rowHeight
            width: root.width
            height: root.rowHeight

            // Hover highlight
            Rectangle {
                anchors.fill: parent
                radius: Tokens.rounding.extraSmall
                color: Colours.palette.m3onSurface
                opacity: entry.hovered && entry.isClickable ? 0.07 : 0.0
                Behavior on opacity { NumberAnimation { duration: 100 } }
            }

            // Glow for current version dot
            Rectangle {
                visible: entry.isCurrent
                x: root.gutterWidth / 2 - width / 2
                anchors.verticalCenter: parent.verticalCenter
                width: root.currentDotRadius * 4
                height: width
                radius: width / 2
                color: Colours.palette.m3primary
                opacity: 0.15
            }

            // Selection ring
            Rectangle {
                visible: entry.isSelected
                x: root.gutterWidth / 2 - width / 2
                anchors.verticalCenter: parent.verticalCenter
                width: root.currentDotRadius * 3
                height: width
                radius: width / 2
                color: Colours.palette.m3primary
                opacity: 0.22
            }

            // Dot
            Rectangle {
                id: dot
                readonly property real r: entry.isCurrent ? root.currentDotRadius : root.dotRadius
                x: root.gutterWidth / 2 - r
                anchors.verticalCenter: parent.verticalCenter
                width: r * 2
                height: r * 2
                // Merge commits are rendered as a diamond to stand out from
                // regular commits/versions in the same vertical timeline.
                radius: entry.isMerge ? 2 : r
                rotation: entry.isMerge ? 45 : 0

                color: {
                    if (entry.isCurrent) return Colours.palette.m3primary;
                    if (entry.isSelected) return Colours.palette.m3primary;
                    if (entry.isAvailable) return "transparent";
                    return Colours.palette.m3outlineVariant;
                }
                border.color: (entry.isAvailable && !entry.isSelected) ? Colours.palette.m3primary : "transparent"
                border.width: (entry.isAvailable && !entry.isSelected) ? 2 : 0

                Behavior on color { ColorAnimation { duration: 150 } }
                Behavior on border.color { ColorAnimation { duration: 150 } }
            }

            // Label + subject text
            Column {
                anchors {
                    left: parent.left
                    leftMargin: root.gutterWidth + Tokens.spacing.medium
                    right: parent.right
                    rightMargin: Tokens.padding.medium
                    verticalCenter: parent.verticalCenter
                }
                spacing: 0

                StyledText {
                    width: parent.width
                    text: entry.modelData.label
                    font: entry.isCurrent ? Tokens.font.body.medium : Tokens.font.body.small
                    color: {
                        if (entry.isCurrent || entry.isSelected) return Colours.palette.m3primary;
                        if (entry.isAvailable) return Colours.palette.m3onSurface;
                        return Colours.palette.m3outline;
                    }
                    elide: Text.ElideRight
                    Behavior on color { ColorAnimation { duration: 150 } }
                }

                StyledText {
                    width: parent.width
                    visible: !!entry.modelData.subject
                    text: entry.modelData.subject || ""
                    font: Tokens.font.label.small
                    color: Colours.palette.m3outline
                    elide: Text.ElideRight
                }
            }

            // Interaction layer
            MouseArea {
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: entry.isClickable ? Qt.PointingHandCursor : Qt.ArrowCursor
                onEntered: entry.hovered = true
                onExited: entry.hovered = false
                onClicked: {
                    if (entry.isClickable) {
                        root.entryClicked(entry.modelData.id, entry.modelData.state);
                    }
                }
            }

            // Author/date tooltip - positioned absolutely, doesn't affect layout
            Loader {
                asynchronous: true
                active: entry.tooltipText !== ""
                z: 10000
                sourceComponent: Component {
                    Tooltip {
                        target: entry
                        text: entry.tooltipText
                    }
                }
            }
        }
    }
}
