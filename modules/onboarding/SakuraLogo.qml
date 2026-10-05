pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Shapes
import qs.modules.theme
import qs.config

// The five-petal blossom of the app icon, drawn as five rotated copies of
// one petal so it can bloom: petals unfold one after another, then a soft
// halo breathes once. `play()` restarts it; animDuration 0 shows it open.
Item {
    id: root

    property real size: 160
    property color color: Colors.primary
    // Petal base: the primary lifted towards the lighter palette end (a soft
    // blossom in light and dark schemes alike).
    readonly property color lift: Config.lightMode ? Colors.background : Colors.overBackground
    property color accent: Qt.rgba(color.r + (lift.r - color.r) * 0.5, color.g + (lift.g - color.g) * 0.5, color.b + (lift.b - color.b) * 0.5, 1)
    // 0 = closed bud, 1 = open blossom (animated by play()).
    property real bloom: Config.animDuration > 0 ? 0 : 1
    property real halo: 0

    implicitWidth: size
    implicitHeight: size

    // One petal of the icon (24x24 view box, centred on 12,12).
    readonly property string petal: "M 12.00 9.30 C 9.10 8.40 6.80 5.60 7.70 2.60 C 8.20 0.90 9.90 0.10 11.00 0.40 L 12.00 1.90 L 13.00 0.40 C 14.10 0.10 15.80 0.90 16.30 2.60 C 17.20 5.60 14.90 8.40 12.00 9.30 Z"

    function play() {
        if (Config.animDuration <= 0) {
            bloom = 1;
            halo = 0;
            return;
        }
        anim.restart();
    }

    Component.onCompleted: play()

    SequentialAnimation {
        id: anim
        PropertyAction {
            target: root
            property: "bloom"
            value: 0
        }
        PauseAnimation {
            duration: 120
        }
        NumberAnimation {
            target: root
            property: "bloom"
            to: 1
            duration: Math.max(900, Config.animDuration * 4)
            easing.type: Easing.OutCubic
        }
        NumberAnimation {
            target: root
            property: "halo"
            from: 0
            to: 1
            duration: Math.max(500, Config.animDuration * 2)
            easing.type: Easing.OutSine
        }
        NumberAnimation {
            target: root
            property: "halo"
            to: 0
            duration: Math.max(900, Config.animDuration * 3)
            easing.type: Easing.InOutSine
        }
    }

    // Halo behind the blossom.
    Rectangle {
        anchors.centerIn: parent
        width: root.size * (0.9 + root.halo * 0.35)
        height: width
        radius: width / 2
        color: root.color
        opacity: root.halo * 0.16
        visible: opacity > 0
    }

    Repeater {
        model: 5
        delegate: Item {
            id: petalItem
            required property int index
            // Staggered: petal i opens over its own slice of `bloom`.
            readonly property real t: Math.max(0, Math.min(1, root.bloom * 1.6 - index * 0.15))
            width: root.size
            height: root.size
            anchors.centerIn: parent
            rotation: index * 72 - (1 - t) * 40
            opacity: t
            scale: 0.55 + t * 0.45

            Shape {
                width: 24
                height: 24
                anchors.centerIn: parent
                scale: root.size / 24
                preferredRendererType: Shape.CurveRenderer
                ShapePath {
                    strokeWidth: -1
                    fillGradient: LinearGradient {
                        x1: 12
                        y1: 9.3
                        x2: 12
                        y2: 0.2
                        GradientStop {
                            position: 0
                            color: root.accent
                        }
                        GradientStop {
                            position: 1
                            color: root.color
                        }
                    }
                    PathSvg {
                        path: root.petal
                    }
                }
            }
        }
    }
}
