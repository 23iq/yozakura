import QtQuick
import qs.config
import qs.modules.theme
import qs.modules.components
import qs.modules.bar

// One live activity island. The item is the island body; how it looks and
// grows depends on `mode` (see ActivityLayout.placement):
//   "tab"      notch-shaped tab with concave fillets, grows out of the edge
//   "pill"     module-like pill inside a classic bar
//   "floating" free pill matching the floating ("island") notch theme
// `shown` drives the grow/retract animation (notch timing); `presence` is
// the animated 0..1 value, and `retracted()` fires when it reaches 0.
Item {
    id: island

    property string mode: "tab"
    property string edge: "top"
    property bool shown: false
    property real thickness: 32
    property real fillet: 0
    property real cornerRadius: 0
    property real hPadding: 10
    property string tooltip: ""

    default property alias content: contentHolder.data
    property Item contentItem: null

    signal clicked(int button)
    signal retracted

    readonly property bool tab: mode === "tab"
    readonly property real bodyLength: (contentItem ? contentItem.implicitWidth : 0) + hPadding * 2
    // Full horizontal footprint, fillets included
    readonly property real footprint: bodyLength + (tab ? fillet * 2 : 0)
    readonly property bool hovered: mouse.containsMouse

    property real presence: shown ? 1 : 0
    Behavior on presence {
        enabled: Config.animDuration > 0
        NumberAnimation {
            duration: island.shown ? Config.animDuration : Math.round(Config.animDuration * 0.6)
            easing.type: island.shown ? Motion.enter.easing : Motion.exit.easing
            easing.overshoot: 1.15
        }
    }
    onPresenceChanged: if (presence <= 0 && !shown)
        retracted()

    readonly property real grow: Math.max(0, Math.min(1, presence))

    width: bodyLength
    height: thickness
    visible: presence > 0.001

    // ── tab: notch silhouette growing out of the edge ──
    IslandShape {
        id: shape
        visible: island.tab
        z: -1
        edge: island.edge
        bodyLength: island.bodyLength
        bodyThickness: island.thickness * Math.max(0, island.presence)
        fillet: island.fillet * island.grow
        bodyRadius: Math.min(island.cornerRadius, island.thickness * Math.max(0, island.presence) / 2)
        x: -shape.bodyOffset
        y: island.edge === "bottom" ? island.height - shape.localHeight : 0
    }

    // ── pill / floating: themed pill that pops from the edge ──
    StyledRect {
        id: pill
        visible: !island.tab
        variant: "bg"
        anchors.fill: parent
        radius: island.cornerRadius
        animateRadius: false
        transformOrigin: island.edge === "bottom" ? Item.Bottom : Item.Top
        scale: 0.6 + 0.4 * island.grow
        opacity: island.grow
    }

    // Hover feedback, like the bar's toggle buttons
    Rectangle {
        anchors.fill: parent
        visible: island.presence > 0.99
        color: Styling.srItem("bg")
        opacity: mouse.pressed ? 0.2 : (island.hovered ? 0.1 : 0)
        topLeftRadius: island.tab && island.edge === "top" ? 0 : island.cornerRadius
        topRightRadius: island.tab && island.edge === "top" ? 0 : island.cornerRadius
        bottomLeftRadius: island.tab && island.edge === "bottom" ? 0 : island.cornerRadius
        bottomRightRadius: island.tab && island.edge === "bottom" ? 0 : island.cornerRadius
        Behavior on opacity {
            enabled: Config.animDuration > 0
            NumberAnimation {
                duration: Motion.exit.duration
            }
        }
    }

    // Content slides out of the edge with the body
    Item {
        id: clipper
        anchors.fill: parent
        clip: island.presence < 1
        opacity: island.tab ? Math.min(1, island.grow * 1.6) : island.grow

        Item {
            id: contentHolder
            width: parent.width
            height: parent.height
            y: (island.tab ? (island.edge === "bottom" ? 1 : -1) * island.height * (1 - Math.min(1, island.presence)) : 0)
        }
    }

    MouseArea {
        id: mouse
        anchors.fill: parent
        enabled: island.shown
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        acceptedButtons: Qt.LeftButton | Qt.RightButton | Qt.MiddleButton
        onClicked: event => island.clicked(event.button)
    }

    StyledToolTip {
        show: island.hovered && island.shown
        tooltipText: island.tooltip
    }
}
