import QtQuick
import qs.modules.theme
import qs.modules.components.kit
import "../home/HomeModel.js" as HomeModel

// One app's notifications as a card on the raised surface: the app icon
// tile (kit Art: the icon or image, else the app's initial), the latest
// summary bold over its body, the count at the end. Hover shows the clear
// button; dragging the card sideways past a third of its width dismisses
// it (`dismissed()`), a shorter drag springs back.
Item {
    id: root

    property var row: ({})
    readonly property bool hovered: hover.hovered

    signal dismissed

    clip: false

    Item {
        id: card
        width: parent.width
        height: parent.height
        opacity: 1 - Math.min(0.7, Math.abs(card.x) / Math.max(1, root.width))

        Behavior on x {
            enabled: !drag.active && Motion.exit.duration > 0
            NumberAnimation {
                duration: Motion.spring.duration
                easing.type: Motion.spring.easing
                easing.overshoot: Motion.spring.overshoot
            }
        }

        Rectangle {
            anchors.fill: parent
            radius: Look.bigRadius(Space.controlL) / 1.5
            color: Look.raisedFill(root.hovered)
            border.width: Look.controlEdge.a > 0 ? Space.hairline : 0
            border.color: Look.controlEdge
        }

        Art {
            id: tile
            x: Space.s
            anchors.verticalCenter: parent.verticalCenter
            width: Space.controlS + Space.xs
            height: width
            source: HomeModel.avatarSource(root.row)
            fillMode: Image.PreserveAspectFit
            placeholderText: String(root.row.app || "?").charAt(0).toUpperCase()
        }

        Column {
            anchors.left: tile.right
            anchors.leftMargin: Space.m
            anchors.right: end.left
            anchors.rightMargin: Space.s
            anchors.verticalCenter: parent.verticalCenter
            spacing: 0

            KitText {
                width: parent.width
                font.weight: Font.DemiBold
                elide: Text.ElideRight
                text: root.row.summary || root.row.text || ""
            }

            KitText {
                width: parent.width
                visible: text !== ""
                role: "secondary"
                elide: Text.ElideRight
                text: root.row.body || ""
            }
        }

        Item {
            id: end
            anchors.right: parent.right
            anchors.rightMargin: Space.s
            anchors.verticalCenter: parent.verticalCenter
            width: Space.controlS
            height: width

            KitText {
                anchors.centerIn: parent
                visible: !root.hovered && (root.row.count || 0) > 1
                role: "caption"
                tabular: true
                font.weight: Font.DemiBold
                text: root.row.count || ""
            }

            IconButton {
                objectName: "clearGroup"
                anchors.fill: parent
                visible: root.hovered
                size: "s"
                icon: Icons.cancel
                onClicked: root.dismissed()
            }
        }

        DragHandler {
            id: drag
            target: card
            yAxis.enabled: false
            onActiveChanged: {
                if (drag.active)
                    return;
                if (Math.abs(card.x) > root.width / 3)
                    root.dismissed();
                else
                    card.x = 0;
            }
        }
    }

    HoverHandler {
        id: hover
    }
}
