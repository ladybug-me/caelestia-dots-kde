import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Quickshell
import Caelestia.Config
import qs.components.controls as Controls
import qs.components.effects

Popup {
    id: root

    property string scriptPath: Quickshell.shellPath("scripts/add_desktop_shortcut.sh")

    width: 300
    height: contentColumn.implicitHeight + Tokens.padding.medium * 2
    modal: true
    focus: true
    closePolicy: Popup.CloseOnEscape | Popup.CloseOnPressOutside

    x: Math.round((parent.width - width) / 2)
    y: Math.round((parent.height - height) / 2)

    background: Elevation {
        anchors.fill: parent
        radius: Tokens.rounding.large
        level: 3
    }

    contentItem: ColumnLayout {
        id: contentColumn
        spacing: Tokens.spacing.small

        Text {
            text: qsTr("Add Custom Shortcut")
            font: Tokens.fonts.bodyLarge
            color: Colours.palette.onSurface
            Layout.fillWidth: true
            Layout.bottomMargin: Tokens.spacing.small
        }

        Controls.StyledTextField {
            id: labelField
            Layout.fillWidth: true
            placeholderText: qsTr("Label (e.g. Firefox)")
        }

        Controls.StyledTextField {
            id: commandField
            Layout.fillWidth: true
            placeholderText: qsTr("Command (e.g. firefox)")
        }

        Controls.StyledTextField {
            id: iconField
            Layout.fillWidth: true
            placeholderText: qsTr("Icon (e.g. firefox)")
        }

        RowLayout {
            Layout.fillWidth: true
            Layout.topMargin: Tokens.spacing.small
            
            Item { Layout.fillWidth: true } // Spacer

            Controls.TextButton {
                text: qsTr("Cancel")
                onClicked: root.close()
            }

            Controls.TextButton {
                text: qsTr("Save")
                enabled: labelField.text.length > 0 && commandField.text.length > 0
                onClicked: {
                    Quickshell.execDetached(["bash", scriptPath, labelField.text, commandField.text, iconField.text])
                    labelField.text = ""
                    commandField.text = ""
                    iconField.text = ""
                    root.close()
                }
            }
        }
    }
}
