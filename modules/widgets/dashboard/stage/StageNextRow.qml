import QtQuick
import qs.modules.theme
import qs.modules.components.kit

// A following item of NEXT: an icon tile (kit Art placeholder with the
// kind's glyph), the title over when it is, the time at the end. Hover
// shows the language's row box.
Item {
    id: root

    property string time: ""
    property string title: ""
    property string when: ""
    property string icon: ""

    Rectangle {
        anchors.fill: parent
        radius: Look.chipRadius(height)
        color: Look.raisedFill(true)
        visible: hover.hovered
    }

    HoverHandler {
        id: hover
    }

    Art {
        id: tile
        x: Space.xs
        anchors.verticalCenter: parent.verticalCenter
        width: Space.controlS
        height: width
        icon: root.icon
    }

    Column {
        anchors.left: tile.right
        anchors.leftMargin: Space.m
        anchors.right: time.left
        anchors.rightMargin: Space.m
        anchors.verticalCenter: parent.verticalCenter
        spacing: 0

        KitText {
            objectName: "nextTitle"
            width: parent.width
            elide: Text.ElideRight
            font.weight: Font.DemiBold
            text: root.title
        }

        KitText {
            width: parent.width
            visible: text !== ""
            role: "caption"
            elide: Text.ElideRight
            text: root.when
        }
    }

    KitText {
        id: time
        objectName: "nextTime"
        anchors.right: parent.right
        anchors.rightMargin: Space.s
        anchors.verticalCenter: parent.verticalCenter
        role: "secondary"
        tabular: true
        font.weight: Font.DemiBold
        text: root.time
    }
}
