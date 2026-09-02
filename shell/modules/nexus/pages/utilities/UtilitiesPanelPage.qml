import QtQuick
import QtQuick.Layouts
import Caelestia.Config
import qs.modules.nexus.common
import qs.services

PageBase {
    id: root

    title: I18n.tr("Utilities panel")
    isSubPage: true

    ColumnLayout {
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.top: parent.top
        width: root.cappedWidth
        spacing: Tokens.spacing.extraSmall / 2

        SectionHeader {
            first: true
            text: I18n.tr("Visible cards")
        }

        ToggleRow {
            first: true
            text: I18n.tr("Keep Awake")
            subtext: I18n.tr("Show the Keep Awake card")
            checked: Config.utilities.showKeepAwake
            onToggled: GlobalConfig.utilities.showKeepAwake = checked
        }

        ToggleRow {
            text: I18n.tr("Screen Recorder")
            subtext: I18n.tr("Show the Screen Recorder card")
            checked: Config.utilities.showScreenRecorder
            onToggled: GlobalConfig.utilities.showScreenRecorder = checked
        }

        ToggleRow {
            last: true
            text: I18n.tr("Quick Toggles")
            subtext: I18n.tr("Show the Quick Toggles card")
            checked: Config.utilities.showQuickToggles
            onToggled: GlobalConfig.utilities.showQuickToggles = checked
        }
    }
}