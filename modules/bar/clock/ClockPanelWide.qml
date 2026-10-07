pragma ComponentBehavior: Bound
import QtQuick
import qs.modules.theme
import qs.modules.services
import qs.modules.components.kit
import "../../widgets/dashboard/widgets/time"
import "ClockFaces.js" as ClockFaces

// The "wide" clock popup (bar.moduleOptions.clock.panelStyle): two halves.
// Left, the time (display) and date, the weekday in kanji as a quiet accent
// and the weather line with the day's details; right, past a vertical
// hairline, a large Pomodoro Ring with reset / start-pause (primary) / skip.
// Under them the world clocks inline.
Column {
    id: root

    property date now: new Date()
    property bool use12h: false
    readonly property real half: (root.width - Space.xl * 2 - Space.hairline) / 2

    readonly property var dayKeys: ["sunday", "monday", "tuesday", "wednesday", "thursday", "friday", "saturday"]
    readonly property var monthKeys: ["january", "february", "march", "april", "may", "june", "july", "august", "september", "october", "november", "december"]

    width: Space.rowHeight * 13
    spacing: Look.groupGap

    PomodoroModel {
        id: pomo
    }

    WorldClockSource {
        id: world
        running: root.visible
    }

    Group {
        width: root.width

        Row {
            width: parent.width
            height: Math.max(left.implicitHeight, right.implicitHeight)
            spacing: Space.xl

            Column {
                id: left
                width: root.half
                anchors.verticalCenter: parent.verticalCenter
                spacing: Space.xs

                KitText {
                    objectName: "clockPanelTime"
                    role: "display"
                    text: Qt.formatDateTime(root.now, root.use12h ? "h:mm AP" : "HH:mm")
                }
                KitText {
                    objectName: "clockPanelDate"
                    width: parent.width
                    role: "secondary"
                    text: I18n.t("calendar.day_full." + root.dayKeys[root.now.getDay()]) + ", " + I18n.t("calendar.month." + root.monthKeys[root.now.getMonth()]) + " " + root.now.getDate()
                }
                KitText {
                    objectName: "clockPanelKanji"
                    role: "caption"
                    text: ClockFaces.kanjiWeekday(root.now.getDay())
                }
                Item {
                    width: 1
                    height: Space.l
                }
                ClockWeatherNow {
                    id: weather
                    width: parent.width
                    showCondition: true
                }
                KitText {
                    width: parent.width
                    visible: weather.ready
                    role: "caption"
                    text: weather.details
                }
            }

            Divider {
                vertical: true
                height: parent.height
            }

            Column {
                id: right
                width: root.half
                anchors.verticalCenter: parent.verticalCenter
                spacing: Space.l

                Ring {
                    anchors.horizontalCenter: parent.horizontalCenter
                    width: Space.rowHeight * 3
                    height: width
                    value: pomo.progress
                    color: pomo.ringing ? Colors.error : Type.accent

                    Column {
                        spacing: Space.xs
                        KitText {
                            objectName: "pomodoroTime"
                            anchors.horizontalCenter: parent.horizontalCenter
                            role: "title"
                            tabular: true
                            text: pomo.ringing ? "00:00" : pomo.timeText
                            color: pomo.ringing ? Colors.error : Type.text
                        }
                        KitText {
                            anchors.horizontalCenter: parent.horizontalCenter
                            role: "label"
                            text: pomo.label
                        }
                    }
                }

                Row {
                    anchors.horizontalCenter: parent.horizontalCenter
                    spacing: Space.l

                    IconButton {
                        anchors.verticalCenter: parent.verticalCenter
                        enabled: pomo.active
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
                        anchors.verticalCenter: parent.verticalCenter
                        enabled: pomo.running
                        icon: Icons.skipForward
                        onClicked: pomo.skip()
                    }
                }
            }
        }
    }

    Group {
        objectName: "clockPanelWorld"
        width: root.width
        divider: true
        visible: world.rows.length > 0
        label: I18n.t("bento.label.world")

        Row {
            id: worldRow
            width: parent.width

            Repeater {
                model: world.rows

                Row {
                    id: zone
                    required property var modelData
                    width: worldRow.width / Math.max(1, world.rows.length)
                    spacing: Space.s

                    KitText {
                        anchors.baseline: time.baseline
                        role: "secondary"
                        text: zone.modelData.label
                    }
                    KitText {
                        id: time
                        objectName: "worldClockTime"
                        role: "body"
                        tabular: true
                        text: zone.modelData.time
                    }
                    KitText {
                        anchors.baseline: time.baseline
                        role: "caption"
                        text: zone.modelData.offset
                    }
                }
            }
        }
    }
}
