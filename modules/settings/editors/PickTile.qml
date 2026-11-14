import QtQuick
import qs.modules.theme
import qs.modules.components.kit

// One choice of a small picture strip (window corners, border widths, the
// scale steps of a display): a raised tile with its picture (default
// children, centred) and a caption under it. The same marks as every
// picture choice (ChoiceCard): the chosen one ringed in the accent inside
// its edge, a check badge in its corner and its caption in the text colour
// and the active weight. Lifts its fill on hover; Tab focus, Space / Enter.
Item {
    id: tile

    property bool chosen: false
    property string caption: ""
    default property alias picture: pictureBox.data
    readonly property bool hovered: area.containsMouse

    signal clicked

    implicitWidth: Space.controlL
    implicitHeight: Space.controlL + Space.l
    activeFocusOnTab: true
    Keys.onSpacePressed: tile.clicked()
    Keys.onReturnPressed: tile.clicked()
    Accessible.role: Accessible.RadioButton
    Accessible.name: tile.caption
    Accessible.checked: tile.chosen

    Mark {
        id: box
        width: parent.width
        height: parent.height - (tile.caption !== "" ? captionText.implicitHeight + Space.s : 0)
        radius: Look.radius("control", Space.controlL)
        color: Look.raisedFill(tile.hovered)
        border.width: tile.chosen ? Space.stroke : Space.hairline
        border.color: tile.chosen ? Type.accent : (tile.hovered ? Type.track : Type.hairline)
        Behavior on color {
            enabled: Motion.micro.duration > 0
            ColorAnimation {
                duration: Motion.micro.duration
            }
        }
        Item {
            id: pictureBox
            anchors.fill: parent
            anchors.margins: Space.s
            clip: true
        }
        // the chosen one's check badge (ChoiceCard's; a tile too narrow
        // for it keeps the ring and the caption)
        Mark {
            objectName: "choiceBadge"
            visible: tile.chosen && box.width >= width * 3
            width: Math.round(Type.iconSize("caption") * 1.4)
            height: width
            // on the corner, mostly outside the picture (ChoiceCard's)
            x: parent.width - width * 0.65
            y: -width * 0.35
            z: 2
            color: Type.accent
            border.width: Space.stroke - 1
            border.color: Qt.rgba(Look.cardFill(false).r, Look.cardFill(false).g, Look.cardFill(false).b, 1)
            Icon {
                anchors.centerIn: parent
                icon: Icons.accept
                role: "caption"
                tone: "accentInk"
            }
        }
        FocusRing {
            shown: tile.activeFocus
            anchors.margins: -Space.stroke * 2
            radius: box.radius + Space.stroke * 2
        }
    }
    KitText {
        id: captionText
        visible: tile.caption !== ""
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.bottom: parent.bottom
        role: "secondary"
        font.weight: tile.chosen ? Look.activeLabelWeight : Look.labelWeight
        color: tile.chosen ? Type.text : Type.secondary
        text: tile.caption
    }
    MouseArea {
        id: area
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onClicked: {
            tile.forceActiveFocus();
            tile.clicked();
        }
    }
}
