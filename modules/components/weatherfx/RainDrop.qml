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
    // Motion is stepped by the shared weather clock (WeatherFx.frame) and
    // only while `animate`; `ticking` tells whether this drop needs it
    property bool animate: false
    readonly property bool ticking: root.animate && (slide.running || landAnim.running || root._resume > 0)
    readonly property string look: WeatherFx.drop
    readonly property real s: Math.min(1.5, root.strength)

    property bool _run: false
    property real _from: 0
    // Waiting (between slides, while the trail dries) is a deadline checked
    // on the shared clock, so no timer wakes a frame of its own
    property real _resume: 0
    property string _then: ""
    function wait(ms: real, then: string): void {
        root._then = then;
        root._resume = Date.now() + ms;
    }

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
        root.wait(1, "start");
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
        root.wait(WeatherFx.ms(650), "dry");
    }

    function relaunch(): void {
        const p = root.respawn ? root.respawn() : null;
        root._run = false;
        if (!p)
            return;
        root.x = p.x;
        root.y = p.y;
        landAnim.start();
    }

    // The slide steps on the shared 10 Hz weather clock: a slow drop reads
    // the same and every drop of every surface lands in the same frame.
    QtObject {
        id: slide
        property real from: 0
        property real to: 0
        property real duration: 1
        property real started: 0
        property bool running: false
        function start(): void {
            running = true;
        }
        function stop(): void {
            running = false;
        }
    }
    onTickingChanged: WeatherFx.tickUsers += root.ticking ? 1 : -1
    Component.onDestruction: {
        if (root.ticking)
            WeatherFx.tickUsers -= 1;
    }
    Connections {
        target: WeatherFx.frame
        enabled: root.ticking
        function onTriggered(): void {
            const now = Date.now();
            if (slide.running) {
                const p = Math.min(1, (now - slide.started) / slide.duration);
                root.y = slide.from + (slide.to - slide.from) * (0.5 - 0.5 * Math.cos(Math.PI * p));
                if (p >= 1) {
                    slide.stop();
                    root.wait(WeatherFx.ms(180 + Math.random() * 520), "step");
                }
            }
            if (landAnim.running)
                landAnim.step(now);
            if (root._resume > 0 && now >= root._resume) {
                root._resume = 0;
                if (root._then === "start") {
                    trail.opacity = 1;
                    root.step();
                } else if (root._then === "step") {
                    root.step();
                } else {
                    trail.opacity = Math.max(0, trail.opacity - 0.25);
                    if (trail.opacity <= 0)
                        root.relaunch();
                    else
                        root.wait(WeatherFx.ms(650), "dry");
                }
            }
        }
    }
    // A new drop lands: grows in from nothing (OutBack), on the same clock
    QtObject {
        id: landAnim
        property bool running: false
        property real started: 0
        function start(): void {
            started = Date.now();
            body.scale = 0.2;
            body.opacity = 0;
            running = true;
        }
        function step(now: real): void {
            const t = Math.min(1, (now - started) / WeatherFx.ms(420));
            const c = 1.70158;
            const u = t - 1;
            body.scale = 0.2 + 0.8 * (1 + (c + 1) * u * u * u + c * u * u);
            body.opacity = Math.min(1, (now - started) / WeatherFx.ms(300));
            if (t >= 1)
                running = false;
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
