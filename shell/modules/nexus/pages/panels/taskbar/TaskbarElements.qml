pragma ComponentBehavior: Bound

import QtQuick.Layouts
import qs.utils
import qs.modules.nexus.common
import qs.services

PageBase {
    id: root

    title: I18n.tr("Taskbar Elements")
    isSubPage: true

    ColumnLayout {
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.top: parent.top
        width: root.cappedWidth
        spacing: Tokens.spacing.extraSmall / 2

        SectionHeader {
            first: true
            text: I18n.tr("Main sections")
        }

        NavRow {
            first: true
            icon: "workspaces"
            label: I18n.tr("Workspaces")
            status: I18n.tr("Indicators, window icons")
            onClicked: root.nState.openSubPage(7)
        }

        NavRow {
            icon: "web_asset"
            label: I18n.tr("Active window")
            status: I18n.tr("Title display, popout")
            onClicked: root.nState.openSubPage(8)
        }

        NavRow {
            icon: "widgets"
            label: I18n.tr("Tray")
            status: I18n.tr("System tray icons")
            onClicked: root.nState.openSubPage(9)
        }

        NavRow {
            icon: "signal_cellular_alt"
            label: I18n.tr("Status icons")
            status: I18n.tr("Visible indicators")
            onClicked: root.nState.openSubPage(10)
        }

        NavRow {
            icon: "schedule"
            label: I18n.tr("Clock")
            status: I18n.tr("Date, icon, background")
            onClicked: root.nState.openSubPage(11)
        }

        NavRow {
            icon: "dock"
            label: I18n.tr("Dock")
            status: Strings.localizeEnglishSpelling(I18n.tr("Positioning, recolouring"))
            onClicked: root.nState.openSubPage(12)
        }

        NavRow {
            icon: "code"
            label: I18n.tr("GitHub")
            status: I18n.tr("Contributions, token setup")
            onClicked: root.nState.openSubPage(13)
        }

        NavRow {
            last: true
            icon: "update"
            label: I18n.tr("Updates")
            status: I18n.tr("Indicator visibility, automatic checks")
            onClicked: root.nState.openSubPage(17)
        }
    }
}
