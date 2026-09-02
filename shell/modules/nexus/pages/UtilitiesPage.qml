pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import Caelestia.Config
import qs.modules.nexus.common
import qs.services

PageBase {
    id: root

    title: I18n.tr("Utilities")

    ColumnLayout {
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.top: parent.top
        width: root.cappedWidth
        spacing: Tokens.spacing.extraSmall / 2

        SectionHeader {
            first: true
            text: I18n.tr("Quick controls")
        }

        NavRow {
            first: true
            icon: "volume_up"
            label: I18n.tr("On-screen sliders")
            status: I18n.tr("Volume, microphone, brightness, and edge triggers")
            onClicked: root.nState.openSubPage(3)
        }

        NavRow {
            icon: "content_paste"
            label: I18n.tr("Clipboard")
            status: I18n.tr("History size")
            onClicked: root.nState.openSubPage(4)
        }

        NavRow {
            icon: "widgets"
            label: I18n.tr("Utilities panel")
            status: I18n.tr("Choose the cards shown in the panel")
            onClicked: root.nState.openSubPage(5)
        }

        NavRow {
            last: true
            icon: "toggle_on"
            label: I18n.tr("Quick toggles")
            status: I18n.tr("Choose the controls shown in Quick Toggles")
            onClicked: root.nState.openSubPage(6)
        }

        SectionHeader {
            text: I18n.tr("Performance")
        }

        NavRow {
            first: true
            last: true
            icon: "sports_esports"
            label: I18n.tr("Game mode")
            status: I18n.tr("Auto-enable rules and performance overrides")
            onClicked: root.nState.openSubPage(1)
        }
    }
}
