import QtQuick.Layouts
import Caelestia.Config
import qs.modules.nexus.common
import qs.services

PageBase {
    id: root

    title: I18n.tr("Notifications")

    ColumnLayout {
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.top: parent.top
        width: root.cappedWidth
        spacing: Tokens.spacing.extraSmall / 2

        SectionHeader {
            first: true
            text: I18n.tr("Delivery")
        }

        NavRow {
            first: true
            icon: "notifications"
            label: I18n.tr("Notifications")
            status: I18n.tr("Position, timeout, and display behavior")
            onClicked: root.nState.openSubPage(1)
        }

        NavRow {
            last: true
            icon: "campaign"
            label: I18n.tr("Toasts")
            status: I18n.tr("Fullscreen behavior, appearance, and sound")
            onClicked: root.nState.openSubPage(2)
        }

        SectionHeader {
            text: I18n.tr("Automation")
        }

        NavRow {
            first: true
            last: true
            icon: "tune"
            label: I18n.tr("Toast events")
            status: I18n.tr("Choose which system changes show a toast")
            onClicked: root.nState.openSubPage(3)
        }
    }
}
