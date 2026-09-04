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

    title: qsTr("Sidebar")
    isSubPage: true

    ColumnLayout {
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.top: parent.top
        width: root.cappedWidth
        spacing: Tokens.spacing.large

        SectionHeader {
            first: true
            text: qsTr("General")
        }

        ToggleRow {
            first: true
            text: qsTr("Enabled")
            checked: root.nState.targetConfig.sidebar.enabled
            onToggled: Globalroot.nState.targetConfig.sidebar.enabled = checked
        }

        StepperRow {
            Layout.topMargin: Tokens.spacing.extraSmall / 2 - parent.spacing
            Layout.fillWidth: true
            label: qsTr("Drag threshold")
            subtext: qsTr("Pixels dragged before the sidebar opens")
            value: root.nState.targetConfig.sidebar.dragThreshold
            from: 0
            to: 200
            stepSize: 5
            onMoved: v => Globalroot.nState.targetConfig.sidebar.dragThreshold = v
        }

        StepperRow {
            Layout.topMargin: Tokens.spacing.extraSmall / 2 - parent.spacing
            Layout.fillWidth: true
            last: true
            label: qsTr("Grab width")
            subtext: qsTr("Pixels of screen edge reserved for grabbing the sidebar")
            value: root.nState.targetConfig.sidebar.grabWidth
            from: 1
            to: 100
            stepSize: 1
            onMoved: v => Globalroot.nState.targetConfig.sidebar.grabWidth = v
        }

        // Sidebar Tabs
        SectionHeader {
            text: qsTr("Sidebar Tabs")
        }

        ToggleRow {
            Layout.fillWidth: true
            first: true
            text: qsTr("Show News tab")
            subtext: qsTr("Show the News tab in the sidebar")
            checked: Globalroot.nState.targetConfig.ai.showNews
            onToggled: Globalroot.nState.targetConfig.ai.showNews = checked
        }

        ToggleRow {
            Layout.topMargin: Tokens.spacing.extraSmall / 2 - parent.spacing
            Layout.fillWidth: true
            last: true
            text: qsTr("Show Caelestia Mode")
            subtext: qsTr("Show the Caelestia Mode toggle at the bottom of notifications")
            checked: Globalroot.nState.targetConfig.ai.showCaelestiaMode
            onToggled: Globalroot.nState.targetConfig.ai.showCaelestiaMode = checked
        }
    }
}
