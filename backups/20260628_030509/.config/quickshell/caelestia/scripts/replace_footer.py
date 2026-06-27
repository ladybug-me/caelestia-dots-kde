import sys

filepath = '/home/dim/.config/quickshell/caelestia/modules/sidebar/AiAssistant.qml'
with open(filepath, 'r') as f:
    lines = f.readlines()

def replace_lines(start, end, replacement_str):
    global lines
    replacement_lines = [l + '\n' for l in replacement_str.split('\n')]
    if replacement_lines[-1] == '\n':
        replacement_lines.pop()
    lines = lines[:start-1] + replacement_lines + lines[end:]

replace_lines(756, 793, '''                    Row {
                        spacing: Tokens.spacing.small
                        y: Tokens.spacing.medium / 2
                        
                        Item {
                            width: 24
                            height: 24
                            anchors.verticalCenter: parent.verticalCenter
                            
                            Rectangle {
                                width: 16
                                height: 16
                                anchors.centerIn: parent
                                radius: 4
                                color: "transparent"
                                border.width: 2
                                border.color: Colours.palette.m3primary
                                
                                NumberAnimation on rotation {
                                    from: 0
                                    to: 360
                                    duration: 1000
                                    loops: Animation.Infinite
                                    running: root.isTyping
                                }
                            }
                        }
                        
                        StyledText {
                            text: root.currentActionText
                            color: Colours.palette.m3onSurfaceVariant
                            font: Tokens.font.body.small
                            anchors.verticalCenter: parent.verticalCenter
                        }
                    }''')

replace_lines(796, 844, '''                delegate: Item {
                    id: delegateItem

                    required property string text
                    required property bool isUser
                    property bool isFinished: true

                    width: listView.width - Tokens.padding.large
                    height: bubbleRect.height
                    
                    scale: 0.0
                    opacity: 0.0
                    
                    Component.onCompleted: {
                        popInAnim.start();
                    }
                    
                    ParallelAnimation {
                        id: popInAnim
                        NumberAnimation { target: delegateItem; property: "scale"; from: 0.8; to: 1.0; duration: 300; easing.type: Easing.OutBack }
                        NumberAnimation { target: delegateItem; property: "opacity"; from: 0.0; to: 1.0; duration: 200; easing.type: Easing.OutQuad }
                    }
                    
                    SequentialAnimation {
                        id: popDoneAnim
                        NumberAnimation { target: delegateItem; property: "scale"; from: 1.0; to: 1.05; duration: 150; easing.type: Easing.OutQuad }
                        NumberAnimation { target: delegateItem; property: "scale"; from: 1.05; to: 1.0; duration: 200; easing.type: Easing.OutBounce }
                    }
                    
                    onIsFinishedChanged: {
                        if (isFinished) popDoneAnim.start();
                    }

                    StyledRect {
                        id: bubbleRect

                        anchors.right: delegateItem.isUser ? parent.right : undefined
                        anchors.left: delegateItem.isUser ? undefined : parent.left
                        width: Math.min(delegateItem.width * 0.85, messageText.implicitWidth + Tokens.padding.medium * 2)
                        height: messageText.implicitHeight + Tokens.padding.medium * 2
                        radius: Tokens.rounding.large
                        color: delegateItem.isUser ? Colours.palette.m3primary : Colours.tPalette.m3surfaceContainerHigh

                        // Asymmetric corners
                        topLeftRadius: Tokens.rounding.large
                        topRightRadius: Tokens.rounding.large
                        bottomLeftRadius: delegateItem.isUser ? Tokens.rounding.large : 4
                        bottomRightRadius: delegateItem.isUser ? 4 : Tokens.rounding.large

                        TextEdit {
                            id: messageText

                            anchors.fill: parent
                            anchors.margins: Tokens.padding.medium
                            text: delegateItem.text
                            color: delegateItem.isUser ? Colours.palette.m3onPrimary : Colours.palette.m3onSurface
                            font: Tokens.font.body.small
                            wrapMode: Text.Wrap
                            readOnly: true
                            selectByMouse: true
                            selectionColor: Colours.palette.m3primary
                            selectedTextColor: Colours.palette.m3onPrimary

                            MouseArea {
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.IBeamCursor
                                propagateComposedEvents: true
                                onPressed: mouse => mouse.accepted = false
                            }
                        }
                    }
                }''')

with open(filepath, 'w') as f:
    f.writelines(lines)
