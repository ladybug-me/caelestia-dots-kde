pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import Caelestia.Config
import qs.components
import qs.components.controls
import qs.services

Item {
    id: root

    // Array of { id: string, label: string, state: "available"|"current"|"past", subject: string,
    //            author?: string, date?: string, isMerge?: bool, isRelease?: bool }
    required property var entries
    property string selectedId: ""

    signal entryClicked(string entryId, string entryState)

    // Commit rows (dev branch) carry an author/subject/type chip and need
    // extra vertical room; plain release rows (main branch) stay compact so
    // the two channels remain visually distinct at a glance.
    readonly property bool richMode: root.entries.some(e => !e.isRelease && (!!e.author || !!e.subject))

    readonly property int rowHeight: root.richMode ? 68 : 44

    readonly property int gutterWidth: 32

    readonly property real dotRadius: root.richMode ? 6 : 5

    readonly property real currentDotRadius: 10

    // Conventional-commit prefix → { label, colour } lookup. Gives the dev
    // timeline a colourful, git-log-style look while keeping the mapping
    // grounded in the current Material palette (so it follows theming).
    readonly property var commitTypes: ({
        feat: { label: I18n.tr("feat"), color: Colours.palette.m3primary },
        fix: { label: I18n.tr("fix"), color: Colours.palette.m3error },
        perf: { label: I18n.tr("perf"), color: Colours.palette.m3secondaryFixedDim },
        refactor: { label: I18n.tr("refactor"), color: Colours.palette.m3secondary },
        style: { label: I18n.tr("style"), color: Colours.palette.m3tertiaryFixedDim },
        docs: { label: I18n.tr("docs"), color: Colours.palette.m3tertiary },
        test: { label: I18n.tr("test"), color: Colours.palette.m3primaryFixedDim },
        build: { label: I18n.tr("build"), color: Colours.palette.m3outline },
        ci: { label: I18n.tr("ci"), color: Colours.palette.m3outline },
        chore: { label: I18n.tr("chore"), color: Colours.palette.m3outline },
        revert: { label: I18n.tr("revert"), color: Colours.palette.m3error }
    })

    function commitType(subject) {
        const match = /^(\w+)(\([^)]*\))?!?:\s*/.exec(subject || "");
        if (!match)
            return null;
        return root.commitTypes[match[1].toLowerCase()] || null;
    }

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
        opacity: 0.6
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
            readonly property bool isRelease: !!modelData.isRelease
            // Conventional-commit prefix (feat/fix/…) parsed from the subject —
            // null for merges, releases, or subjects that don't follow the
            // convention, in which case the dot falls back to a neutral tone.
            readonly property var typeInfo: (!isRelease && !isMerge) ? root.commitType(modelData.subject) : null
            readonly property color typeColor: {
                if (isMerge) return Colours.palette.m3secondaryFixedDim;
                if (typeInfo) return typeInfo.color;
                return Colours.palette.m3outlineVariant;
            }
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

                // Fill colour stays a fixed, opaque hue per state/type; the
                // "hollow" look for available dots is done via opacity
                // (not by switching the color to "transparent") to avoid
                // animating through a black-looking transient frame.
                color: {
                    if (entry.isCurrent || entry.isSelected) return Colours.palette.m3primary;
                    // Past commits stay tinted by their commit type so the dev
                    // timeline reads as a colourful git log; plain releases
                    // (main branch) keep the original neutral tone.
                    return entry.isRelease ? Colours.palette.m3outlineVariant : entry.typeColor;
                }
                opacity: (entry.isAvailable && !entry.isSelected) ? 0 : (entry.isPast && !entry.isRelease ? 0.85 : 1)
                border.color: {
                    if (!entry.isAvailable || entry.isSelected) return "transparent";
                    return entry.isRelease ? Colours.palette.m3primary : entry.typeColor;
                }
                border.width: (entry.isAvailable && !entry.isSelected) ? 2 : 0

                Behavior on color { ColorAnimation { duration: 150 } }
                Behavior on opacity { NumberAnimation { duration: 150 } }
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
                spacing: 2

                RowLayout {
                    width: parent.width
                    spacing: Tokens.spacing.extraSmall

                    // Tag icon marks release rows so the main-branch timeline
                    // reads distinctly from the colourful dev commit log.
                    MaterialIcon {
                        visible: entry.isRelease
                        fontStyle: Tokens.font.icon.small
                        text: "sell"
                        color: (entry.isCurrent || entry.isSelected) ? Colours.palette.m3primary : Colours.palette.m3onSurfaceVariant
                    }

                    StyledText {
                        Layout.fillWidth: true
                        text: entry.modelData.label
                        font: entry.isCurrent ? Tokens.font.body.medium : Tokens.font.body.small
                        // Colour-code the hash/label itself by commit type
                        // (not just the small dot) so the dev timeline reads
                        // as an unmistakably colourful git log at a glance.
                        // Releases (main branch) stay neutral to keep that
                        // channel visually plain/compact by contrast.
                        color: {
                            if (entry.isCurrent || entry.isSelected) return Colours.palette.m3primary;
                            if (entry.isRelease) return entry.isAvailable ? Colours.palette.m3onSurface : Colours.palette.m3outline;
                            return entry.typeColor;
                        }
                        elide: Text.ElideRight

                        Behavior on color { ColorAnimation { duration: 150 } }
                    }

                    // Conventional-commit type chip (feat/fix/chore/…) — quick
                    // visual classification without reading the full subject.
                    StyledRect {
                        visible: entry.typeInfo !== null
                        Layout.alignment: Qt.AlignVCenter
                        color: Qt.alpha(entry.typeColor, 0.22)
                        radius: Tokens.rounding.full
                        implicitWidth: chipText.implicitWidth + Tokens.padding.small * 2
                        implicitHeight: chipText.implicitHeight + Tokens.padding.extraSmall

                        StyledText {
                            id: chipText

                            anchors.centerIn: parent
                            text: entry.typeInfo ? entry.typeInfo.label : ""
                            font: Tokens.font.label.small
                            color: entry.typeColor
                        }
                    }

                    // Merge badge — merges don't carry a conventional-commit
                    // prefix of their own, so they get a dedicated chip.
                    StyledRect {
                        visible: entry.isMerge
                        Layout.alignment: Qt.AlignVCenter
                        color: Qt.alpha(entry.typeColor, 0.18)
                        radius: Tokens.rounding.full
                        implicitWidth: mergeText.implicitWidth + Tokens.padding.small * 2
                        implicitHeight: mergeText.implicitHeight + Tokens.padding.extraSmall

                        StyledText {
                            id: mergeText

                            anchors.centerIn: parent
                            text: I18n.tr("merge")
                            font: Tokens.font.label.small
                            color: entry.typeColor
                        }
                    }
                }

                StyledText {
                    width: parent.width
                    visible: !!entry.modelData.subject
                    text: entry.modelData.subject || ""
                    font: Tokens.font.label.small
                    color: Colours.palette.m3onSurfaceVariant
                    elide: Text.ElideRight
                }

                // Author • date — always visible now instead of hover-only,
                // so the dev timeline reads like a real git log at a glance.
                StyledText {
                    width: parent.width
                    visible: entry.tooltipText !== ""
                    text: entry.tooltipText
                    font: Tokens.font.label.small
                    color: Colours.palette.m3onSurfaceVariant
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
