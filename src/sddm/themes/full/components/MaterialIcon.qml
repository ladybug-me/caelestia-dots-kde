import QtQuick

Item {
    property alias color: icon.color
    property alias text: icon.text
    property alias pointSize: icon.font.pointSize

    Text {
        id: icon

        font.family: "Material Symbols Rounded"
        font.pointSize: 20
    }
}
