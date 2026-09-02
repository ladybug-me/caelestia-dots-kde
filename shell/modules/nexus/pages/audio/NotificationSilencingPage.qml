import QtQuick
import QtQuick.Layouts
import Caelestia.Config
import qs.components
import qs.components.controls
import qs.modules.nexus.common
import qs.services

PageBase {
    id: root

    function addApp() {
        const appName = appInput.text.trim();
        if (appName === "")
            return;

        const mutedApps = Array.from(GlobalConfig.audio.sounds.disabledNotifApps);
        if (!mutedApps.includes(appName)) {
            mutedApps.push(appName);
            GlobalConfig.audio.sounds.disabledNotifApps = mutedApps;
            GlobalConfig.save();
        }
        appInput.text = "";
    }

    title: I18n.tr("Muted notification apps")
    isSubPage: true

    ColumnLayout {
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.top: parent.top
        width: root.cappedWidth
        spacing: Tokens.spacing.extraSmall / 2

        SectionHeader {
            first: true
            text: I18n.tr("Muted apps")
        }

        RowLayout {
            Layout.fillWidth: true
            spacing: Tokens.spacing.small

            StyledInputField {
                id: appInput

                Layout.fillWidth: true
                onEditingFinished: root.addApp()
            }

            IconTextButton {
                text: I18n.tr("Add")
                icon: "add"
                onClicked: root.addApp()
            }
        }

        Flow {
            Layout.fillWidth: true
            spacing: Tokens.spacing.small

            Repeater {
                model: GlobalConfig.audio.sounds.disabledNotifApps

                delegate: StyledRect {
                    required property string modelData
                    required property int index

                    width: implicitWidth
                    height: implicitHeight
                    implicitWidth: chipLayout.implicitWidth + Tokens.padding.medium * 2
                    implicitHeight: chipLayout.implicitHeight + Tokens.padding.extraSmall * 2
                    color: Colours.layer(Colours.palette.m3surfaceContainer, 2)
                    radius: Tokens.rounding.large

                    RowLayout {
                        id: chipLayout

                        x: Tokens.padding.medium
                        y: Tokens.padding.extraSmall
                        spacing: Tokens.spacing.extraSmall

                        StyledText {
                            text: modelData
                        }

                        MaterialIcon {
                            text: "close"
                            font: Tokens.font.icon.small

                            StateLayer {
                                onClicked: {
                                    const mutedApps = Array.from(GlobalConfig.audio.sounds.disabledNotifApps);
                                    mutedApps.splice(index, 1);
                                    GlobalConfig.audio.sounds.disabledNotifApps = mutedApps;
                                    GlobalConfig.save();
                                }
                            }
                        }
                    }
                }
            }
        }
    }
}