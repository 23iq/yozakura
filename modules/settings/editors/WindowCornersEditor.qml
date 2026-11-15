pragma ComponentBehavior: Bound

import QtQuick
import qs.modules.theme
import qs.modules.services
import qs.modules.components.kit
import qs.modules.settings.store
import "../stages/WindowTiles.js" as Tiles
import "StepPick.js" as StepPick

// Window corners as a strip of window shapes from square to round
// (compositor.rounding) and "Like the shell" (compositor.syncRoundness:
// the windows follow the shell's roundness, its value beside it). One click
// = one undo step; Left / Right step from the value it has. The stage's
// corner knob gives any value: one between the steps chooses no tile.
FocusScope {
    id: root

    property var entry
    property real fillHeight: 0
    readonly property var steps: [0, 8, 16, 24, 32]
    readonly property bool sync: SettingsStore.get("compositor.syncRoundness") !== false
    readonly property int value: Tiles.rounding(root.sync, SettingsStore.get("compositor.rounding"), SettingsStore.get("theme.roundness"))
    // the step equal to the current rounding (-1 while following the shell
    // or between two steps)
    readonly property int current: root.sync ? -1 : StepPick.exactIndex(root.steps, root.value)

    function pick(v) {
        SettingsStore.transaction("prefs.undo.window_corners", () => {
            SettingsStore.set("compositor.syncRoundness", false);
            SettingsStore.set("compositor.rounding", v);
        });
    }
    function follow() {
        SettingsStore.transaction("prefs.undo.window_corners", () => SettingsStore.set("compositor.syncRoundness", true));
    }

    implicitHeight: root.fillHeight > 0 ? root.fillHeight : Space.controlL * 2
    activeFocusOnTab: true
    Keys.onLeftPressed: root.pick(StepPick.stepFrom(root.steps, root.value, -1))
    Keys.onRightPressed: root.pick(StepPick.stepFrom(root.steps, root.value, 1))

    Row {
        id: strip
        width: parent.width
        height: parent.height - shell.height - Space.s
        spacing: Space.s

        Repeater {
            model: root.steps
            delegate: PickTile {
                id: step
                required property int modelData
                required property int index
                objectName: "cornerStep:" + modelData
                width: (strip.width - strip.spacing * (root.steps.length - 1)) / root.steps.length
                height: strip.height
                chosen: index === root.current
                caption: String(modelData)
                onClicked: root.pick(modelData)

                // a window's top-left corner at this rounding (scaled to the tile)
                Mark {
                    readonly property real s: Math.min(parent.width, parent.height) * 1.5
                    x: parent.width * 0.22
                    y: parent.height * 0.22
                    width: s
                    height: s
                    radius: Math.min(s / 2, step.modelData * s / 48)
                    color: "transparent"
                    border.width: Space.stroke - 1
                    border.color: step.chosen ? Type.accent : Type.secondary
                }
            }
        }
    }

    Chip {
        id: shell
        objectName: "cornersFollowShell"
        anchors.bottom: parent.bottom
        dense: true
        icon: Icons.link
        active: root.sync
        text: I18n.t("prefs.windows.corners_shell")
        onClicked: root.follow()
    }
    // the rounding the shell gives the windows now
    KitText {
        objectName: "cornersShellValue"
        visible: root.sync
        anchors.left: shell.right
        anchors.leftMargin: Space.s
        anchors.verticalCenter: shell.verticalCenter
        role: "secondary"
        color: Type.secondary
        text: String(root.value)
    }

    FocusRing {
        shown: root.activeFocus
        radius: Look.radius("box", Space.controlL)
    }
}
