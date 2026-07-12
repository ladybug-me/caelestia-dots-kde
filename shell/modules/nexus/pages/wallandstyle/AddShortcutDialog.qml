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
    signal saved(string label, string cmd, string icon)

    width: 300
    padding: 24
    height: contentColumn.implicitHeight + 48
    modal: true
    focus: true
    closePolicy: Popup.CloseOnEscape | Popup.CloseOnPressOutside

    x: Math.round((parent.width - width) / 2)
    y: Math.round((parent.height - height) / 2)

    background: Item {
        Elevation {
            anchors.fill: bgRect
            level: 3
            radius: bgRect.radius
        }
        Rectangle {
            id: bgRect
            anchors.fill: parent
            color: Colours.palette.surface
            radius: 16
            border.width: 1
            border.color: Colours.palette.surfaceVariant
        }
    }

    contentItem: ColumnLayout {
        id: contentColumn
        spacing: 8

        Text {
            text: qsTr("Add Custom Shortcut")
            font: Tokens.fonts.bodyLarge
            color: Colours.palette.onSurface
            Layout.fillWidth: true
            Layout.bottomMargin: 8
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
            Layout.topMargin: 8
            
            Item { Layout.fillWidth: true } // Spacer

            Controls.TextButton {
                text: qsTr("Cancel")
                onClicked: root.close()
            }

            Controls.TextButton {
                text: qsTr("Save")
                enabled: labelField.text.length > 0 && commandField.text.length > 0
                onClicked: {
                    root.saved(labelField.text, commandField.text, iconField.text);
                    labelField.text = ""
                    commandField.text = ""
                    iconField.text = ""
                    root.close()
                }
            }
        }
    }
}
