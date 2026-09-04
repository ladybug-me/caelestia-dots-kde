pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import Quickshell
import Caelestia.Config
import qs.components
import qs.components.controls
import qs.utils
import qs.modules.nexus.common

PageBase {
    id: root

    title: qsTr("Quick toggle")
    isSubPage: true

    ColumnLayout {
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.top: parent.top
        width: root.cappedWidth
        spacing: Tokens.spacing.extraSmall / 2

        SectionHeader {
            first: true
            text: qsTr("General")
        }

        ToggleRow {
            first: true
            text: qsTr("Enabled")
            checked: root.nState.targetConfig.utilities.enabled
            onToggled: Globalroot.nState.targetConfig.utilities.enabled = checked
        }

        ToggleRow {
            Layout.fillWidth: true
            text: qsTr("Show on hover")
            subtext: qsTr("Reveal when the cursor reaches the screen edge")
            checked: root.nState.targetConfig.utilities.showOnHover
            onToggled: Globalroot.nState.targetConfig.utilities.showOnHover = checked
        }
        
        StepperRow {
            Layout.topMargin: Tokens.spacing.extraSmall / 2 - parent.spacing
            Layout.fillWidth: true
            label: qsTr("Hover trigger depth")
            subtext: qsTr("Distance in from the screen edge that opens the quick toggles")
            value: root.nState.targetConfig.utilities.hoverThickness
            from: 1
            to: 100
            stepSize: 1
            onMoved: v => Globalroot.nState.targetConfig.utilities.hoverThickness = v
        }

        StepperRow {
            Layout.topMargin: Tokens.spacing.extraSmall / 2 - parent.spacing
            Layout.fillWidth: true
            label: qsTr("Hover trigger width")
            subtext: qsTr("How much of that edge opens the quick toggles, as a percentage of their width")
            value: root.nState.targetConfig.utilities.hoverWidth
            from: 10
            to: 100
            stepSize: 5
            onMoved: v => Globalroot.nState.targetConfig.utilities.hoverWidth = v
        }

        StepperRow {
            Layout.topMargin: Tokens.spacing.extraSmall / 2 - parent.spacing
            Layout.fillWidth: true
            last: true
            label: qsTr("Drag threshold")
            subtext: qsTr("Pixels dragged before the quick toggle opens")
            value: root.nState.targetConfig.utilities.dragThreshold
            from: 0
            to: 200
            stepSize: 5
            onMoved: v => Globalroot.nState.targetConfig.utilities.dragThreshold = v
        }
    }
}
