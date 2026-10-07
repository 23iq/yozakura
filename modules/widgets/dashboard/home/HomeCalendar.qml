pragma ComponentBehavior: Bound
import QtQuick
import qs.modules.theme
import qs.modules.services
import qs.modules.components.kit
import qs.modules.widgets.dashboard.widgets
import "../widgets/CalendarModel.js" as CalendarModel

// Month calendar of the composed dashboard: the month title with ‹ ›
// (click the title or scroll to browse, the title returns to today), the
// weekdays and the days, today selected; with a calendar source (khal) the
// next events under it. Month logic is the shared CalendarModel.
Group {
    id: root

    property date now: new Date()
    property int monthShift: 0
    property int maxEvents: 2
    readonly property date shown: new Date(root.now.getFullYear(), root.now.getMonth() + root.monthShift, 1)
    readonly property int firstDay: CalendarModel.firstDayOf("locale", Qt.locale().firstDayOfWeek)
    readonly property var cells: CalendarModel.monthGrid(root.shown, root.firstDay, root.now)
    readonly property int rows: CalendarModel.rowsNeeded(root.shown, root.firstDay)
    readonly property real cellW: width > 0 ? (width - root.padding * 2) / 7 : Space.controlS
    readonly property real cellH: Math.round(Space.controlS * 0.8)

    CalendarEvents {
        id: events
        active: root.visible
        limit: root.maxEvents
    }

    // The date changes at most once a minute.
    Timer {
        interval: 60000
        repeat: true
        running: root.visible
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
        width: parent.width
        height: Space.controlS

        KitText {
            objectName: "monthTitle"
            anchors.left: parent.left
            anchors.right: nav.left
            anchors.rightMargin: Space.s
            anchors.verticalCenter: parent.verticalCenter
            role: "title"
            text: root.shown.toLocaleDateString(Qt.locale(), "MMMM yyyy")
            font.capitalization: Font.Capitalize

            MouseArea {
                anchors.fill: parent
                onClicked: root.monthShift = 0
            }
        }

        Row {
            id: nav
            anchors.right: parent.right
            anchors.verticalCenter: parent.verticalCenter
            spacing: Space.xs

            IconButton {
                objectName: "prevMonth"
                size: "s"
                icon: Icons.caretLeft
                onClicked: root.monthShift--
            }

            IconButton {
                objectName: "nextMonth"
                size: "s"
                icon: Icons.caretRight
                onClicked: root.monthShift++
            }
        }
    }

    Grid {
        objectName: "monthGrid"
        columns: 7

        Repeater {
            model: CalendarModel.weekdayOrder(root.firstDay)

            KitText {
                required property int modelData
                width: root.cellW
                height: root.cellH
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
                width: root.cellW
                height: root.cellH

                Rectangle {
                    objectName: "today"
                    anchors.centerIn: parent
                    width: Math.min(parent.width, parent.height)
                    height: width
                    radius: Look.squareControls ? Space.clampRadius(Space.smallRadius, width) : width / 2
                    visible: cell.modelData.today
                    color: Type.accent
                    opacity: Look.solidActive ? 1 : 0.16
                }

                KitText {
                    anchors.centerIn: parent
                    role: cell.modelData.inMonth ? "secondary" : "caption"
                    tabular: true
                    text: cell.modelData.day
                    color: cell.modelData.today ? (Look.solidActive ? Type.accentInk : Type.accent) : (cell.modelData.inMonth ? Type.text : Type.muted)
                    font.weight: cell.modelData.today ? Look.activeLabelWeight : Font.Normal
                    opacity: cell.modelData.inMonth ? 1 : 0.6
                }
            }
        }
    }

    Repeater {
        model: events.available ? events.events : []

        ListRow {
            required property var modelData
            width: parent.width
            title: modelData.title
            subtitle: modelData.time !== "" ? modelData.date + " · " + modelData.time : modelData.date
        }
    }
}
