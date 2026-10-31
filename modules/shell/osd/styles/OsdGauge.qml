pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Shapes
import qs.modules.theme
import qs.modules.services
import qs.modules.shell.osd
import qs.modules.components.kit
import "../OsdStyles.js" as OsdStyles

// Gauge OSD: a small instrument on a floating kit Surface. A 240° dial with
// ticks every 5 % (long every 10 %) lit up to the level, the level as a
// thin progress arc and a needle (the accent: the live value) that swings
// to it; under the hub, the value in an inset well (segment digits where
// the language reads out in segments, Look.readout) and the kind label
// with its glyph. Muted: the needle drops to zero, the accent "Muted" label
// replaces the value. The device (muted, or just switched to) replaces the
// kind label.
// Same upright box on every edge.
Surface {
    id: root

    property string kind: "volume"
    property real value: 0
    property bool muted: false
    property string device: ""
    property string currentDevice: ""
    property bool vertical: false
    property bool shown: true
    readonly property var size: OsdStyles.sizeFor("gauge", root.vertical, Metrics.osdW)
    readonly property var readout: OsdStyles.readout(root.kind, root.value, root.muted, root.device, root.currentDevice, I18n.t("osd.muted"))
    readonly property real level: root.readout.level ? OsdStyles.clamp01(root.value) : 0
    // The drawn level: the needle swings, never jumps.
    property real needle: root.level
    readonly property real startAngle: 150
    readonly property real sweep: 240
    readonly property real dialR: root.width * 0.36
    readonly property point hub: Qt.point(root.width / 2, Space.l + root.dialR)
    readonly property bool segment: Look.readout === "segment"
    // The device under the value: the muted output, or the new one after a switch.
    readonly property string deviceLine: root.readout.caption !== "" ? root.readout.caption : (root.readout.accent ? "" : root.readout.title)

    padding: 0
    floating: true
    implicitWidth: root.size.w
    implicitHeight: root.size.h
    radius: Look.bigRadius(root.width)

    Behavior on needle {
        enabled: Motion.glide.duration > 0
        NumberAnimation {
            duration: Motion.glide.duration * 1.5
            easing.type: Motion.spring.easing
            easing.overshoot: 1.2
        }
    }

    function point(deg: real, r: real): point {
        const a = deg * Math.PI / 180;
        return Qt.point(root.hub.x + Math.cos(a) * r, root.hub.y + Math.sin(a) * r);
    }

    Shape {
        anchors.fill: parent
        preferredRendererType: Shape.CurveRenderer

        ShapePath {
            strokeColor: Type.track
            strokeWidth: Space.hairline * 2
            fillColor: "transparent"
            PathAngleArc {
                centerX: root.hub.x
                centerY: root.hub.y
                radiusX: root.dialR
                radiusY: root.dialR
                startAngle: root.startAngle
                sweepAngle: root.sweep
            }
        }

        ShapePath {
            strokeColor: root.needle > 0.005 ? Type.progress : "transparent"
            strokeWidth: Space.stroke
            fillColor: "transparent"
            capStyle: ShapePath.FlatCap
            PathAngleArc {
                centerX: root.hub.x
                centerY: root.hub.y
                radiusX: root.dialR
                radiusY: root.dialR
                startAngle: root.startAngle
                sweepAngle: root.sweep * root.needle
            }
        }
    }

    // Ticks inside the arc, lit up to the level.
    Repeater {
        model: 21

        Rectangle {
            id: tick
            required property int index
            readonly property bool major: tick.index % 2 === 0
            readonly property real deg: root.startAngle + root.sweep * tick.index / 20
            readonly property real len: tick.major ? Space.s : Space.xs
            readonly property point at: root.point(tick.deg, root.dialR - Space.xs - tick.len / 2 - Space.hairline)
            width: Space.hairline * (tick.major ? 2 : 1)
            height: tick.len
            x: tick.at.x - width / 2
            y: tick.at.y - height / 2
            rotation: tick.deg + 90
            antialiasing: true
            color: tick.index / 20 <= root.needle + 1e-6 && root.needle > 0.005 ? Type.secondary : Type.track
        }
    }

    // The needle: from just behind the hub to the ticks.
    Item {
        objectName: "gaugeNeedle"
        x: root.hub.x
        y: root.hub.y
        rotation: root.startAngle + root.sweep * root.needle

        Rectangle {
            x: -root.dialR * 0.14
            y: -height / 2
            width: root.dialR * 0.88
            height: Space.stroke - 1
            radius: height / 2
            antialiasing: true
            color: Type.accent
        }
    }

    Rectangle {
        objectName: "gaugeHub"
        width: Space.s + Space.xs
        height: width
        radius: width / 2
        x: root.hub.x - width / 2
        y: root.hub.y - height / 2
        color: Type.accent
        border.width: Space.hairline
        border.color: Look.groupShade.a > 0 ? Look.groupShade : Type.hairline
    }

    // The value window under the hub.
    Well {
        id: well
        objectName: "gaugeWell"
        width: root.dialR * 1.1
        height: Type.size("title") + Space.s * 2
        x: root.hub.x - width / 2
        y: root.hub.y + root.dialR * 0.3

        SegmentDigits {
            visible: root.segment && root.readout.value !== ""
            anchors.centerIn: parent
            text: ("   " + OsdStyles.percent(root.value)).slice(-3)
            digitHeight: Type.size("title")
            color: Type.text
        }

        KitText {
            visible: !root.segment || root.readout.value === ""
            anchors.centerIn: parent
            width: parent.width - Space.s
            horizontalAlignment: Text.AlignHCenter
            role: root.readout.value !== "" ? "title" : "secondary"
            tabular: true
            text: root.readout.value !== "" ? root.readout.value : root.readout.title
            color: root.readout.accent ? Type.accent : Type.text
            font.weight: Font.DemiBold
        }
    }

    // The kind (or, muted, the device) with its glyph.
    Row {
        anchors.horizontalCenter: parent.horizontalCenter
        y: well.y + well.height + Space.s
        spacing: Space.xs

        OsdGlyph {
            anchors.verticalCenter: parent.verticalCenter
            role: "caption"
            kind: root.kind
            value: root.value
            muted: root.muted
        }

        KitText {
            anchors.verticalCenter: parent.verticalCenter
            width: Math.min(implicitWidth, root.width - Space.xl * 2)
            role: root.deviceLine !== "" ? "caption" : "label"
            text: root.deviceLine !== "" ? root.deviceLine : I18n.t(OsdStyles.labelKey(root.kind))
        }
    }
}
