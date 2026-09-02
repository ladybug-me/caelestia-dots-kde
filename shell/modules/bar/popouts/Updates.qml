pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import Caelestia.Config
import qs.components
import qs.services
import qs.modules.nexus

ColumnLayout {
    id: root

    required property PopoutState popouts

    readonly property real masterScale: !isNaN(GlobalConfig.bar.previewScale) ? GlobalConfig.bar.previewScale : 1.0

    readonly property real barScaleOffset: GlobalConfig.bar.previewScaleWithBar ? (!isNaN(GlobalConfig.bar.scale) ? GlobalConfig.bar.scale : 1.0) : 1.0

    readonly property real scaleOffset: Math.max(0.1, masterScale * barScaleOffset)

    readonly property real fontScale: Math.max(0.1, scaleOffset + (!isNaN(GlobalConfig.bar.fontScaleOffset) ? GlobalConfig.bar.fontScaleOffset : 0.0))

    // Index of the Nexus "Updates" page, resolved dynamically so this menu
    // can't drift out of sync if the page registry is reordered.
    readonly property int updatesPageIdx: {
        const idx = PageRegistry.pages.findIndex(page => page.icon === "update");
        return idx >= 0 ? idx : 0;
    }

    readonly property bool hasUpdate: UpdateChecker.hasUpdate

    readonly property bool checking: UpdateChecker.checkingUpdates

    readonly property bool updateRunning: UpdateChecker.updateRunning

    readonly property string statusText: {
        if (root.updateRunning)
            return UpdateChecker.updateStatus !== "" ? UpdateChecker.updateStatus : I18n.tr("Updating…");
        if (root.checking)
            return I18n.tr("Checking for updates…");
        if (root.hasUpdate)
            return UpdateChecker.versionSummaryMode
                ? I18n.tr("New version available on %1").arg(UpdateChecker.currentBranch)
                : I18n.tr("%1 new commits on %2 branch").arg(UpdateChecker.pendingCount).arg(UpdateChecker.currentBranch);
        return I18n.tr("System is up to date");
    }

    readonly property string statusIcon: root.updateRunning ? "progress_activity" : root.checking ? "sync" : root.hasUpdate ? "update" : "check_circle"

    property double nowMs: Date.now()

    function formatDuration(ms: double): string {
        const total = Math.max(0, Math.floor(ms / 1000));
        const minutes = Math.floor(total / 60);
        const seconds = total % 60;
        return minutes > 0 ? I18n.tr("%1m %2s").arg(minutes).arg(seconds) : I18n.tr("%1s").arg(seconds);
    }

    function hideIndicator(): void {
        const entries = GlobalConfig.bar.entries ? [...GlobalConfig.bar.entries] : [];
        const idx = entries.findIndex(e => e.id === "updateIndicator");
        if (idx >= 0)
            entries[idx] = { id: "updateIndicator", enabled: false, zone: entries[idx].zone || "right" };
        else
            entries.push({ id: "updateIndicator", enabled: false, zone: "right" });
        GlobalConfig.bar.entries = entries;
        root.popouts.hasCurrent = false;
    }

    width: 300 * scaleOffset
    implicitWidth: 300 * scaleOffset
    spacing: Tokens.spacing.small * scaleOffset

    // Status card: state icon + summary + last/next check timings.
    StyledRect {
        Layout.fillWidth: true
        implicitHeight: statusLayout.implicitHeight + Tokens.padding.medium * 2 * root.scaleOffset
        radius: Tokens.rounding.medium * root.scaleOffset
        color: Colours.tPalette.m3surfaceContainer
        clip: true

        ColumnLayout {
            id: statusLayout

            anchors.left: parent.left
            anchors.right: parent.right
            anchors.top: parent.top
            anchors.margins: Tokens.padding.medium * root.scaleOffset
            spacing: Tokens.spacing.small * root.scaleOffset

            RowLayout {
                Layout.fillWidth: true
                spacing: Tokens.spacing.small * root.scaleOffset

                MaterialIcon {
                    text: root.statusIcon
                    color: (root.hasUpdate || root.updateRunning) ? Colours.palette.m3primary : Colours.palette.m3onSurfaceVariant
                    fontStyle.pointSize: Tokens.font.icon.medium.pointSize * root.fontScale
                }

                StyledText {
                    Layout.fillWidth: true
                    text: root.statusText
                    color: Colours.palette.m3onSurface
                    wrapMode: Text.Wrap
                    font.weight: 600
                    font.pointSize: Tokens.font.body.medium.pointSize * root.fontScale
                }
            }

            RowLayout {
                Layout.fillWidth: true
                spacing: Tokens.spacing.small * root.scaleOffset

                MaterialIcon {
                    text: "history"
                    color: Colours.palette.m3onSurfaceVariant
                    fontStyle.pointSize: Tokens.font.icon.medium.pointSize * root.fontScale
                }

                StyledText {
                    Layout.fillWidth: true
                    text: {
                        if (root.checking)
                            return I18n.tr("Checking…");
                        if (UpdateChecker.lastCheckMs <= 0)
                            return I18n.tr("Last check: not yet");
                        return I18n.tr("Last check %1 ago").arg(root.formatDuration(root.nowMs - UpdateChecker.lastCheckMs));
                    }
                    color: Colours.palette.m3onSurfaceVariant
                    font.pointSize: Tokens.font.body.medium.pointSize * root.fontScale
                }
            }

            RowLayout {
                Layout.fillWidth: true
                visible: UpdateChecker.lastCheckMs > 0
                spacing: Tokens.spacing.small * root.scaleOffset

                MaterialIcon {
                    text: "schedule"
                    color: Colours.palette.m3onSurfaceVariant
                    fontStyle.pointSize: Tokens.font.icon.medium.pointSize * root.fontScale
                }

                StyledText {
                    Layout.fillWidth: true
                    text: I18n.tr("Next check in %1").arg(root.formatDuration(UpdateChecker.lastCheckMs + UpdateChecker.checkIntervalMs - root.nowMs))
                    color: Colours.palette.m3onSurfaceVariant
                    font.pointSize: Tokens.font.body.medium.pointSize * root.fontScale
                }
            }
        }
    }

    // Actions card, mirroring the CachyOS updater menu.
    StyledRect {
        Layout.fillWidth: true
        implicitHeight: actionsLayout.implicitHeight + Tokens.padding.medium * 2 * root.scaleOffset
        radius: Tokens.rounding.medium * root.scaleOffset
        color: Colours.tPalette.m3surfaceContainer
        clip: true

        ColumnLayout {
            id: actionsLayout

            anchors.left: parent.left
            anchors.right: parent.right
            anchors.top: parent.top
            anchors.margins: Tokens.padding.medium * root.scaleOffset
            spacing: Tokens.spacing.small * root.scaleOffset

            // Check for updates
            StyledRect {
                Layout.fillWidth: true
                implicitHeight: checkRow.implicitHeight
                radius: Tokens.rounding.full
                color: "transparent"

                StateLayer {
                    anchors.margins: -Tokens.padding.medium / 2 * root.scaleOffset
                    anchors.leftMargin: -Tokens.padding.medium * root.scaleOffset
                    anchors.rightMargin: -Tokens.padding.medium * root.scaleOffset

                    radius: parent.radius
                    enabled: !root.checking && !root.updateRunning
                    onClicked: UpdateChecker.checkUpdates()
                }

                RowLayout {
                    id: checkRow

                    anchors.left: parent.left
                    anchors.right: parent.right
                    spacing: Tokens.spacing.small * root.scaleOffset

                    MaterialIcon {
                        text: root.checking ? "progress_activity" : "refresh"
                        color: Colours.palette.m3onSurfaceVariant
                        fontStyle.pointSize: Tokens.font.icon.medium.pointSize * root.fontScale
                    }

                    StyledText {
                        Layout.fillWidth: true
                        text: root.checking ? I18n.tr("Checking…") : I18n.tr("Check for updates")
                        color: Colours.palette.m3onSurface
                        font.pointSize: Tokens.font.body.medium.pointSize * root.fontScale
                    }
                }
            }

            // Open the updates page
            StyledRect {
                Layout.fillWidth: true
                implicitHeight: openRow.implicitHeight
                radius: Tokens.rounding.full
                color: "transparent"

                StateLayer {
                    anchors.margins: -Tokens.padding.medium / 2 * root.scaleOffset
                    anchors.leftMargin: -Tokens.padding.medium * root.scaleOffset
                    anchors.rightMargin: -Tokens.padding.medium * root.scaleOffset

                    radius: parent.radius
                    onClicked: {
                        root.popouts.hasCurrent = false;
                        WindowFactory.create(null, { initialPageIdx: root.updatesPageIdx });
                    }
                }

                RowLayout {
                    id: openRow

                    anchors.left: parent.left
                    anchors.right: parent.right
                    spacing: Tokens.spacing.small * root.scaleOffset

                    MaterialIcon {
                        text: "update"
                        color: Colours.palette.m3onSurfaceVariant
                        fontStyle.pointSize: Tokens.font.icon.medium.pointSize * root.fontScale
                    }

                    StyledText {
                        Layout.fillWidth: true
                        text: I18n.tr("Open Updates")
                        color: Colours.palette.m3onSurface
                        font.pointSize: Tokens.font.body.medium.pointSize * root.fontScale
                    }
                }
            }

            // CachyOS "Exit" equivalent: hide the indicator from the bar
            StyledRect {
                Layout.fillWidth: true
                implicitHeight: hideRow.implicitHeight
                radius: Tokens.rounding.full
                color: "transparent"

                StateLayer {
                    anchors.margins: -Tokens.padding.medium / 2 * root.scaleOffset
                    anchors.leftMargin: -Tokens.padding.medium * root.scaleOffset
                    anchors.rightMargin: -Tokens.padding.medium * root.scaleOffset

                    radius: parent.radius
                    onClicked: root.hideIndicator()
                }

                RowLayout {
                    id: hideRow

                    anchors.left: parent.left
                    anchors.right: parent.right
                    spacing: Tokens.spacing.small * root.scaleOffset

                    MaterialIcon {
                        text: "visibility_off"
                        color: Colours.palette.m3onSurfaceVariant
                        fontStyle.pointSize: Tokens.font.icon.medium.pointSize * root.fontScale
                    }

                    StyledText {
                        Layout.fillWidth: true
                        text: I18n.tr("Hide from bar")
                        color: Colours.palette.m3onSurface
                        font.pointSize: Tokens.font.body.medium.pointSize * root.fontScale
                    }
                }
            }
        }
    }

    Timer {
        interval: 1000
        repeat: true
        running: true
        onTriggered: root.nowMs = Date.now()
    }
}
