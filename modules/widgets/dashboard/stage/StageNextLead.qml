import QtQuick
import qs.modules.theme
import qs.modules.components.kit

// The leading item of NEXT as a bold card: an accent tint (Look.activeTint)
// with an accent bar at its start, the time or countdown in the display
// role, then the kind as a label (FOCUS, TIMER, ...; none when `kind` is
// empty), the title and when ("in 40 min", "remaining").
Item {
    id: root

    property string time: ""
    property string title: ""
    property string when: ""
    property string kind: ""
    property string icon: ""

    Rectangle {
        objectName: "nextLeadCard"
        anchors.fill: parent
        radius: Look.bigRadius(height)
        color: Look.alpha("primary", Look.activeTint)
    }

    Rectangle {
        id: bar
        x: Space.m
        anchors.verticalCenter: parent.verticalCenter
        width: Space.xs
        height: parent.height - Space.s * 2
        radius: width / 2
        color: Type.accent
    }

    KitText {
        id: time
        objectName: "nextTime"
        anchors.left: bar.right
        anchors.leftMargin: Space.m
        anchors.verticalCenter: parent.verticalCenter
        role: "display"
        font.pixelSize: Math.round(Type.size("title") * 1.6)
        tabular: true
        text: root.time
    }

    Column {
        anchors.left: time.right
        anchors.leftMargin: Space.l
        anchors.right: parent.right
        anchors.rightMargin: Space.m
        anchors.verticalCenter: parent.verticalCenter
        spacing: Space.xs / 2

        Row {
            spacing: Space.xs
            visible: root.kind !== ""

            Text {
                anchors.verticalCenter: parent.verticalCenter
                text: root.icon
                font.family: Icons.font
                font.pixelSize: Type.iconSize("label")
                color: Type.accent
            }

            KitText {
                anchors.verticalCenter: parent.verticalCenter
                role: "label"
                color: Type.accent
                text: root.kind
            }
        }

        KitText {
            objectName: "nextTitle"
            width: parent.width
            font.weight: Font.DemiBold
            elide: Text.ElideRight
            text: root.title
        }

        KitText {
            objectName: "nextWhen"
            width: parent.width
            role: "caption"
            elide: Text.ElideRight
            text: root.when
        }
    }
}
