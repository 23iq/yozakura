import QtQuick
import qs.modules.theme
import qs.modules.components.kit

// On / off switch. Off: the track line color with a muted knob; on: the
// accent track with an onAccent knob (the accent marks the active state
// only). Round, or the small radius in square languages (tiles).
// `toggled(value)` fires on user interaction only; `checked` follows the
// bound value. Space / Enter flip it; keyboard focus shows a hairline ring.
Item {
    id: root

    property bool checked: false
    readonly property bool hovered: mouse.containsMouse
    readonly property real trackRadius: Look.squareControls ? Space.clampRadius(Space.smallRadius, root.height) : Space.round(root.height)

    signal toggled(bool value)

    function flip() {
        if (root.enabled)
            root.toggled(!root.checked);
    }

    implicitWidth: Space.px(40)
    implicitHeight: Space.px(22)
    activeFocusOnTab: true
    opacity: root.enabled ? 1 : 0.38

    Accessible.role: Accessible.CheckBox
    Accessible.checked: root.checked
    Accessible.onToggleAction: root.flip()

    Keys.onSpacePressed: root.flip()
    Keys.onReturnPressed: root.flip()

    Rectangle {
        id: track
        anchors.fill: parent
        radius: root.trackRadius
        color: root.checked ? Type.accent : (root.hovered ? Qt.rgba(Type.text.r, Type.text.g, Type.text.b, 0.22) : Type.track)
        border.width: root.activeFocus ? Space.hairline : 0
        border.color: Type.text

        Behavior on color {
            enabled: Motion.enter.duration > 0
            ColorAnimation {
                duration: Motion.enter.duration / 2
            }
        }

        Rectangle {
            id: knob
            readonly property int pad: Space.px(3)
            width: track.height - pad * 2
            height: width
            radius: Look.squareControls ? Math.max(0, track.radius - pad) : width / 2
            y: pad
            x: root.checked ? track.width - width - pad : pad
            color: root.checked ? Type.onAccent : Type.secondary

            Behavior on x {
                enabled: Motion.enter.duration > 0
                NumberAnimation {
                    duration: Motion.enter.duration / 2
                    easing.type: Easing.OutCubic
                }
            }
        }
    }

    MouseArea {
        id: mouse
        anchors.fill: parent
        anchors.margins: -Space.xs
        hoverEnabled: true
        cursorShape: root.enabled ? Qt.PointingHandCursor : Qt.ArrowCursor
        onClicked: {
            root.forceActiveFocus();
            root.flip();
        }
    }
}
