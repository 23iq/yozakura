import QtQuick
import qs.modules.theme

// One rain drop resting on a surface (RainBeads). Drawn per language
// (WeatherFx.drop): "bead" a refracting glass bead (dark contact side, bright
// caustic at the bottom, specular dot), "flat" a solid tile dot, "glint" a
// tiny highlight with a hairline for languages without glass. `run()` lets it
// slide down in stick-slip steps, leaving a fading trail, then a new drop
// lands elsewhere (`respawn`). Nothing animates between runs.
Item {
    id: root

    property real d: 5
    property real strength: 1
    property var respawn: null      // function () -> { x, y } for the next landing
    // Shared slide clock of the surface (RainBeads); `moving` asks for it
    property Timer clock: null
    signal moving(bool on)
    readonly property string look: WeatherFx.drop
    readonly property real s: Math.min(1.5, root.strength)

    property bool _run: false
    property real _from: 0

    width: root.d
    height: Math.round(root.d * 1.12)

    function a(v: real): real {
        return Math.min(1, v * root.s);
    }

    function run(): void {
        if (root._run || !root.parent)
            return;
        root._run = true;
        root._from = root.y;
        trail.opacity = 1;
        root.step();
    }

    // One slide: a short burst down, then a pause (drops stick and slip)
    function step(): void {
        const floor = root.parent.height + root.height;
        if (root.y >= floor - 0.5) {
            root.finish();
            return;
        }
        const left = floor - root.y;
        const burst = Math.min(left, Math.max(root.d * 3, left * (0.35 + Math.random() * 0.4)));
        slide.from = root.y;
        slide.to = root.y + burst;
        slide.duration = Math.max(1, WeatherFx.ms(burst / 150 * 1000));
        slide.started = Date.now();
        slide.start();
    }

    // Off the bottom: the trail dries, then a new drop lands elsewhere
    function finish(): void {
        trailFade.start();
    }

    function relaunch(): void {
        const p = root.respawn ? root.respawn() : null;
        root._run = false;
        if (!p)
            return;
        root.x = p.x;
        root.y = p.y;
        land.start();
    }

    // The slide steps on the surface's shared 20 Hz clock (RainBeads): a
    // slow drop reads the same and the surface re-renders three times less
    // often than at 60 Hz, once per tick however many drops run.
    QtObject {
        id: slide
        property real from: 0
        property real to: 0
        property real duration: 1
        property real started: 0
        property bool running: false
        onRunningChanged: root.moving(running)
        function start(): void {
            running = true;
        }
        function stop(): void {
            running = false;
        }
    }
    Connections {
        target: root.clock
        enabled: slide.running
        function onTriggered(): void {
            const p = Math.min(1, (Date.now() - slide.started) / slide.duration);
            root.y = slide.from + (slide.to - slide.from) * (0.5 - 0.5 * Math.cos(Math.PI * p));
            if (p >= 1) {
                slide.stop();
                pause.start();
            }
        }
    }
    Timer {
        id: pause
        interval: WeatherFx.ms(180 + Math.random() * 520)
        onTriggered: root.step()
    }
    // A new drop lands: grows in from nothing
    ParallelAnimation {
        id: land
        NumberAnimation {
            target: body
            property: "scale"
            from: 0.2
            to: 1
            duration: WeatherFx.ms(420)
            easing.type: Easing.OutBack
        }
        NumberAnimation {
            target: body
            property: "opacity"
            from: 0
            to: 1
            duration: WeatherFx.ms(300)
        }
    }

    // The wet trail behind a running drop (kept in the surface's
    // coordinates: it stays while the drop moves on)
    Rectangle {
        id: trail
        opacity: 0
        visible: opacity > 0
        width: Math.max(1, Math.round(root.d * (root.look === "glint" ? 0.2 : 0.34)))
        x: (root.width - width) / 2
        y: root._from - root.y + root.height * 0.3
        height: Math.max(0, root.y - root._from)
        radius: width / 2
        gradient: Gradient {
            GradientStop {
                position: 0
                color: "transparent"
            }
            GradientStop {
                position: 1
                color: Qt.alpha(WeatherFx.glint, root.a(root.look === "glint" ? 0.34 : 0.3))
            }
        }
    }

    // The trail dries in a few discrete steps (a handful of frames, not a
    // 60 fps fade)
    Timer {
        id: trailFade
        interval: WeatherFx.ms(650)
        repeat: true
        onTriggered: {
            trail.opacity = Math.max(0, trail.opacity - 0.25);
            if (trail.opacity <= 0) {
                stop();
                root.relaunch();
            }
        }
    }

    Item {
        id: body
        anchors.fill: parent

        // Contact shadow: the side of the bead away from the light
        Rectangle {
            visible: root.look !== "glint"
            width: parent.width
            height: parent.height
            y: 1
            radius: width / 2
            color: Qt.alpha(WeatherFx.shade, root.a(root.look === "flat" ? 0.34 : 0.32))
        }
        // Body: clear water over the surface
        Rectangle {
            visible: root.look !== "glint"
            anchors.fill: parent
            radius: width / 2
            color: Qt.alpha(WeatherFx.glint, root.a(root.look === "flat" ? 0.2 : 0.12))
            border.width: root.look === "bead" ? 1 : 0
            border.color: Qt.alpha(WeatherFx.glint, root.a(0.4))
        }
        // Caustic: light focused through the drop onto its lower edge
        Rectangle {
            visible: root.look === "bead"
            width: parent.width * 0.56
            height: Math.max(1, parent.height * 0.26)
            x: (parent.width - width) / 2
            y: parent.height - height - 1
            radius: height / 2
            color: Qt.alpha(WeatherFx.glint, root.a(0.5))
        }
        // Specular glint
        Rectangle {
            readonly property real g: Math.max(1.5, root.d * (root.look === "glint" ? 0.42 : 0.3))
            width: g
            height: g
            radius: root.look === "flat" ? 0.5 : g / 2
            x: root.look === "glint" ? (parent.width - g) / 2 : parent.width * 0.2
            y: root.look === "glint" ? 0 : parent.height * 0.16
            color: Qt.alpha(WeatherFx.glint, root.a(root.look === "glint" ? 0.8 : 1))
        }
        // Hairline tick under the glint (hairline languages)
        Rectangle {
            visible: root.look === "glint"
            width: 1
            height: root.d * 0.9
            x: (parent.width - 1) / 2
            y: root.d * 0.5
            color: Qt.alpha(WeatherFx.glint, root.a(0.22))
        }
    }
}
