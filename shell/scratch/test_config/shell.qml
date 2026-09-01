import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Caelestia.Services

ApplicationWindow {
    width: 600
    height: 800
    visible: true
    title: "AudioBackend Test"

    ColumnLayout {
        anchors.fill: parent
        anchors.margins: 10

        RowLayout {
            CheckBox {
                text: "Show Inactive Devices"
                checked: AudioBackend.showInactiveDevices
                onCheckedChanged: AudioBackend.showInactiveDevices = checked
            }
        }

        ScrollView {
            Layout.fillWidth: true
            Layout.fillHeight: true

            ColumnLayout {
                Text { text: "Sinks:"; font.bold: true }
                ListView {
                    Layout.fillWidth: true
                    Layout.preferredHeight: contentItem.childrenRect.height
                    model: AudioBackend.sinks
                    delegate: Text {
                        text: "- " + model.description
                    }
                }

                Text { text: "Sources:"; font.bold: true }
                ListView {
                    Layout.fillWidth: true
                    Layout.preferredHeight: contentItem.childrenRect.height
                    model: AudioBackend.sources
                    delegate: Text {
                        text: "- " + model.description
                    }
                }

                Text { text: "Cards & Profiles:"; font.bold: true }
                ListView {
                    Layout.fillWidth: true
                    Layout.preferredHeight: contentItem.childrenRect.height
                    model: AudioBackend.cards
                    delegate: ColumnLayout {
                        Text { text: "Card: " + model.name }
                        ListView {
                            Layout.fillWidth: true
                            Layout.preferredHeight: contentItem.childrenRect.height
                            Layout.leftMargin: 20
                            model: model.PulseObject.profiles
                            delegate: RowLayout {
                                RadioButton {
                                    text: modelData.description
                                    // Note: modelData is PulseAudioQt::Profile*
                                    // In a real app we'd bind checked to whether this is the active profile
                                }
                            }
                        }
                    }
                }
            }
        }
    }
}
