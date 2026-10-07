import QtQuick
import qs.modules.theme
import qs.modules.services
import qs.modules.components.kit
import "../../widgets/dashboard/widgets/time"

// The Pomodoro of the column clock panel: a Ring with the time left inside,
// beside it the phase ("FOCUS · 1 OF 4"), the work / rest lengths and the
// actions: Start (or pause / resume / stop, the accented chip) and Edit,
// which opens the length steppers under the row; while running, skip and
// cancel instead of Edit.
Column {
    id: root

    property bool editing: false

    spacing: Space.m

    PomodoroModel {
        id: pomo
    }

    Row {
        width: parent.width
        spacing: Space.l

        Ring {
            id: ring
            width: Space.rowHeight * 1.5
            height: width
            anchors.verticalCenter: parent.verticalCenter
            value: pomo.progress
            color: pomo.ringing ? Colors.error : Type.accent

            KitText {
                objectName: "pomodoroTime"
                role: "body"
                tabular: true
                font.weight: Font.Medium
                text: pomo.ringing ? "00:00" : pomo.timeText
                color: pomo.ringing ? Colors.error : Type.text
            }
        }

        Column {
            width: parent.width - ring.width - parent.spacing
            anchors.verticalCenter: parent.verticalCenter
            spacing: Space.xs

            KitText {
                objectName: "pomodoroLabel"
                width: parent.width
                role: "label"
                text: pomo.label
            }
            KitText {
                width: parent.width
                role: "caption"
                text: pomo.lengths
            }
            Item {
                width: 1
                height: Space.xs
            }
            Row {
                spacing: Space.s

                Chip {
                    objectName: "pomodoroMain"
                    icon: pomo.mainIcon
                    text: pomo.ringing ? I18n.t("clock.panel.stop") : (pomo.running ? I18n.t("clock.panel.pause") : (pomo.active ? I18n.t("clock.panel.resume") : I18n.t("clock.panel.start")))
                    active: true
                    onClicked: pomo.main()
                }
                Chip {
                    visible: !pomo.active
                    icon: Icons.pencil
                    text: I18n.t("clock.panel.edit")
                    active: root.editing
                    onClicked: root.editing = !root.editing
                }
                IconButton {
                    visible: pomo.running
                    anchors.verticalCenter: parent.verticalCenter
                    size: "s"
                    icon: Icons.skipForward
                    onClicked: pomo.skip()
                }
                IconButton {
                    visible: pomo.active
                    anchors.verticalCenter: parent.verticalCenter
                    size: "s"
                    icon: Icons.cancel
                    onClicked: pomo.cancel()
                }
            }
        }
    }

    PomodoroLengths {
        visible: root.editing && !pomo.active
        width: parent.width
        pomodoro: pomo
    }
}
