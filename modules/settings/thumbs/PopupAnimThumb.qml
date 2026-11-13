pragma ComponentBehavior: Bound

import QtQuick
import qs.modules.theme
import qs.modules.components.kit

// Card picture of how a popup opens (theme.popup.entry): a bar with the
// chip that opened it and the popup caught mid-way, its earlier frames
// faint behind it: fading in from smaller, sliding down from its anchor,
// growing out of the bar chip, or unfolding from its top edge.
MiniScreen {
    id: root

    property var entry
    property var value: "fade-scale"
    readonly property real barH: Math.round(root.height * 0.16)
    readonly property real popW: Math.round(root.width * 0.46)
    readonly property real popH: Math.round(root.height * 0.46)
    readonly property real popX: Math.round(root.width * 0.3)
    readonly property real popY: root.barH + Math.round(root.height * 0.08)

    // the bar and the chip the popup opens from
    Mark {
        width: parent.width
        height: root.barH
        radius: 0
        color: Colors.surfaceContainer
        Mark {
            id: chip
            x: root.popX + root.popW * 0.35
            anchors.verticalCenter: parent.verticalCenter
            width: root.popW * 0.3
            height: parent.height * 0.56
            color: Qt.alpha(Type.accent, 0.85)
        }
    }

    // earlier frames: faint copies on the way in
    Repeater {
        model: root.value === "slide-from-anchor" ? [0.18, 0.36] : (root.value === "fade-scale" ? [0.8] : [])
        delegate: Mark {
            required property real modelData
            x: root.value === "fade-scale" ? root.popX + root.popW * (1 - modelData) / 2 : root.popX
            y: root.value === "fade-scale" ? root.popY + root.popH * (1 - modelData) / 2 : root.popY - root.popH * modelData
            width: root.value === "fade-scale" ? root.popW * modelData : root.popW
            height: root.value === "fade-scale" ? root.popH * modelData : root.popH
            radius: Look.radius("box", height)
            color: Qt.alpha(Colors.surfaceContainerHigh, 0.35)
        }
    }

    // morph: the popup grows out of the chip (a neck joins them)
    Mark {
        visible: root.value === "morph-from-bar"
        x: chip.x
        y: root.barH * 0.7
        width: chip.width
        height: root.popY - y + Space.xs
        radius: 0
        color: Colors.surfaceContainerHigh
    }

    // the popup, mid-way
    Mark {
        id: popup
        x: root.popX
        y: root.popY
        width: root.popW
        height: root.value === "unfold" ? root.popH * 0.6 : root.popH
        radius: Look.radius("box", root.popH)
        color: Colors.surfaceContainerHigh
        border.width: Space.hairline
        border.color: Qt.alpha(Colors.overBackground, 0.28)
        opacity: root.value === "fade-scale" ? 0.85 : 1
        Column {
            x: Space.s
            y: Space.s
            spacing: Space.xs
            Repeater {
                model: [0.7, 0.5, 0.6]
                delegate: Mark {
                    required property real modelData
                    width: popup.width * modelData
                    height: Space.xs
                    color: Qt.alpha(Colors.overBackground, 0.55)
                }
            }
        }
    }
    // unfold: the part still folding, lighter, under a fold line
    Mark {
        visible: root.value === "unfold"
        x: root.popX
        y: popup.y + popup.height
        width: root.popW
        height: root.popH * 0.22
        radius: 0
        color: Qt.alpha(Colors.surfaceContainerHigh, 0.5)
        Mark {
            width: parent.width
            height: Space.hairline
            radius: 0
            color: Qt.alpha(Colors.overBackground, 0.4)
        }
    }
}
