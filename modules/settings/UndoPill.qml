import QtQuick
import QtQuick.Layouts
import qs.modules.theme
import qs.modules.services
import qs.modules.components
import qs.modules.components.kit
import qs.modules.settings.store

// After every change, undo or redo in the settings window: a small pill at
// the bottom of the window that names what changed ("Roundness changed")
// with [Undo] (or [Redo] after an undo). It rises in with a spring, stays a
// few seconds (longer while hovered or focused) and slides away. Ctrl+Z /
// Ctrl+Shift+Z work with or without it (SettingsShell).
Item {
    id: pill

    property int holdMs: 5000
    readonly property var step: SettingsStore.lastStep
    property bool shown: false
    readonly property bool hovered: hover.hovered
    readonly property string what: pill.step && pill.step.label ? I18n.t(pill.step.label) : I18n.t("prefs.undo.something")
    readonly property bool undone: !!pill.step && pill.step.kind === "undone"

    objectName: "undoPill"
    implicitWidth: box.width
    implicitHeight: box.height
    // Slides from just below its place.
    property real rise: pill.shown ? 0 : 1
    opacity: 1 - pill.rise
    visible: opacity > 0
    Behavior on rise {
        enabled: Motion.spring.duration > 0
        NumberAnimation {
            duration: pill.shown ? Motion.spring.duration : Motion.exit.duration
            easing.type: pill.shown ? Motion.spring.easing : Motion.exit.easing
            easing.overshoot: Motion.spring.overshoot
        }
    }

    onStepChanged: {
        if (!pill.step)
            return;
        pill.shown = true;
        hideTimer.restart();
    }

    Timer {
        id: hideTimer
        interval: pill.holdMs
        onTriggered: {
            if (pill.hovered || box.activeFocus)
                restart();
            else
                pill.shown = false;
        }
    }

    HoverHandler {
        id: hover
    }

    StyledRect {
        id: box
        y: pill.rise * Space.xl
        width: content.implicitWidth + Space.l + Space.s
        height: Space.controlM + Space.xs
        variant: "popup"
        enableShadow: true
        radius: Look.radius("round", height)

        RowLayout {
            id: content
            anchors.verticalCenter: parent.verticalCenter
            x: Space.l
            spacing: Space.m

            Icon {
                icon: pill.undone ? Icons.arrowCounterClockwise : Icons.check
                role: "secondary"
                tone: "accent"
            }
            KitText {
                objectName: "undoText"
                role: "secondary"
                color: Type.text
                // "Roundness changed"; a step that names itself ("Page reset")
                // is said as is.
                text: pill.step && pill.step.kind === "changed" && pill.step.label === "prefs.undo.reset_page" ? pill.what : I18n.t(pill.undone ? "prefs.undo.undone" : (pill.step && pill.step.kind === "redone" ? "prefs.undo.redone" : "prefs.undo.changed")).arg(pill.what)
                elide: Text.ElideRight
                Layout.maximumWidth: Space.px(340)
            }
            Chip {
                objectName: "undoAction"
                text: I18n.t(pill.undone ? "prefs.undo.redo" : "prefs.undo.undo")
                icon: pill.undone ? Icons.arrowsClockwise : Icons.arrowCounterClockwise
                quiet: true
                dense: true
                activeFocusOnTab: true
                highlighted: activeFocus
                Keys.onReturnPressed: clicked()
                Keys.onSpacePressed: clicked()
                onClicked: pill.undone ? SettingsStore.redo() : SettingsStore.undo()
            }
        }
    }
}
