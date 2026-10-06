pragma ComponentBehavior: Bound
import QtQuick
import qs.modules.services
import qs.modules.theme
import "CalendarModel.js" as CalendarModel

// Month view; with a calendar source (khal) also the next events, beside
// the month on a wide widget or under it on a tall one (not when `compact`).
// Host-agnostic (see HostWidget): the dashboard bento grid and the desktop
// both place it. Scroll over it to browse months; click the title to return.
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
    readonly property real gap: Math.round(12 * k)

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
        onWheel: event => root.monthShift += event.angleDelta.y > 0 ? -1 : 1
    }

    Item {
        id: month
        x: root.pad
        y: root.pad
        width: root.showEvents && root.wide ? (root.width - 2 * root.pad - root.gap) * 0.56 : root.width - 2 * root.pad
        height: root.showEvents && !root.wide ? (root.height - 2 * root.pad - root.gap) * 0.66 : root.height - 2 * root.pad

        Text {
            id: title
            width: parent.width
            text: root.shown.toLocaleDateString(Qt.locale(), "MMMM yyyy")
            elide: Text.ElideRight
            font.family: root.font
            font.pixelSize: root.px(1)
            font.weight: Font.DemiBold
            font.capitalization: Font.Capitalize
            color: root.ink

            MouseArea {
                anchors.fill: parent
                onClicked: root.monthShift = 0
            }
        }

        Grid {
            id: grid
            anchors.top: title.bottom
            anchors.topMargin: Math.round(8 * root.k)
            columns: 7
            readonly property real cellW: month.width / 7
            readonly property real cellH: (month.height - title.height - Math.round(8 * root.k)) / (root.rows + 1)

            Repeater {
                model: CalendarModel.weekdayOrder(root.firstDay)
                Text {
                    required property int modelData
                    width: grid.cellW
                    height: grid.cellH
                    horizontalAlignment: Text.AlignHCenter
                    verticalAlignment: Text.AlignVCenter
                    text: Qt.locale().dayName(modelData, Locale.NarrowFormat)
                    font.family: root.font
                    font.pixelSize: root.px(-3)
                    font.weight: Font.Bold
                    color: root.inkSoft
                }
            }

            Repeater {
                model: root.cells.slice(0, root.rows * 7)
                Item {
                    id: cell
                    required property var modelData
                    width: grid.cellW
                    height: grid.cellH

                    Rectangle {
                        anchors.centerIn: parent
                        width: Math.min(parent.width, parent.height) * 0.86
                        height: width
                        radius: Math.min(width / 2, Styling.radius(0))
                        color: Colors.primary
                        visible: cell.modelData.today
                    }
                    Text {
                        anchors.centerIn: parent
                        text: cell.modelData.day
                        font.family: root.font
                        font.pixelSize: root.px(-2)
                        font.weight: cell.modelData.today ? Font.Bold : Font.Normal
                        color: cell.modelData.today ? Colors.overPrimary : root.ink
                        opacity: cell.modelData.inMonth ? 1 : 0.32
                    }
                }
            }
        }
    }

    Column {
        id: agenda
        visible: root.showEvents
        x: root.wide ? month.x + month.width + root.gap : root.pad
        y: root.wide ? root.pad : month.y + month.height + root.gap
        width: root.wide ? root.width - x - root.pad : root.width - 2 * root.pad
        height: root.height - y - root.pad
        spacing: Math.round(6 * root.k)
        clip: true

        Text {
            text: I18n.t("desktop.widgets.calendar.upcoming")
            font.family: root.font
            font.pixelSize: root.px(-3)
            font.weight: Font.Bold
            font.capitalization: Font.AllUppercase
            font.letterSpacing: 1
            color: root.inkSoft
        }

        Text {
            visible: events.events.length === 0
            width: parent.width
            text: I18n.t("desktop.widgets.calendar.no_events")
            wrapMode: Text.WordWrap
            font.family: root.font
            font.pixelSize: root.px(-2)
            color: root.inkSoft
        }

        Repeater {
            model: events.events
            Row {
                id: ev
                required property var modelData
                width: agenda.width
                spacing: Math.round(8 * root.k)

                Rectangle {
                    width: Math.max(2, Math.round(3 * root.k))
                    height: evText.height
                    radius: width / 2
                    color: Colors.primary
                }
                Column {
                    id: evText
                    width: parent.width - parent.spacing - Math.max(2, Math.round(3 * root.k))
                    Text {
                        width: parent.width
                        text: ev.modelData.title
                        elide: Text.ElideRight
                        font.family: root.font
                        font.pixelSize: root.px(-2)
                        font.weight: Font.Medium
                        color: root.ink
                    }
                    Text {
                        width: parent.width
                        text: ev.modelData.time !== "" ? ev.modelData.date + " · " + ev.modelData.time : ev.modelData.date
                        elide: Text.ElideRight
                        font.family: root.font
                        font.pixelSize: root.px(-4)
                        color: root.inkSoft
                    }
                }
            }
        }
    }
}
