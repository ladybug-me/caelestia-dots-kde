pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import Caelestia.Config
import qs.components
import qs.components.containers
import qs.services
import qs.utils
import qs.modules.nexus
import qs.modules.nexus.common

VerticalFadeFlickable {
    id: root

    required property NexusState nState
    readonly property string normalizedQuery: root.nState.searchQuery.trim().toLowerCase()
    readonly property var filteredPages: PageRegistry.fuzzyPages(root.normalizedQuery)

    function categoryLabel(category: string): string {
        switch (category) {
        case "personalization": return I18n.tr("Personalization");
        case "connectivity": return I18n.tr("Connectivity");
        case "controls": return I18n.tr("Controls");
        case "shell": return I18n.tr("Caelestia");
        case "system": return I18n.tr("System");
        case "assistant": return I18n.tr("AI Assistant");
        default: return category;
        }
    }

    topMargin: Tokens.padding.large
    bottomMargin: Tokens.padding.large
    contentHeight: content.implicitHeight

    ColumnLayout {
        id: content

        anchors.left: parent.left
        anchors.right: parent.right
        spacing: Tokens.spacing.extraSmall

        Repeater {
            id: list

            model: root.filteredPages

            delegate: ColumnLayout {
                id: item

                required property var modelData
                required property int index
                readonly property var page: modelData.page
                readonly property int pageIdx: modelData.pageIdx

                readonly property bool isCurrentPage: pageIdx === root.nState.currentPageIdx
                readonly property bool isCategoryStart: index === 0 || list.model[index - 1].page.category !== page.category
                readonly property bool isCategoryEnd: index === list.model.length - 1 || list.model[index + 1].page.category !== page.category

                Layout.fillWidth: true
                spacing: Tokens.spacing.extraSmall

                SectionHeader {
                    visible: item.isCategoryStart
                    first: item.index === 0
                    text: root.categoryLabel(item.page.category)
                }

                StyledRect {
                    Layout.fillWidth: true
                    implicitHeight: {
                        const h = layout.implicitHeight + layout.anchors.margins * 2;
                        return h % 2 === 0 ? h : h + 1;
                    }

                    color: item.isCurrentPage ? Colours.palette.m3secondaryContainer : Colours.layer(Colours.palette.m3surfaceContainerHigh, 2)

                    topLeftRadius: stateLayer.pressed ? Tokens.rounding.medium : item.isCurrentPage ? Tokens.rounding.extraLargeIncreased : item.isCategoryStart ? Tokens.rounding.extraLarge : Tokens.rounding.extraSmall
                    topRightRadius: stateLayer.pressed ? Tokens.rounding.medium : item.isCurrentPage ? Tokens.rounding.extraLargeIncreased : item.isCategoryStart ? Tokens.rounding.extraLarge : Tokens.rounding.extraSmall
                    bottomLeftRadius: stateLayer.pressed ? Tokens.rounding.medium : item.isCurrentPage ? Tokens.rounding.extraLargeIncreased : item.isCategoryEnd ? Tokens.rounding.extraLarge : Tokens.rounding.extraSmall
                    bottomRightRadius: stateLayer.pressed ? Tokens.rounding.medium : item.isCurrentPage ? Tokens.rounding.extraLargeIncreased : item.isCategoryEnd ? Tokens.rounding.extraLarge : Tokens.rounding.extraSmall

                    RadiusBehavior on topLeftRadius {}
                    RadiusBehavior on topRightRadius {}
                    RadiusBehavior on bottomLeftRadius {}
                    RadiusBehavior on bottomRightRadius {}

                    StateLayer {
                        id: stateLayer

                        anchors.fill: parent
                        topLeftRadius: parent.topLeftRadius
                        topRightRadius: parent.topRightRadius
                        bottomLeftRadius: parent.bottomLeftRadius
                        bottomRightRadius: parent.bottomRightRadius

                        onClicked: root.nState.currentPageIdx = item.pageIdx
                    }

                    RowLayout {
                        id: layout

                        anchors.fill: parent
                        anchors.margins: Tokens.padding.large
                        spacing: Tokens.spacing.medium

                        StyledRect {
                            Layout.fillHeight: true
                            Layout.topMargin: -1
                            Layout.bottomMargin: -1
                            implicitWidth: height

                            radius: Tokens.rounding.full
                            color: item.isCurrentPage ? Colours.palette.m3primary : Colours.palette.m3secondaryContainer

                            MaterialIcon {
                                anchors.centerIn: parent
                                anchors.verticalCenterOffset: Centering.pixelAlign(parent.height, height)

                                text: item.page.icon
                                color: item.isCurrentPage ? Colours.palette.m3onPrimary : Colours.palette.m3onSecondaryContainer
                                fontStyle: Tokens.font.icon.builders.medium.weight(Font.Medium).build()
                                grade: 25
                                fill: item.page.noFill ? 0 : 1
                            }
                        }

                        ColumnLayout {
                            Layout.fillWidth: true
                            spacing: 0

                            StyledText {
                                Layout.fillWidth: true
                                text: item.page.label
                                font: Tokens.font.body.medium
                                elide: Text.ElideRight
                            }

                            StyledText {
                                Layout.fillWidth: true
                                text: item.page.description
                                color: Colours.palette.m3onSurfaceVariant
                                font: Tokens.font.label.small
                                elide: Text.ElideRight
                            }
                        }
                    }
                }
            }
        }
    }

    component RadiusBehavior: Behavior {
        Anim {
            type: Anim.DefaultEffects
        }
    }
}
