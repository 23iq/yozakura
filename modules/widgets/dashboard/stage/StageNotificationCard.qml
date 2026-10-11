import QtQuick
import qs.modules.theme
import qs.modules.components.kit
import "../home/HomeModel.js" as HomeModel

// One app's notifications as a card on the raised surface: the app icon
// tile (kit Art: the icon or image, else the app's initial), the latest
// summary bold over its body, the count at the end. Hover shows the clear
// button; dragging the card sideways past a third of its width dismisses
// it (`dismissed()`), a shorter drag springs back. Dismissing (swipe,
// clear, Delete) slides the card out first. `live` is the app's current
// row; `row` keeps the last non-empty one while the card animates away.
// Keyboard: focusable, Delete / Backspace dismiss, the ring fades in.
Item {
    id: root

    property var live: ({})
    property var row: ({})
    readonly property bool hovered: hover.hovered || root.activeFocus
    readonly property real radius: Look.chipRadius(root.height)

    signal dismissed

    // Slide out to the side it was pushed to, then report.
    function dismiss(sign: real) {
        if (out.running)
            return;
        out.to = (sign < 0 ? -1 : 1) * root.width;
        if (Motion.glide.duration > 0)
            out.restart();
        else
            root.dismissed();
    }

    onLiveChanged: if (root.live && root.live.ids && root.live.ids.length > 0)
        root.row = root.live
    Component.onCompleted: root.row = root.live || {}

    activeFocusOnTab: true
    Keys.onPressed: event => {
        if (event.key === Qt.Key_Delete || event.key === Qt.Key_Backspace) {
            root.dismiss(1);
            event.accepted = true;
        }
    }

    NumberAnimation {
        id: out
        target: card
        property: "x"
        duration: Motion.glide.duration
        easing.type: Motion.exit.easing
        onFinished: root.dismissed()
    }

    clip: false

    Item {
        id: card
        width: parent.width
        height: parent.height
        opacity: 1 - Math.min(0.7, Math.abs(card.x) / Math.max(1, root.width))

        Behavior on x {
            enabled: !drag.active && !out.running && Motion.spring.duration > 0
            NumberAnimation {
                duration: Motion.spring.duration
                easing.type: Motion.spring.easing
                easing.overshoot: Motion.spring.overshoot
            }
        }

        Rectangle {
            anchors.fill: parent
            radius: root.radius
            color: Look.raisedFill(root.hovered)
            border.width: Look.controlEdge.a > 0 ? Space.hairline : 0
            border.color: Look.controlEdge
        }

        Art {
            id: tile
            x: Space.s
            anchors.verticalCenter: parent.verticalCenter
            width: Space.controlS
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
                onClicked: root.dismiss(1)
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
                    root.dismiss(card.x);
                else
                    card.x = 0;
            }
        }
    }

    HoverHandler {
        id: hover
    }

    FocusRing {
        radius: root.radius + Space.stroke
        shown: root.activeFocus
    }
}
