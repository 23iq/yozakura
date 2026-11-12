import QtQuick
import qs.modules.theme
import qs.modules.components.kit

// A bento card: one raised box (Look.raisedFill, Look.bigRadius, the
// language's control edge) holding a concept - an optional label
// (SectionLabel) over its content, laid out in a column. Visible in every
// visual language (unlike Group, which ink leaves unboxed), so a grid of
// cards reads as a bento. `interactive` makes the whole card a button:
// it lifts and brightens on hover (Motion.micro), springs on press
// (Motion.spring), takes Tab focus with the FocusRing, `clicked()` on
// click / Enter / Space. `fill: false` drops the box (a picture tile that
// paints itself, `background` content under everything).
//
//   Card { label: "Edge"; Switch { ... } }
Item {
    id: root

    property string label: ""
    property bool interactive: false
    property bool highlighted: false
    property bool fill: true
    property int padding: Look.boxPadding + Space.xs
    property int spacing: Space.m
    readonly property real radius: Look.bigRadius(Space.controlXL)
    readonly property bool hovered: area.containsMouse || root.highlighted
    readonly property real contentWidth: root.width - root.padding * 2
    default property alias content: body.data
    // Painted under the label and content, clipped to the card (a picture).
    property alias background: backdrop.data

    signal clicked

    implicitWidth: body.implicitWidth + root.padding * 2
    implicitHeight: body.implicitHeight + root.padding * 2
    activeFocusOnTab: root.interactive
    Keys.onReturnPressed: if (root.interactive)
        root.clicked()
    Keys.onSpacePressed: if (root.interactive)
        root.clicked()

    Accessible.role: root.interactive ? Accessible.Button : Accessible.Grouping
    Accessible.name: root.label

    // The box, lifted a little while hovered, pressed in on a press.
    Item {
        id: shell
        anchors.fill: parent
        y: root.interactive && root.hovered && !area.pressed ? -Space.hairline * 2 : 0
        scale: area.pressed ? 0.985 : 1
        Behavior on y {
            enabled: Motion.micro.duration > 0
            NumberAnimation {
                duration: Motion.micro.duration
                easing.type: Motion.micro.easing
            }
        }
        Behavior on scale {
            enabled: Motion.spring.duration > 0
            NumberAnimation {
                duration: Motion.spring.duration
                easing.type: Motion.spring.easing
                easing.overshoot: Motion.spring.overshoot
            }
        }

        Mark {
            anchors.fill: parent
            visible: root.fill
            radius: root.radius
            color: Look.raisedFill(root.interactive && root.hovered)
            border.width: Look.controlEdge.a > 0 ? Space.hairline : 0
            border.color: Look.controlEdge
            Behavior on color {
                enabled: Motion.micro.duration > 0
                ColorAnimation {
                    duration: Motion.micro.duration
                }
            }
        }
        Item {
            id: backdrop
            anchors.fill: parent
        }

        Column {
            id: body
            x: root.padding
            y: root.padding
            width: root.contentWidth
            spacing: root.spacing

            SectionLabel {
                width: parent.width
                inset: 0
                visible: root.label !== ""
                text: root.label
            }
        }

        FocusRing {
            shown: root.activeFocus
            radius: root.radius + Space.stroke
        }
    }

    MouseArea {
        id: area
        anchors.fill: parent
        enabled: root.interactive
        hoverEnabled: root.interactive
        cursorShape: root.interactive ? Qt.PointingHandCursor : Qt.ArrowCursor
        onClicked: root.clicked()
    }
}
