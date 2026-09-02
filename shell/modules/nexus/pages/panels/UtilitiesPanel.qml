pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import Quickshell
import Caelestia.Config
import qs.components
import qs.components.controls
import qs.utils
import qs.modules.nexus.common
import qs.services

PageBase {
    id: root

    title: I18n.tr("Quick toggle")
    isSubPage: true

    ColumnLayout {
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.top: parent.top
        width: root.cappedWidth
        spacing: Tokens.spacing.extraSmall / 2

        SectionHeader {
            first: true
            text: I18n.tr("General")
        }

        ToggleRow {
            first: true
            text: I18n.tr("Enabled")
            checked: Config.utilities.enabled
            onToggled: GlobalConfig.utilities.enabled = checked
        }

        ToggleRow {
            Layout.fillWidth: true
            text: I18n.tr("Show on hover")
            subtext: I18n.tr("Reveal when the cursor reaches the screen edge")
            checked: Config.utilities.showOnHover
            onToggled: GlobalConfig.utilities.showOnHover = checked
        }
        
        StepperRow {
            Layout.topMargin: Tokens.spacing.extraSmall / 2 - parent.spacing
            Layout.fillWidth: true
            label: I18n.tr("Hover trigger depth")
            subtext: I18n.tr("Distance in from the screen edge that opens the quick toggles")
            value: Config.utilities.hoverThickness
            from: 1
            to: 100
            stepSize: 1
            onMoved: v => GlobalConfig.utilities.hoverThickness = v
        }

        StepperRow {
            Layout.topMargin: Tokens.spacing.extraSmall / 2 - parent.spacing
            Layout.fillWidth: true
            label: I18n.tr("Hover trigger width")
            subtext: I18n.tr("How much of that edge opens the quick toggles, as a percentage of their width")
            value: Config.utilities.hoverWidth
            from: 10
            to: 100
            stepSize: 5
            onMoved: v => GlobalConfig.utilities.hoverWidth = v
        }

        StepperRow {
            Layout.topMargin: Tokens.spacing.extraSmall / 2 - parent.spacing
            Layout.fillWidth: true
            last: true
            label: I18n.tr("Drag threshold")
            subtext: I18n.tr("Pixels dragged before the quick toggle opens")
            value: Config.utilities.dragThreshold
            from: 0
            to: 200
            stepSize: 5
            onMoved: v => GlobalConfig.utilities.dragThreshold = v
        }
    }
}
