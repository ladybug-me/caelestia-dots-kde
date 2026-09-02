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

    title: I18n.tr("Sidebar")
    isSubPage: true

    ColumnLayout {
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.top: parent.top
        width: root.cappedWidth
        spacing: Tokens.spacing.large

        SectionHeader {
            first: true
            text: I18n.tr("General")
        }

        ToggleRow {
            first: true
            text: I18n.tr("Enabled")
            checked: Config.sidebar.enabled
            onToggled: GlobalConfig.sidebar.enabled = checked
        }

        StepperRow {
            Layout.topMargin: Tokens.spacing.extraSmall / 2 - parent.spacing
            Layout.fillWidth: true
            last: true
            label: I18n.tr("Drag threshold")
            subtext: I18n.tr("Pixels dragged before the sidebar opens")
            value: Config.sidebar.dragThreshold
            from: 0
            to: 200
            stepSize: 5
            onMoved: v => GlobalConfig.sidebar.dragThreshold = v
        }

        // Sidebar Tabs
        SectionHeader {
            text: I18n.tr("Sidebar Tabs")
        }

        ToggleRow {
            Layout.fillWidth: true
            first: true
            text: I18n.tr("Show News tab")
            subtext: I18n.tr("Show the News tab in the sidebar")
            checked: GlobalConfig.ai.showNews
            onToggled: GlobalConfig.ai.showNews = checked
        }

        ToggleRow {
            Layout.topMargin: Tokens.spacing.extraSmall / 2 - parent.spacing
            Layout.fillWidth: true
            last: true
            text: I18n.tr("Show Caelestia Mode")
            subtext: I18n.tr("Show the Caelestia Mode toggle at the bottom of notifications")
            checked: GlobalConfig.ai.showCaelestiaMode
            onToggled: GlobalConfig.ai.showCaelestiaMode = checked
        }
    }
}
