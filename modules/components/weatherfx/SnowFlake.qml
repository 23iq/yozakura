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

    // The fall steps on the shared weather clock (FrameUse): the resting
    // flake melts (1.6 s), then drifts down to its spot (2.2 s)
    property bool animate: false
    property string _phase: ""
    property real _t0: 0

    function fall(): void {
        if (root._phase !== "")
            return;
        if (root.settled) {
            root._phase = "melt";
            root._t0 = Date.now();
        } else {
            root._begin();
        }
    }

    function _begin(): void {
        root.settled = false;
        root.y = root.restY - root.d * 6;
        root.x = root.restX - root.d * 2;
        root.opacity = 1;
        root._phase = "fall";
        root._t0 = Date.now();
    }

    FrameUse {
        ticking: root.animate && root._phase !== ""
        onTick: now => {
            if (root._phase === "melt") {
                const p = Math.min(1, (now - root._t0) / Math.max(1, WeatherFx.ms(1600)));
                root.opacity = 1 - p;
                if (p >= 1)
                    root._begin();
            } else if (root._phase === "fall") {
                const p = Math.min(1, (now - root._t0) / Math.max(1, WeatherFx.ms(2200)));
                root.y = root.restY - root.d * 6 + root.d * 6 * (1 - (1 - p) * (1 - p));
                root.x = root.restX - root.d * 2 + root.d * 2 * (0.5 - 0.5 * Math.cos(Math.PI * p));
                if (p >= 1) {
                    root._phase = "";
                    root.settled = true;
                }
            }
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
