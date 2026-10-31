pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Shapes
import qs.modules.theme

// Fog on a surface (theme.weatherFx.fog): a soft haze rising from the bottom
// edge and a few wide, very faint banks of mist. Static once it has faded in
// (the fade steps on WeatherFx.frame).
Item {
    id: root

    property real level: 0.6
    property real strength: 1
    property bool animate: false
    property int salt: 0
    property real radius: 0

    readonly property real k: Math.min(1, root.level * root.strength)
    readonly property var banks: {
        const r = WeatherFx.rng(root.salt + 41);
        const out = [];
        for (let i = 0; i < 3; i++)
            out.push({
                x: (i + 0.15 + r() * 0.7) / 3,
                y: 0.35 + r() * 0.65,
                s: 0.7 + r() * 0.6
            });
        return out;
    }

    // Fades in over 1.6 s on the shared weather clock
    property real _t0: 0
    property bool _fading: false
    opacity: 0
    Component.onCompleted: {
        if (root.animate && WeatherFx.motionOn) {
            root._t0 = Date.now();
            root._fading = true;
        } else {
            root.opacity = 1;
        }
    }
    FrameUse {
        ticking: root._fading && root.animate
        onTick: now => {
            const p = Math.min(1, (now - root._t0) / Math.max(1, WeatherFx.ms(1600)));
            root.opacity = p;
            if (p >= 1)
                root._fading = false;
        }
    }

    Rectangle {
        anchors.fill: parent
        radius: root.radius
        gradient: Gradient {
            GradientStop {
                position: 0
                color: Qt.alpha(WeatherFx.mist, 0.03 * root.k * WeatherFx.mistGain)
            }
            GradientStop {
                position: 1
                color: Qt.alpha(WeatherFx.mist, 0.16 * root.k * WeatherFx.mistGain)
            }
        }
    }

    Repeater {
        model: root.banks
        Shape {
            id: bank
            required property var modelData
            readonly property real rx: Math.max(root.height * 1.2, root.width * 0.28) * bank.modelData.s
            readonly property real ry: Math.max(root.height * 0.5, Math.min(root.height, root.width) * 0.35) * bank.modelData.s
            // A circle squashed into a wide bank (keeps the gradient soft
            // all the way to the edge)
            x: root.width * bank.modelData.x - bank.rx
            y: root.height * bank.modelData.y - bank.rx
            width: bank.rx * 2
            height: bank.rx * 2
            transform: Scale {
                origin.x: bank.rx
                origin.y: bank.rx
                yScale: bank.ry / bank.rx
            }

            ShapePath {
                strokeWidth: 0
                strokeColor: "transparent"
                fillGradient: RadialGradient {
                    centerX: bank.rx
                    centerY: bank.rx
                    centerRadius: bank.rx
                    focalX: bank.rx
                    focalY: bank.rx
                    GradientStop {
                        position: 0
                        color: Qt.alpha(WeatherFx.mist, 0.12 * root.k * WeatherFx.mistGain)
                    }
                    GradientStop {
                        position: 0.6
                        color: Qt.alpha(WeatherFx.mist, 0.05 * root.k * WeatherFx.mistGain)
                    }
                    GradientStop {
                        position: 1
                        color: Qt.alpha(WeatherFx.mist, 0)
                    }
                }
                PathAngleArc {
                    centerX: bank.rx
                    centerY: bank.rx
                    radiusX: bank.rx
                    radiusY: bank.rx
                    startAngle: 0
                    sweepAngle: 360
                }
            }
        }
    }
}
