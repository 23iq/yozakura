pragma ComponentBehavior: Bound
import QtQuick
import qs.modules.theme
import qs.modules.services
import qs.modules.components.kit
import "../widgets/CalendarModel.js" as CalendarModel
import "StageModel.js" as StageModel

// The week strip of the stage home: the month as the label, seven days
// (narrow weekday over the date; today selected, days with an event
// dotted, past days quiet). Clicking the strip or "Month" opens the full
// month as the home's detail (`openMonth()`).
Group {
    id: root

    property var events: []
    property date now: new Date()
    readonly property int firstDay: CalendarModel.firstDayOf("locale", Qt.locale().firstDayOfWeek)
    readonly property var days: StageModel.weekDays(root.now, root.firstDay)
    readonly property var marked: StageModel.eventDays(root.events)
    readonly property real dayH: Type.size("caption") * 1.4 + Space.xs + Space.controlS + Space.xs

    signal openMonth

    label: Qt.locale(I18n.resolvedLanguage).toString(root.now, "MMMM")
    actionText: I18n.t("dashboard.stage.month")
    onActionTriggered: root.openMonth()

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

    Item {
        objectName: "weekStrip"
        width: parent.width
        height: root.dayH

        MouseArea {
            anchors.fill: parent
            cursorShape: Qt.PointingHandCursor
            onClicked: root.openMonth()
        }

        Row {
            id: strip
            anchors.fill: parent

            Repeater {
                model: root.days

                Item {
                    id: cell
                    required property var modelData
                    width: strip.width / 7
                    height: strip.height

                    KitText {
                        anchors.horizontalCenter: parent.horizontalCenter
                        role: "caption"
                        text: Qt.locale(I18n.resolvedLanguage).dayName(cell.modelData.weekday, Locale.NarrowFormat)
                    }

                    Rectangle {
                        id: mark
                        objectName: cell.modelData.today ? "weekToday" : ""
                        anchors.horizontalCenter: parent.horizontalCenter
                        y: Type.size("caption") * 1.4 + Space.xs
                        width: Space.controlS
                        height: width
                        radius: Look.squareControls ? Space.clampRadius(Space.smallRadius, width) : width / 2
                        visible: cell.modelData.today
                        color: Type.accent
                        opacity: Look.solidActive ? 1 : 0.16
                    }

                    KitText {
                        anchors.centerIn: mark
                        tabular: true
                        text: cell.modelData.day
                        color: cell.modelData.today ? (Look.solidActive ? Type.accentInk : Type.accent) : (cell.modelData.past ? Type.muted : Type.text)
                        font.weight: cell.modelData.today ? Look.activeLabelWeight : Font.Normal
                    }

                    Rectangle {
                        objectName: "eventDot"
                        anchors.horizontalCenter: parent.horizontalCenter
                        anchors.top: mark.bottom
                        anchors.topMargin: Space.xs / 2
                        width: Space.xs
                        height: width
                        radius: width / 2
                        visible: root.marked[cell.modelData.iso] === true
                        color: Type.secondary
                    }
                }
            }
        }
    }
}
