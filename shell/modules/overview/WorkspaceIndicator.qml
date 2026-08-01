pragma ComponentBehavior: Bound

import QtQuick
import Caelestia.Config
import qs.components
import qs.components.controls
import qs.services

Row {
    id: indicatorRow
    
    property int count: 0
    property int currentIndex: 0
    signal workspaceSelected(int index)

    spacing: Tokens.spacing.small

    Repeater {
        model: indicatorRow.count
        Item {
            required property int index
            width: 48
            height: 48

            HoverHandler { id: hoverIndicator }
            
            Rectangle {
                anchors.fill: parent
                radius: width / 2
                color: indicatorRow.currentIndex === index ? Colours.palette.m3primary : 
                       (hoverIndicator.hovered ? Colours.layer(Colours.palette.m3onSurface, 0.12) : "transparent")
            }
            
            StyledText {
                anchors.centerIn: parent
                text: (index + 1).toString()
                font: Tokens.font.title.medium
                color: indicatorRow.currentIndex === index ? Colours.palette.m3onPrimary : Colours.palette.m3onSurface
            }

            StateLayer {
                anchors.fill: parent
                radius: parent.width / 2
                onClicked: indicatorRow.workspaceSelected(index)
            }
        }
    }
}
