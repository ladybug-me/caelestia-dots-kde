import QtQuick
import QtQuick.Layouts
import Caelestia.Config
import qs.components
import qs.services
import qs.utils
import qs.modules.nexus.common
import qs.modules.launcher.items
import qs.modules.launcher.services

PageBase {
    id: root

    title: Strings.localizeEnglishSpelling(qsTr("Colours"))
    isSubPage: true

    Component.onCompleted: {
        Schemes.reload();
    }

    ColumnLayout {
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.top: parent.top
        width: root.cappedWidth
        spacing: Tokens.spacing.small

        StyledText {
            Layout.topMargin: Tokens.spacing.medium
            text: qsTr("Schemes")
            font: Tokens.font.title.small
        }

        Column {
            Layout.fillWidth: true
            spacing: Tokens.spacing.small

            Repeater {
                model: Schemes.list
                delegate: SchemeItem {
                    list: null
                }
            }
        }

        StyledText {
            Layout.topMargin: Tokens.spacing.large
            text: qsTr("Variants")
            font: Tokens.font.title.small
        }

        Column {
            Layout.fillWidth: true
            spacing: Tokens.spacing.small
            Layout.bottomMargin: Tokens.spacing.large

            Repeater {
                model: M3Variants.list
                delegate: VariantItem {
                    list: null
                }
            }
        }
    }
}
