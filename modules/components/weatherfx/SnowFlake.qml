import QtQuick
import qs.modules.theme

// One snowflake for SnowLine: drifts down onto its resting spot along the top
// edge of a surface and stays; a flake already resting melts first.
Item {
    id: root

    property real d: 3
    property real restX: 0
    property real restY: 0
    property real strength: 1
    property bool settled: false

    width: root.d
    height: root.d
    x: root.restX
    y: root.restY
    opacity: root.settled ? 1 : 0

    function a(v: real): real {
        return Math.min(1, v * root.strength);
    }

    function fall(): void {
        if (drop.running)
            return;
        drop.start();
    }

    SequentialAnimation {
        id: drop
        // Melt the flake resting here
        NumberAnimation {
            target: root
            property: "opacity"
            to: 0
            duration: root.settled ? WeatherFx.ms(1600) : 0
        }
        ScriptAction {
            script: {
                root.settled = false;
                root.y = root.restY - root.d * 6;
                root.x = root.restX - root.d * 2;
                root.opacity = 1;
            }
        }
        ParallelAnimation {
            NumberAnimation {
                target: root
                property: "y"
                to: root.restY
                duration: WeatherFx.ms(2200)
                easing.type: Easing.OutQuad
            }
            NumberAnimation {
                target: root
                property: "x"
                to: root.restX
                duration: WeatherFx.ms(2200)
                easing.type: Easing.InOutSine
            }
        }
        ScriptAction {
            script: root.settled = true
        }
    }

    // Soft halo, then the flake
    Rectangle {
        anchors.centerIn: parent
        width: root.d * 2.2
        height: width
        radius: width / 2
        color: Qt.alpha(WeatherFx.ice, root.a(0.18))
    }
    Rectangle {
        anchors.fill: parent
        radius: width / 2
        color: Qt.alpha(WeatherFx.glint, root.a(0.78))
    }
}
