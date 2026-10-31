import QtQuick
import qs.modules.theme
import qs.modules.components.kit
import "StripLayout.js" as StripLayout
import "StripPhysics.js" as Physics

// Motion of one strip (Strip.qml): it drops in along its thread and sways
// (a damped pendulum, StripPhysics.swayAngle), neighbours get a nudge, and
// it leaves back up the thread: at once when flicked (`kind` "flick"),
// gently when its time is up ("lift"). All durations come from Motion
// tokens; with motion off nothing moves and nothing sways.
Item {
    id: root

    property string edge: "top"
    property bool sway: true
    // Pivot-to-tip length: how far the strip travels in and out
    property real reach: 0
    property string kind: "lift"

    readonly property bool canLeave: Motion.exit.duration > 0
    readonly property int swayMs: root.sway ? Physics.swayDuration(Motion.emphasis.duration) : 0

    property real dropped: 1
    property real swayed: 1
    property real swayAmp: 0
    property real gone: 0

    readonly property real angle: Physics.swayAngle(root.swayed, root.swayAmp)
    readonly property var toward: StripLayout.towardEdge(root.edge)
    readonly property real travel: root.reach * 0.3 * (1 - root.dropped) + (root.reach + Space.xl) * root.gone
    readonly property var offset: ({
            "x": root.toward.x * root.travel,
            "y": root.toward.y * root.travel
        })
    readonly property real fade: Math.min(1, root.dropped * 1.6) * (1 - root.gone)

    signal gonePast

    function arrive(): void {
        if (Motion.enter.duration > 0) {
            root.dropped = 0;
            dropAnim.restart();
        }
        root.nudge(Physics.amplitude(0));
    }

    function nudge(amp: real): void {
        if (root.swayMs <= 0 || amp <= 0)
            return;
        root.swayAmp = amp;
        swayAnim.restart();
    }

    function leave(): void {
        swayAnim.stop();
        leaveAnim.duration = Physics.exitDuration(root.kind, Motion.exit.duration);
        leaveAnim.easing.type = root.kind === "lift" ? Easing.InOutSine : Motion.exit.easing;
        leaveSeq.restart();
    }

    NumberAnimation {
        id: dropAnim
        target: root
        property: "dropped"
        from: 0
        to: 1
        duration: Motion.enter.duration
        easing.type: Motion.enter.easing
    }

    NumberAnimation {
        id: swayAnim
        target: root
        property: "swayed"
        from: 0
        to: 1
        duration: root.swayMs
        easing.type: Easing.Linear
    }

    SequentialAnimation {
        id: leaveSeq
        NumberAnimation {
            id: leaveAnim
            target: root
            property: "gone"
            from: 0
            to: 1
        }
        ScriptAction {
            script: root.gonePast()
        }
    }
}
