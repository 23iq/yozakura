pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import qs.modules.theme
import qs.modules.services
import qs.modules.components.kit
import qs.modules.settings.controls
import qs.modules.settings.store

// Pomodoro card: the focus and break lengths in minutes (stored in seconds,
// system.pomodoro.workTime / restTime) and whether the next phase starts on
// its own (system.pomodoro.autoStart). One line each, like the rows of the
// other cards.
Column {
    id: root

    property var entry
    readonly property int work: Math.round(Number(SettingsStore.get("system.pomodoro.workTime") ?? 1500) / 60)
    readonly property int rest: Math.round(Number(SettingsStore.get("system.pomodoro.restTime") ?? 300) / 60)
    readonly property bool auto: SettingsStore.get("system.pomodoro.autoStart") === true

    spacing: 0

    Line {
        objectName: "pomodoroWork"
        label: I18n.t("prefs.timers.pomo_focus")
        keys: ["system.pomodoro.workTime"]
        NumberControl {
            objectName: "pomodoroWorkStep"
            value: root.work
            from: 5
            to: 240
            stepSize: 5
            unit: I18n.t("prefs.timers.min")
            onChanged: v => SettingsStore.set("system.pomodoro.workTime", Math.round(v) * 60)
        }
    }
    Line {
        objectName: "pomodoroRest"
        label: I18n.t("prefs.timers.pomo_break")
        keys: ["system.pomodoro.restTime"]
        NumberControl {
            objectName: "pomodoroRestStep"
            value: root.rest
            from: 1
            to: 120
            stepSize: 1
            unit: I18n.t("prefs.timers.min")
            onChanged: v => SettingsStore.set("system.pomodoro.restTime", Math.round(v) * 60)
        }
    }
    Line {
        objectName: "pomodoroAuto"
        label: I18n.t("prefs.timers.pomo_auto")
        keys: ["system.pomodoro.autoStart"]
        Switch {
            objectName: "pomodoroAutoSwitch"
            checked: root.auto
            onToggled: v => SettingsStore.set("system.pomodoro.autoStart", v)
        }
    }

    // One line: the label on the left, the control on the right; under
    // the pointer it lights up its part of the stage.
    component Line: Item {
        id: line
        property string label: ""
        property var keys: []
        default property alias control: slot.data
        width: root.width
        // three lines fit a row card with the row's own padding
        height: Space.rowHeight - Math.ceil(Space.s * 2 / 3)

        HoverHandler {
            onHoveredChanged: hovered ? SettingsStore.point(line, line.keys) : SettingsStore.unpoint(line)
        }
        Component.onDestruction: SettingsStore.unpoint(line)

        RowLayout {
            x: Look.rowInset
            width: parent.width - Look.rowInset * 2
            anchors.verticalCenter: parent.verticalCenter
            spacing: Space.l
            KitText {
                Layout.fillWidth: true
                role: "body"
                elide: Text.ElideRight
                text: line.label
            }
            Item {
                id: slot
                implicitWidth: childrenRect.width
                implicitHeight: childrenRect.height
            }
        }
    }
}
