pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import Quickshell
import Caelestia.Config
import qs.components
import qs.components.controls
import qs.services
import qs.utils
import qs.modules.nexus.common
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
        spacing: Tokens.spacing.large

        StyledRect {
            Layout.fillWidth: true
            Layout.topMargin: Tokens.spacing.medium
            implicitHeight: row.implicitHeight + Tokens.padding.large * 2
            radius: Tokens.rounding.large
            color: Colours.tPalette.m3surfaceContainer
            
            StateLayer {
                anchors.fill: parent
                radius: parent.radius
                onClicked: root.nState.openSubPage(9)
            }
            
            RowLayout {
                id: row
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.verticalCenter: parent.verticalCenter
                anchors.margins: Tokens.padding.large
                spacing: Tokens.spacing.large
                
                MaterialIcon {
                    text: "settings_suggest"
                    fontStyle: Tokens.font.icon.extraLarge
                    color: Colours.palette.m3onSurface
                }
                
                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: Tokens.spacing.extraSmall
                    StyledText {
                        text: "Advanced Material You Settings"
                        font: Tokens.font.title.small
                        color: Colours.palette.m3onSurface
                    }
                    StyledText {
                        text: "Configure advanced color engine settings and integrations"
                        font: Tokens.font.body.medium
                        color: Colours.palette.m3outline
                    }
                }
                
                MaterialIcon {
                    text: "chevron_right"
                    fontStyle: Tokens.font.icon.large
                    color: Colours.palette.m3onSurfaceVariant
                }
            }
        }

        StyledText {
            Layout.topMargin: Tokens.spacing.small
            text: qsTr("Schemes")
            font: Tokens.font.title.medium
        }

        GridLayout {
            Layout.fillWidth: true
            columns: 2
            rowSpacing: Tokens.spacing.medium
            columnSpacing: Tokens.spacing.medium

            Repeater {
                model: Schemes.list
                
                StyledRect {
                    id: delegateRect
                    required property var modelData
                    
                    readonly property bool isSelected: `${modelData?.name} ${modelData?.flavour}` === Schemes.currentScheme
                    
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    implicitHeight: schemeRow.implicitHeight + Tokens.padding.large * 2
                    radius: Tokens.rounding.large
                    color: isSelected ? Colours.palette.m3secondaryContainer : Colours.tPalette.m3surfaceContainer
                    border.width: isSelected ? 2 : 1
                    border.color: isSelected ? Colours.palette.m3secondary : Colours.palette.m3surfaceVariant
                    
                    StateLayer {
                        radius: parent.radius
                        onClicked: delegateRect.modelData?.onClicked(null)
                    }
                    
                    RowLayout {
                        id: schemeRow
                        anchors.fill: parent
                        anchors.margins: Tokens.padding.large
                        spacing: Tokens.spacing.large
                        
                        StyledRect {
                            id: preview
                            Layout.preferredWidth: Tokens.sizes.launcher.itemHeight
                            Layout.preferredHeight: Tokens.sizes.launcher.itemHeight
                            
                            border.width: 1
                            border.color: Qt.alpha(`#${delegateRect.modelData?.colours?.outline}`, 0.5)

                            color: `#${delegateRect.modelData?.colours?.surface}`
                            radius: Tokens.rounding.full

                            Item {
                                anchors.top: parent.top
                                anchors.bottom: parent.bottom
                                anchors.right: parent.right

                                width: parent.width / 2
                                clip: true

                                StyledRect {
                                    anchors.top: parent.top
                                    anchors.bottom: parent.bottom
                                    anchors.right: parent.right

                                    width: preview.width
                                    color: `#${delegateRect.modelData?.colours?.primary}`
                                    radius: Tokens.rounding.full
                                }
                            }
                        }
                        
                        ColumnLayout {
                            Layout.fillWidth: true
                            spacing: Tokens.spacing.extraSmall
                            
                            StyledText {
                                Layout.fillWidth: true
                                text: delegateRect.modelData?.flavour ?? ""
                                font: Tokens.font.title.small
                                color: delegateRect.isSelected ? Colours.palette.m3onSecondaryContainer : Colours.palette.m3onSurface
                            }
                            StyledText {
                                Layout.fillWidth: true
                                text: delegateRect.modelData?.name ?? ""
                                font: Tokens.font.body.medium
                                color: delegateRect.isSelected ? Colours.palette.m3onSecondaryContainer : Colours.palette.m3outline
                            }
                        }
                        
                        MaterialIcon {
                            Layout.alignment: Qt.AlignVCenter
                            visible: delegateRect.isSelected
                            text: "check"
                            color: Colours.palette.m3onSecondaryContainer
                            fontStyle: Tokens.font.icon.large
                        }
                    }
                }
            }
        }

        StyledText {
            Layout.topMargin: Tokens.spacing.large
            text: qsTr("Variants")
            font: Tokens.font.title.medium
        }

        GridLayout {
            Layout.fillWidth: true
            Layout.bottomMargin: Tokens.spacing.extraLarge
            columns: 2
            rowSpacing: Tokens.spacing.medium
            columnSpacing: Tokens.spacing.medium

            Repeater {
                model: M3Variants.list
                
                StyledRect {
                    id: varDelegateRect
                    required property var modelData
                    
                    readonly property bool isSelected: modelData?.variant === Schemes.currentVariant
                    
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    Layout.preferredWidth: 1
                    implicitHeight: varCol.implicitHeight + Tokens.padding.large * 2
                    radius: Tokens.rounding.large
                    color: isSelected ? Colours.palette.m3secondaryContainer : Colours.tPalette.m3surfaceContainer
                    border.width: isSelected ? 2 : 1
                    border.color: isSelected ? Colours.palette.m3secondary : Colours.palette.m3surfaceVariant
                    
                    StateLayer {
                        radius: parent.radius
                        onClicked: varDelegateRect.modelData?.onClicked(null)
                    }
                    
                    RowLayout {
                        id: varCol
                        anchors.top: parent.top
                        anchors.left: parent.left
                        anchors.right: parent.right
                        anchors.margins: Tokens.padding.large
                        spacing: Tokens.spacing.large
                        
                        MaterialIcon {
                            Layout.alignment: Qt.AlignTop
                            text: varDelegateRect.modelData?.icon ?? ""
                            fontStyle: Tokens.font.icon.extraLarge
                            color: varDelegateRect.isSelected ? Colours.palette.m3onSecondaryContainer : Colours.palette.m3onSurface
                        }
                        
                        ColumnLayout {
                            Layout.fillWidth: true
                            spacing: Tokens.spacing.extraSmall
                            
                            StyledText {
                                Layout.fillWidth: true
                                text: varDelegateRect.modelData?.name ?? ""
                                font: Tokens.font.title.small
                                color: varDelegateRect.isSelected ? Colours.palette.m3onSecondaryContainer : Colours.palette.m3onSurface
                            }
                            StyledText {
                                Layout.fillWidth: true
                                text: varDelegateRect.modelData?.description ?? ""
                                font: Tokens.font.body.medium
                                color: varDelegateRect.isSelected ? Colours.palette.m3onSecondaryContainer : Colours.palette.m3outline
                                wrapMode: Text.Wrap
                            }
                        }
                    }
                }
            }
        }
    }
}
