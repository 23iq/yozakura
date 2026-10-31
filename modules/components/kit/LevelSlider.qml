pragma ComponentBehavior: Bound
import QtQuick
import qs.modules.theme
import qs.modules.components.kit

// A chunky level slider (volume, brightness): a pill track on the raised
// surface (Look.raisedFill) with a tonal fill (Look.tonal; `strong`: solid
// accent) that always holds the `icon` at its start, and the value as text
// at the end. No thumb: press or drag anywhere on the track to set (the
// fill follows 1:1), the wheel and Left / Right step by `step` (Up / Down
// are left to the host's focus moves); external changes ease in and the
// number rolls with them. `iconClickable` makes the icon's cap a button (`iconClicked()`,
// mute); `dimmed` draws the fill quiet (muted). `level` (0..1, -1 = none)
// draws a live meter: a ghost of the fill reaching the signal level. `moved(value)` on user
// changes; `pressed` while dragged (hosts hold their binding then).
// `hasMore` ends the track with a caret zone (`more()`: the device list),
// accent while `moreActive`; the fill never runs under it. Where the
// language draws levels as knobs (Look.levelControl "knob") the face is a
// LevelStrip (knob + LED ladder + readout); the input stays the same.
Item {
    id: root

    property real from: 0
    property real to: 1
    property real value: 0
    property real step: (to - from) / 20
    property string icon: ""
    property bool iconClickable: false
    property bool dimmed: false
    property bool showValue: true
    property string valueText: Math.round(root.shown * 100) + "%"
    property bool highlighted: false
    property real level: -1
    property bool hasMore: false
    property bool moreActive: false
    property bool strong: false
    readonly property real fraction: root.to === root.from ? 0 : Math.max(0, Math.min(1, (root.value - root.from) / (root.to - root.from)))
    // The drawn fraction: follows the value with a short ease (instant while dragged).
    property real shown: root.fraction
    readonly property bool hovered: mouse.containsMouse || moreArea.containsMouse || root.highlighted
    readonly property bool pressed: mouse.pressed && !mouse.onCap
    readonly property real cap: root.height
    readonly property real moreW: root.hasMore ? root.cap : 0
    readonly property real span: Math.max(1, root.width - root.cap - root.moreW)
    readonly property real fillW: root.cap + root.shown * root.span
    property color fillColor: root.dimmed ? Qt.alpha(Type.muted, root.strong ? 1 : 0.45) : (root.strong ? Type.progress : Look.tonal(Type.progress))
    readonly property color onFill: root.strong ? (root.dimmed ? Colors.background : Type.accentInk) : (root.dimmed ? Type.secondary : Type.text)
    readonly property bool knob: Look.levelControl === "knob"

    signal moved(real value)
    signal iconClicked
    signal more

    function setFraction(f: real) {
        const v = root.from + Math.max(0, Math.min(1, f)) * (root.to - root.from);
        if (Math.abs(v - root.value) < 1e-6)
            return;
        root.value = v;
        root.moved(v);
    }

    function stepBy(n: int) {
        root.setFraction(root.fraction + n * root.step / Math.max(1e-6, root.to - root.from));
    }

    implicitWidth: 240
    implicitHeight: Space.controlM + Space.xs
    opacity: root.enabled ? 1 : 0.38
    activeFocusOnTab: true
    scale: root.pressed ? 0.98 : 1

    Accessible.role: Accessible.Slider
    Accessible.name: root.icon

    Keys.onLeftPressed: root.stepBy(-1)
    Keys.onRightPressed: root.stepBy(1)

    Behavior on fillColor {
        enabled: Motion.micro.duration > 0
        ColorAnimation {
            duration: Motion.micro.duration
        }
    }

    Behavior on opacity {
        enabled: Motion.micro.duration > 0
        NumberAnimation {
            duration: Motion.micro.duration
        }
    }

    Behavior on scale {
        enabled: Motion.spring.duration > 0
        NumberAnimation {
            duration: Motion.spring.duration
            easing.type: Motion.spring.easing
            easing.overshoot: Motion.spring.overshoot
        }
    }

    Behavior on shown {
        enabled: Motion.spring.duration > 0 && !root.pressed
        NumberAnimation {
            duration: Motion.glide.duration
            easing.type: Motion.glide.easing
        }
    }

    Rectangle {
        id: track
        objectName: "levelTrack"
        anchors.fill: parent
        radius: Look.bigRadius(height)
        color: Look.raisedFill(root.hovered)
        border.width: Look.controlEdge.a > 0 ? Space.hairline : 0
        border.color: Look.controlEdge
        clip: true

        // Live input level: a ghost of the fill reaching the signal level.
        Rectangle {
            objectName: "levelMeter"
            visible: root.level > 0.02 && !root.knob
            width: root.cap + Math.max(0, Math.min(1, root.level)) * root.span
            height: parent.height
            radius: parent.radius
            color: Type.progress
            opacity: 0.16
        }

        Rectangle {
            objectName: "levelFill"
            visible: !root.knob
            width: root.fillW
            height: parent.height
            radius: parent.radius
            color: root.fillColor
        }
    }

    Loader {
        anchors.fill: parent
        active: root.knob
        sourceComponent: LevelStrip {
            slider: root
        }
    }

    Text {
        objectName: "levelIcon"
        visible: !root.knob
        x: (root.cap - width) / 2
        anchors.verticalCenter: parent.verticalCenter
        text: root.icon
        font.family: Icons.font
        font.pixelSize: Type.iconSize("body") + 2
        color: root.onFill
    }

    KitText {
        objectName: "levelValue"
        visible: root.showValue && !root.knob
        anchors.right: parent.right
        anchors.rightMargin: root.moreW + Space.m
        anchors.verticalCenter: parent.verticalCenter
        role: "secondary"
        tabular: true
        font.weight: Font.DemiBold
        text: root.valueText
        // On the fill once it reaches the end.
        color: root.strong && root.fillW > root.width - root.moreW - Space.m - width / 2 ? root.onFill : Type.text
    }

    FocusRing {
        radius: track.radius + Space.stroke
        shown: root.activeFocus
    }

    MouseArea {
        id: mouse
        // Pressed on the icon's cap while it is a button.
        property bool onCap: false
        anchors.fill: parent
        anchors.rightMargin: root.moreW
        hoverEnabled: true
        enabled: root.enabled
        cursorShape: Qt.PointingHandCursor
        function track(m: var) {
            root.setFraction((m.x - root.cap / 2) / root.span);
        }
        onPressed: m => {
            mouse.onCap = root.iconClickable && m.x < root.cap;
            if (!mouse.onCap)
                mouse.track(m);
        }
        onPositionChanged: m => {
            if (mouse.pressed && !mouse.onCap)
                mouse.track(m);
        }
        onClicked: m => {
            if (mouse.onCap && m.x < root.cap)
                root.iconClicked();
        }
        onWheel: w => root.stepBy((w.angleDelta.y !== 0 ? w.angleDelta.y : w.angleDelta.x) > 0 ? 1 : -1)
    }

    // The detail zone: a caret behind a short divider.
    Item {
        objectName: "levelMore"
        visible: root.hasMore
        anchors.right: parent.right
        width: root.moreW
        height: parent.height

        Rectangle {
            anchors.verticalCenter: parent.verticalCenter
            width: Space.hairline
            height: parent.height * 0.44
            color: Type.hairline
        }

        Text {
            anchors.centerIn: parent
            text: Icons.caretRight
            font.family: Icons.font
            font.pixelSize: Type.iconSize("caption")
            color: root.moreActive ? Type.accent : (moreArea.containsMouse ? Type.text : Type.secondary)
        }

        MouseArea {
            id: moreArea
            anchors.fill: parent
            hoverEnabled: true
            enabled: root.enabled
            cursorShape: Qt.PointingHandCursor
            onClicked: root.more()
        }
    }
}
