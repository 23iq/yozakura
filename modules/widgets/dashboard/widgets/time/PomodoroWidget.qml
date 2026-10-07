pragma ComponentBehavior: Bound
import QtQuick
import qs.modules.theme
import qs.modules.services
import qs.modules.components.kit
import ".."

// Pomodoro bento widget (bar clock panel, dashboard) over PomodoroModel: a
// Ring with the time left (the work length when idle) and the phase under
// it, then the controls: idle, Start (the one primary action) and, on a
// roomy tile, the work / rest lengths (-/+ 1 min); running, reset, pause /
// resume and skip, plus -1 / +1 min and cancel on a wide tile. A tile that
// is not compact also shows the auto-start and Spotify sync chips. The IPC
// target and the Spotify sync live in modules/bar/clock/PomodoroSync.qml.
HostWidget {
    id: root

    readonly property bool wideTile: root.width >= root.cellW * 1.5
    readonly property bool showLengths: !pomo.active && group.bodyHeight >= Space.rowHeight * 5
    readonly property real controlsH: Space.controlM + (root.showLengths ? Space.controlS * 2 + Space.s + Space.m : 0) + (root.compact ? 0 : Space.chip + Space.m)
    readonly property real ringSize: Math.max(Space.controlM, Math.min(width - group.padding * 2, group.bodyHeight - root.controlsH - Type.size("caption") * 1.4 - Space.m * 2, Space.rowHeight * 3.4))

    PomodoroModel {
        id: pomo
    }

    Group {
        id: group
        anchors.fill: parent
        fill: true
        bare: !root.framed
        label: I18n.t("bento.widget.pomodoro")

        Ring {
            anchors.horizontalCenter: parent.horizontalCenter
            width: root.ringSize
            height: root.ringSize
            value: pomo.progress
            color: pomo.ringing ? Colors.error : Type.accent

            KitText {
                objectName: "pomodoroTime"
                role: root.ringSize >= Space.rowHeight * 2.4 ? "title" : "body"
                tabular: true
                text: pomo.timeText
                color: pomo.ringing ? Colors.error : Type.text
            }
        }

        KitText {
            width: parent.width
            horizontalAlignment: Text.AlignHCenter
            role: "label"
            text: pomo.label
        }

        // Idle lengths
        PomodoroLengths {
            visible: root.showLengths
            width: parent.width
            pomodoro: pomo
        }

        Row {
            anchors.horizontalCenter: parent.horizontalCenter
            spacing: root.wideTile ? Space.m : Space.xs

            Chip {
                visible: pomo.active && !pomo.ringing && root.wideTile
                anchors.verticalCenter: parent.verticalCenter
                text: I18n.t("pomodoro.minus_1m")
                onClicked: pomo.nudge("-1m")
            }
            IconButton {
                visible: pomo.active && !pomo.ringing
                anchors.verticalCenter: parent.verticalCenter
                size: "s"
                icon: Icons.arrowCounterClockwise
                onClicked: pomo.reset()
            }
            IconButton {
                objectName: "pomodoroMain"
                anchors.verticalCenter: parent.verticalCenter
                primary: true
                icon: pomo.mainIcon
                Accessible.name: pomo.mainText
                onClicked: pomo.main()
            }
            IconButton {
                visible: pomo.running
                anchors.verticalCenter: parent.verticalCenter
                size: "s"
                objectName: "pomodoroSkip"
                icon: Icons.skipForward
                onClicked: pomo.skip()
            }
            IconButton {
                visible: pomo.active && (root.wideTile || !pomo.running)
                anchors.verticalCenter: parent.verticalCenter
                size: "s"
                icon: Icons.cancel
                onClicked: pomo.cancel()
            }
            Chip {
                visible: pomo.active && !pomo.ringing && root.wideTile
                anchors.verticalCenter: parent.verticalCenter
                text: I18n.t("pomodoro.plus_1m")
                onClicked: pomo.nudge("+1m")
            }
        }

        Row {
            visible: !root.compact
            anchors.horizontalCenter: parent.horizontalCenter
            spacing: Space.s

            Chip {
                text: I18n.t("common.auto")
                active: pomo.cfg.autoStart
                onClicked: pomo.cfg.autoStart = !pomo.cfg.autoStart
            }
            Chip {
                text: I18n.t("pomodoro.sync_spotify")
                active: pomo.cfg.syncSpotify
                onClicked: pomo.cfg.syncSpotify = !pomo.cfg.syncSpotify
            }
        }
    }
}
