import QtQuick
import QtQuick.Shapes
import qs.config
import qs.modules.theme
import qs.modules.components.kit
import "BranchGeometry.js" as Geo

// One workspace on the branch: a closed bud (empty), a blossom with a petal
// per window, or the fully open accent blossom (active). Urgent nodes
// tremble; a closed window drops a petal. No motion when animations are off.
Item {
    id: root

    required property int index
    required property var slotData
    required property real slot
    required property string shape
    required property color tint
    required property color accent
    required property color accentInk
    required property color stem
    // Urgent workspaces: the stamen (and a bud) take this role, so they read
    // with motion off too.
    required property color alert
    // Bar background and its ink: urgency falls back to these when the alert
    // role does not contrast (Geo.readable).
    required property color ground
    required property color ink
    required property bool petalFall

    readonly property var state_: Geo.node(root.slotData)
    readonly property bool open: root.state_.kind === "open"
    readonly property bool animated: Config.animDuration > 0
    readonly property real half: root.slot / 2
    readonly property real len: Geo.bloomRadius(root.slot)
    readonly property color petalColor: root.open ? root.accent : root.tint
    readonly property color haloColor: Geo.readable(root.alert, root.ground, root.ink, root.accentInk)
    readonly property color alertCentre: Geo.readable(root.alert, root.petalColor, root.ink, root.ground)

    width: root.slot
    height: root.slot

    // Buds are kept for empty workspaces; they fade as the blossom opens.
    Shape {
        anchors.fill: parent
        preferredRendererType: Shape.CurveRenderer
        opacity: root.state_.kind === "bud" ? 1 : 0
        scale: opacity
        Behavior on opacity {
            enabled: root.animated
            NumberAnimation {
                duration: Motion.glide.duration
                easing.type: Motion.glide.easing
            }
        }
        ShapePath {
            strokeWidth: -1
            fillRule: ShapePath.WindingFill
            fillColor: root.state_.urgent ? root.alert : Qt.alpha(root.tint, 0.62)
            PathSvg {
                path: Geo.budPath(root.index, root.half, root.half, root.slot * 0.2)
            }
        }
    }

    Item {
        id: bloom
        anchors.fill: parent
        scale: root.state_.scale
        opacity: root.state_.kind === "bud" ? 0 : 1
        transformOrigin: Item.Center

        Behavior on scale {
            enabled: root.animated
            NumberAnimation {
                duration: Motion.glide.duration
                easing.type: Motion.spring.easing
                easing.overshoot: 1.6
            }
        }
        Behavior on opacity {
            enabled: root.animated
            NumberAnimation {
                duration: Motion.glide.duration
                easing.type: Motion.glide.easing
            }
        }

        Shape {
            anchors.fill: parent
            preferredRendererType: Shape.CurveRenderer
            // The positions still closed: a faint outline of the whole flower.
            ShapePath {
                strokeWidth: -1
                fillRule: ShapePath.WindingFill
                fillColor: Qt.alpha(root.tint, 0.2)
                PathSvg {
                    path: Geo.petalsPath(root.shape, root.index, root.state_.petals, Geo.MAX_PETALS, root.half, root.half, root.len)
                }
            }
            ShapePath {
                strokeWidth: -1
                fillRule: ShapePath.WindingFill
                fillColor: root.open ? root.petalColor : Qt.alpha(root.petalColor, 0.78)
                Behavior on fillColor {
                    enabled: root.animated
                    ColorAnimation {
                        duration: Motion.micro.duration
                    }
                }
                PathSvg {
                    path: Geo.petalsPath(root.shape, root.index, 0, root.state_.petals, root.half, root.half, root.len)
                }
            }
            // Urgent: a halo around the blossom, readable on any palette.
            ShapePath {
                strokeWidth: root.state_.urgent ? Geo.haloWidth(root.slot) : -1
                strokeColor: root.haloColor
                fillColor: "transparent"
                PathAngleArc {
                    centerX: root.half
                    centerY: root.half
                    radiusX: Geo.haloRadius(root.slot)
                    radiusY: Geo.haloRadius(root.slot)
                    sweepAngle: 360
                }
            }
            // Stamen: a small centre in the on-accent ink, the branch colour
            // on a plain blossom.
            ShapePath {
                strokeWidth: -1
                fillRule: ShapePath.WindingFill
                fillColor: root.state_.urgent ? root.alertCentre : (root.open ? root.accentInk : root.stem)
                PathAngleArc {
                    centerX: root.half
                    centerY: root.half
                    radiusX: root.len * 0.17
                    radiusY: root.len * 0.17
                    sweepAngle: 360
                }
            }
        }

        // Urgent: a gentle tremble in short bursts.
        SequentialAnimation on rotation {
            running: root.state_.urgent && root.animated
            loops: Animation.Infinite
            onRunningChanged: if (!running)
                bloom.rotation = 0
            NumberAnimation {
                to: -9
                duration: Motion.micro.duration
                easing.type: Easing.InOutSine
            }
            NumberAnimation {
                to: 9
                duration: Motion.micro.duration * 2
                easing.type: Easing.InOutSine
            }
            NumberAnimation {
                to: -5
                duration: Motion.micro.duration * 2
                easing.type: Easing.InOutSine
            }
            NumberAnimation {
                to: 0
                duration: Motion.micro.duration
                easing.type: Easing.InOutSine
            }
            PauseAnimation {
                duration: Motion.emphasis.duration * 2
            }
        }
    }

    // A window closed: its petal detaches and falls.
    property var previous: null
    onSlotDataChanged: {
        if (root.petalFall && root.animated && Geo.petalFalls(root.previous, root.slotData))
            fallen.drop(Math.min(root.slotData.windows, Geo.MAX_PETALS - 1));
        root.previous = root.slotData;
    }

    BranchPetal {
        id: fallen
        index: root.index
        slot: root.slot
        shape: root.shape
        color: root.petalColor
        scaleFrom: root.state_.scale > 0 ? root.state_.scale : 0.78
    }
}
