pragma ComponentBehavior: Bound

import QtQuick
import qs.modules.theme
import qs.modules.services
import qs.modules.components.kit

// Direct manipulation on a screen miniature: the edges of the tiny screen
// are targets. Hovering an edge in `edges` other than `current` shows a
// ghost of the part there ("Move here"); a click emits `picked(edge)`.
// Hovering `current` shows nothing (it is already there); `busy` edges
// (another part sits there) light up without a ghost, the owner decides
// what a click on them means (e.g. pick that bar). Lives in a ScreenMini
// overlay (screen coordinates), over the parts it moves.
Item {
    id: picker

    property var edges: ["top", "bottom", "left", "right"]
    property string current: ""
    property var busy: []
    // How deep a target strip reaches into the screen, and the ghost's
    // thickness.
    property real reach: Space.px(28)
    property real ghostThickness: Space.px(14)
    // Share of the edge the ghost covers (a bar 1, a dock less), centred.
    property real ghostSpan: 1
    property string hint: I18n.t("prefs.home.move_here")
    // An edge shown as hovered without a pointer (renders, tests).
    property string preview: ""
    readonly property string hovered: {
        if (picker.preview)
            return picker.preview;
        for (let i = 0; i < strips.count; i++) {
            const s = strips.itemAt(i) as Item;
            if (s && (s as EdgeStrip).containsMouse)
                return (s as EdgeStrip).edge;
        }
        return "";
    }
    signal picked(string edge)

    anchors.fill: parent

    component EdgeStrip: MouseArea {
        id: strip
        required property string modelData
        readonly property string edge: modelData
        readonly property bool vertical: edge === "left" || edge === "right"
        x: edge === "right" ? picker.width - picker.reach : 0
        y: edge === "bottom" ? picker.height - picker.reach : 0
        width: vertical ? picker.reach : picker.width
        height: vertical ? picker.height : picker.reach
        hoverEnabled: true
        cursorShape: strip.edge === picker.current ? Qt.ArrowCursor : Qt.PointingHandCursor
        onClicked: {
            if (strip.edge !== picker.current)
                picker.picked(strip.edge);
        }
    }

    // The ghost of the part on the hovered edge.
    Mark {
        id: ghost
        readonly property string edge: picker.hovered
        readonly property bool vertical: edge === "left" || edge === "right"
        readonly property bool shown: edge !== "" && edge !== picker.current && picker.busy.indexOf(edge) < 0
        readonly property real inset: Space.s
        x: vertical ? (edge === "right" ? picker.width - picker.ghostThickness - inset : inset) : (picker.width - width) / 2
        y: vertical ? (picker.height - height) / 2 : (edge === "bottom" ? picker.height - picker.ghostThickness - inset : inset)
        width: vertical ? picker.ghostThickness : (picker.width - inset * 2) * picker.ghostSpan
        height: vertical ? (picker.height - inset * 2) * picker.ghostSpan : picker.ghostThickness
        radius: picker.ghostThickness / 2
        color: Qt.alpha(Type.accent, 0.28)
        border.width: Space.hairline
        border.color: Type.accent
        opacity: shown ? 1 : 0
        scale: shown ? 1 : 0.96
        Behavior on opacity {
            NumberAnimation {
                duration: Motion.micro.duration
                easing.type: Motion.micro.easing
            }
        }
        Behavior on scale {
            NumberAnimation {
                duration: Motion.micro.duration
                easing.type: Motion.micro.easing
            }
        }
    }

    // "Move here", beside the ghost, inside the screen.
    Chip {
        readonly property string edge: ghost.edge
        visible: ghost.shown
        dense: true
        active: true
        text: picker.hint
        x: edge === "left" ? ghost.x + ghost.width + Space.s : edge === "right" ? ghost.x - width - Space.s : (picker.width - width) / 2
        y: edge === "top" ? ghost.y + ghost.height + Space.s : edge === "bottom" ? ghost.y - height - Space.s : (picker.height - height) / 2
    }

    // The targets, over the ghost and its label.
    Repeater {
        id: strips
        model: picker.edges
        delegate: EdgeStrip {}
    }
}
