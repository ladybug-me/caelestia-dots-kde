import QtQuick
import QtQuick.Layouts
import Caelestia.Config
import qs.modules.nexus.common
import qs.services

PageBase {
    id: root

    title: I18n.tr("Clipboard")
    isSubPage: true

    ColumnLayout {
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.top: parent.top
        width: root.cappedWidth
        spacing: Tokens.spacing.extraSmall / 2

        SectionHeader {
            first: true
            text: I18n.tr("History")
        }

        StepperRow {
            first: true
            last: true
            label: I18n.tr("Maximum entries")
            subtext: I18n.tr("Number of entries available in the launcher")
            value: GlobalConfig.launcher.clipboardMaxEntries
            from: 1
            to: 2048
            stepSize: 10
            onMoved: value => GlobalConfig.launcher.clipboardMaxEntries = value
        }
    }
}