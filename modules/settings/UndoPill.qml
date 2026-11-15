import QtQuick
import QtQuick.Layouts
import qs.modules.theme
import qs.modules.services
import qs.modules.components
import qs.modules.components.kit
import qs.modules.settings.store

// After every change, undo or redo in the settings window: a small pill
// floating at the bottom centre of the window that names what changed
// ("Roundness changed") with [Undo] (or [Redo] after an undo). It is its
// own opaque surface with a shadow (never a see-through layer over row
// text; the pages keep room for it under their last card), rises in
// (enter), stays a few seconds (longer while hovered or focused) and
// slides away (exit); a new step cross-fades its words. Ctrl+Z /
// Ctrl+Shift+Z work with or without it (SettingsShell). Its button acts on
// the step it names (SettingsStore.undoStep / redoStep by id), never on
// another one; when that step is gone (taken back, dropped, the history
// cleared) the store announces nothing and the pill hides.
Item {
    id: pill

    property int holdMs: 5000
    // The step the pill names; kept while it slides away so its text holds.
    property var step: null
    property bool shown: false
    readonly property bool hovered: hover.hovered
    readonly property string what: pill.step && pill.step.label ? I18n.t(pill.step.label) : I18n.t("prefs.undo.something")
    readonly property bool undone: !!pill.step && pill.step.kind === "undone"
    // "Roundness changed"; a step that names itself (a prefs.undo.* label:
    // "Page reset", "Bar moved") is said as is
    readonly property string said: pill.step && pill.step.kind === "changed" && String(pill.step.label).startsWith("prefs.undo.") ? pill.what : I18n.t(pill.undone ? "prefs.undo.undone" : (pill.step && pill.step.kind === "redone" ? "prefs.undo.redone" : "prefs.undo.changed")).arg(pill.what)

    objectName: "undoPill"
    implicitWidth: box.width
    implicitHeight: box.height
    // Rises from just below its place.
    property real rise: pill.shown ? 0 : 1
    opacity: 1 - pill.rise
    visible: opacity > 0
    Behavior on rise {
        enabled: Motion.enter.duration > 0
        NumberAnimation {
            duration: pill.shown ? Motion.enter.duration : Motion.exit.duration
            easing.type: pill.shown ? Motion.enter.easing : Motion.exit.easing
        }
    }

    Connections {
        target: SettingsStore
        function onLastStepChanged() {
            const s = SettingsStore.lastStep;
            if (!s) {
                hideTimer.stop();
                pill.shown = false;
                return;
            }
            pill.step = s;
            pill.shown = true;
            hideTimer.restart();
        }
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
        y: pill.rise * Space.l
        width: content.implicitWidth + Space.l + Space.s
        height: Space.controlM + Space.xs
        variant: "popup"
        // opaque: words under it never show through
        backgroundOpacity: 1
        enableShadow: true
        radius: Look.radius("round", height)
        Behavior on width {
            enabled: pill.shown && Motion.glide.duration > 0
            NumberAnimation {
                duration: Motion.glide.duration
                easing.type: Motion.glide.easing
            }
        }

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
            // the words: the new ones cross-fade over the old (a second
            // change while it shows)
            Item {
                Layout.preferredWidth: Math.min(Space.px(340), undoText.implicitWidth)
                Layout.preferredHeight: undoText.implicitHeight
                clip: true
                KitText {
                    id: oldText
                    role: "secondary"
                    color: Type.text
                    width: parent.width
                    elide: Text.ElideRight
                    opacity: 0
                }
                KitText {
                    id: undoText
                    objectName: "undoText"
                    role: "secondary"
                    color: Type.text
                    width: parent.width
                    elide: Text.ElideRight
                    text: pill.said
                    property string was: ""
                    onTextChanged: {
                        if (undoText.was !== "" && pill.visible && Motion.micro.duration > 0) {
                            oldText.text = undoText.was;
                            swapText.restart();
                        }
                        undoText.was = undoText.text;
                    }
                }
                ParallelAnimation {
                    id: swapText
                    NumberAnimation {
                        target: oldText
                        property: "opacity"
                        from: 1
                        to: 0
                        duration: Motion.glide.duration
                        easing.type: Motion.glide.easing
                    }
                    NumberAnimation {
                        target: undoText
                        property: "opacity"
                        from: 0
                        to: 1
                        duration: Motion.glide.duration
                        easing.type: Motion.glide.easing
                    }
                }
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
                onClicked: {
                    if (!pill.step || !pill.shown)
                        return;
                    if (pill.undone)
                        SettingsStore.redoStep(pill.step.id);
                    else
                        SettingsStore.undoStep(pill.step.id);
                }
            }
        }
    }
}
