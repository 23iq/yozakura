pragma ComponentBehavior: Bound
import QtQuick
import qs.modules.services
import qs.modules.theme
import qs.modules.components.kit
import "CalendarModel.js" as CalendarModel

// Month view under the month's name (the Group label; "Today" returns from
// another month); with a calendar source (khal) also the next events,
// beside the month on a wide widget or under it on a tall one (not when
// `compact`). A short tile drops the weekday header, a very narrow one
// shows today as a day card instead of the month. Host-agnostic (see
// HostWidget): the dashboard bento grid, the dashboard home and the desktop
// place it. Scroll over it to browse months.
HostWidget {
    id: root

    property date now: new Date()
    property int monthShift: 0
    readonly property date shown: new Date(now.getFullYear(), now.getMonth() + monthShift, 1)
    readonly property int firstDay: CalendarModel.firstDayOf(options.weekStart ?? "locale", Qt.locale().firstDayOfWeek)
    readonly property var cells: CalendarModel.monthGrid(shown, firstDay, now)
    readonly property int rows: CalendarModel.rowsNeeded(shown, firstDay)
    readonly property bool showEvents: (options.showEvents ?? true) && !compact && events.available && !preview
    readonly property bool wide: width > height * 1.45
    readonly property real bodyW: group.width - group.padding * 2
    readonly property real monthW: root.showEvents && root.wide ? (root.bodyW - Space.l) * 0.56 : root.bodyW
    readonly property real monthH: root.showEvents && !root.wide ? (group.bodyHeight - Space.l) * 0.66 : group.bodyHeight
    readonly property bool showWeekdays: root.monthH / (root.rows + 1) >= Type.size("caption") * 1.3
    // Too narrow for a readable month: today as a day card instead.
    readonly property bool dayCard: root.monthW / 7 < Type.size("caption") * 1.6

    CalendarEvents {
        id: events
        active: root.active && (root.options.showEvents ?? true) && !root.preview
    }

    // The date changes at most once a minute; check only while visible.
    Timer {
        interval: 60000
        repeat: true
        running: root.active
        onTriggered: {
            const d = new Date();
            if (d.getDate() !== root.now.getDate())
                root.now = d;
        }
    }

    WheelHandler {
        acceptedDevices: PointerDevice.Mouse | PointerDevice.TouchPad
        enabled: !root.dayCard
        onWheel: event => root.monthShift += event.angleDelta.y > 0 ? -1 : 1
    }

    Group {
        id: group
        anchors.fill: parent
        fill: true
        bare: !root.framed
        label: root.shown.toLocaleDateString(Qt.locale(), "MMMM yyyy")
        actionText: root.monthShift !== 0 ? I18n.t("bento.calendar.today") : ""
        onActionTriggered: root.monthShift = 0

        Item {
            width: parent.width
            height: group.bodyHeight

            Column {
                visible: root.dayCard
                width: root.monthW
                spacing: Space.xs

                KitText {
                    objectName: "calendarDay"
                    role: "display"
                    text: root.now.getDate()
                }
                KitText {
                    width: parent.width
                    role: "body"
                    text: Qt.locale().dayName(root.now.getDay(), Locale.LongFormat)
                }
            }

            Grid {
                id: grid
                visible: !root.dayCard
                columns: 7
                readonly property real cellW: root.monthW / 7
                readonly property real cellH: root.monthH / (root.rows + (root.showWeekdays ? 1 : 0))

                Repeater {
                    model: root.showWeekdays ? CalendarModel.weekdayOrder(root.firstDay) : []
                    KitText {
                        required property int modelData
                        width: grid.cellW
                        height: grid.cellH
                        horizontalAlignment: Text.AlignHCenter
                        role: "caption"
                        text: Qt.locale().dayName(modelData, Locale.NarrowFormat)
                    }
                }

                Repeater {
                    model: root.cells.slice(0, root.rows * 7)
                    Item {
                        id: cell
                        required property var modelData
                        width: grid.cellW
                        height: grid.cellH

                        // Today: the accent (the one marked day).
                        Rectangle {
                            anchors.centerIn: parent
                            width: Math.min(parent.width, parent.height) * 0.9
                            height: width
                            radius: Look.buttonRadius(height)
                            color: Type.accent
                            visible: cell.modelData.today
                        }
                        KitText {
                            anchors.centerIn: parent
                            role: grid.cellW >= Type.size("secondary") * 2 ? "secondary" : "caption"
                            tabular: true
                            text: cell.modelData.day
                            color: cell.modelData.today ? Type.accentInk : (cell.modelData.inMonth ? Type.text : Type.muted)
                            font.weight: cell.modelData.today ? Font.DemiBold : Font.Normal
                            opacity: cell.modelData.inMonth ? 1 : 0.6
                        }
                    }
                }
            }

            Column {
                id: agenda
                visible: root.showEvents
                x: root.wide ? root.monthW + Space.l : 0
                y: root.wide ? 0 : root.monthH + Space.l
                width: root.wide ? parent.width - x : parent.width
                height: parent.height - y
                spacing: Space.s
                clip: true

                SectionLabel {
                    width: parent.width
                    text: I18n.t("desktop.widgets.calendar.upcoming")
                }

                KitText {
                    visible: events.events.length === 0
                    width: parent.width
                    role: "caption"
                    wrapMode: Text.WordWrap
                    text: I18n.t("desktop.widgets.calendar.no_events")
                }

                Repeater {
                    model: events.events
                    Column {
                        id: ev
                        required property var modelData
                        width: agenda.width
                        spacing: 1

                        KitText {
                            width: parent.width
                            role: "body"
                            text: ev.modelData.title
                        }
                        KitText {
                            width: parent.width
                            role: "caption"
                            text: ev.modelData.time !== "" ? ev.modelData.date + " · " + ev.modelData.time : ev.modelData.date
                        }
                    }
                }
            }
        }
    }
}
