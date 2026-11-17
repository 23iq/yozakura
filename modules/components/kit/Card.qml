import QtQuick
import QtQuick.Effects
import qs.modules.theme
import qs.modules.components.kit

// A bento card: one surface (Look.cardFill: translucent over the window's
// Ambient in glass / ink, solid in the boxed languages; Look.radius("big"), a
// hairline edge, a soft shadow) holding a concept - an optional label
// (SectionLabel) over its content, laid out in a column. Visible in every
// visual language (unlike Group, which ink leaves unboxed), so a grid of
// cards reads as a bento. `interactive` makes the whole card a button:
// it lifts and brightens on hover (Motion.micro), springs on press
// (Motion.spring), reports the `pointer` over it, takes Tab focus with the FocusRing, `clicked()` on
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
    // an accent ring and glow (the thing the window is about, e.g. the hero tile)
    property bool accented: false
    // the shadow under the card (off for cards inside cards)
    property bool shadow: true
    property int padding: Look.boxPadding + Space.xs
    property int spacing: Space.m
    readonly property real radius: Look.radius("big", Space.controlXL)
    readonly property bool hovered: hover.hovered || root.highlighted
    readonly property real contentWidth: root.width - root.padding * 2
    // Where the pointer is over an interactive card, -1..1 on each axis
    // (0, 0 when it is away): for a picture that follows it (parallax).
    readonly property point pointer: hover.hovered && root.width > 0 && root.height > 0 ? Qt.point(hover.point.position.x / root.width * 2 - 1, hover.point.position.y / root.height * 2 - 1) : Qt.point(0, 0)
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

    // 0 at rest, 1 hovered (Motion.micro): the box rises, its shadow drops
    // further and softens with it, one curve for all three.
    property real lift: root.interactive && root.hovered && !area.pressed ? 1 : 0
    Behavior on lift {
        enabled: Motion.micro.duration > 0
        NumberAnimation {
            duration: Motion.micro.duration
            easing.type: Motion.micro.easing
        }
    }
    // The shadow fades in when it is turned on (a home tile turns its own
    // on after the first frame) instead of popping.
    property real shadowLevel: root.shadow && (root.fill || root.accented) ? 1 : 0
    Behavior on shadowLevel {
        enabled: Motion.glide.duration > 0
        NumberAnimation {
            duration: Motion.glide.duration
            easing.type: Motion.glide.easing
        }
    }

    // Hover of the whole card, controls inside it included (a MouseArea
    // loses containsMouse to the controls over it).
    HoverHandler {
        id: hover
        enabled: root.interactive
        cursorShape: Qt.PointingHandCursor
    }

    // Under the content: a control inside the card (a bar's remove button)
    // gets its own clicks instead of the card's.
    MouseArea {
        id: area
        anchors.fill: parent
        enabled: root.interactive
        onClicked: root.clicked()
    }

    // The box, lifted a little while hovered, pressed in on a press (sized
    // by binding, not anchors, so its y can move).
    Item {
        id: shell
        width: root.width
        height: root.height
        y: -Space.xs * root.lift
        scale: area.pressed ? 0.985 : 1
        Behavior on scale {
            enabled: Motion.spring.duration > 0
            NumberAnimation {
                duration: Motion.spring.duration
                easing.type: Motion.spring.easing
                easing.overshoot: Motion.spring.overshoot
            }
        }

        RectangularShadow {
            anchors.fill: parent
            visible: root.shadowLevel > 0
            opacity: root.shadowLevel
            radius: root.radius
            offset: Qt.vector2d(0, Space.xs + (Space.s - Space.xs) * root.lift)
            blur: Space.xl + (Space.xxl - Space.xl) * root.lift
            spread: 0
            color: root.accented ? Qt.alpha(Type.accent, 0.35) : Look.cardShadow
        }
        Mark {
            anchors.fill: parent
            visible: root.fill
            radius: root.radius
            color: Look.cardFill(root.interactive && root.hovered)
            border.width: Look.cardEdge.a > 0 ? Space.hairline : 0
            border.color: Look.cardEdge
            Behavior on color {
                enabled: Motion.micro.duration > 0
                ColorAnimation {
                    duration: Motion.micro.duration
                }
            }
        }
        // The language's edge light: a lit top edge (glass frost, device's
        // machined edge) and a dark lower edge (device's bevel).
        Mark {
            x: root.radius
            width: parent.width - root.radius * 2
            height: Space.hairline
            visible: root.fill && Look.cardHighlight.a > 0
            radius: 0
            color: Look.cardHighlight
        }
        Mark {
            x: root.radius
            y: parent.height - height
            width: parent.width - root.radius * 2
            height: Space.hairline
            visible: root.fill && Look.cardShade.a > 0
            radius: 0
            color: Look.cardShade
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

        // the accent ring, over the picture
        Mark {
            anchors.fill: parent
            visible: root.accented
            radius: root.radius
            color: "transparent"
            border.width: Space.stroke
            border.color: Type.accent
            z: 2
        }
        FocusRing {
            shown: root.activeFocus
            radius: root.radius + Space.stroke
        }
    }
}
