import QtQuick
import qs.modules.theme

// Heat on the bar (theme.weatherFx.heat, above 30 °C): every few seconds a
// faint shimmer wave passes through the strip (heat.frag). Between waves the
// shader is hidden, so nothing renders; with motion off one still frame of
// the shimmer stays.
ShaderEffect {
    id: root

    property real level: 0.5
    property bool animate: false
    property real strength: 1

    property real phase: 1.3
    property real amp: root.animate ? 0 : 0.6
    property real aspect: root.height > 0 ? root.width / root.height : 1
    readonly property color _tint: Qt.tint(WeatherFx.glint, Qt.alpha(WeatherFx.warm, 0.45))
    property vector4d tint: Qt.vector4d(root._tint.r, root._tint.g, root._tint.b, Math.min(0.5, (0.13 + 0.1 * root.level) * root.strength))

    visible: root.amp > 0.001
    blending: true
    fragmentShader: "heat.frag.qsb"

    Timer {
        objectName: "heatTimer"
        running: root.animate
        repeat: true
        interval: WeatherFx.cadence("heat", root.level)
        onTriggered: wave.restart()
    }

    ParallelAnimation {
        id: wave
        SequentialAnimation {
            NumberAnimation {
                target: root
                property: "amp"
                from: 0
                to: 1
                duration: WeatherFx.ms(1400)
                easing.type: Easing.InOutSine
            }
            NumberAnimation {
                target: root
                property: "amp"
                to: 0
                duration: WeatherFx.ms(2200)
                easing.type: Easing.InOutSine
            }
        }
        NumberAnimation {
            target: root
            property: "phase"
            from: 0
            to: 3.6
            duration: WeatherFx.ms(3600)
        }
    }
}
