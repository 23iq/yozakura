import QtQuick
import qs.modules.theme
import qs.modules.components.kit

// One choice of a small picture strip (window corners, border widths, the
// scale steps of a display): a raised tile with its picture (default
// children, centred) and a caption; the chosen one is ringed in the accent
// and its caption takes the accent. Lifts its fill on hover.
Item {
    id: tile

    property bool chosen: false
    property string caption: ""
    default property alias picture: pictureBox.data
    readonly property bool hovered: area.containsMouse

    signal clicked

    implicitWidth: Space.controlL
    implicitHeight: Space.controlL + Space.l

    Mark {
        id: box
        width: parent.width
        height: parent.height - (tile.caption !== "" ? captionText.implicitHeight + Space.xs : 0)
        radius: Look.radius("box", height)
        color: Look.raisedFill(tile.hovered)
        border.width: tile.chosen ? Space.stroke - 1 : Space.hairline
        border.color: tile.chosen ? Type.accent : Type.hairline
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
    }
    KitText {
        id: captionText
        visible: tile.caption !== ""
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.bottom: parent.bottom
        role: "caption"
        font.weight: tile.chosen ? Type.weight("title") : Type.weight("caption")
        color: tile.chosen ? Type.accent : Type.secondary
        text: tile.caption
    }
    MouseArea {
        id: area
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onClicked: tile.clicked()
    }
}
