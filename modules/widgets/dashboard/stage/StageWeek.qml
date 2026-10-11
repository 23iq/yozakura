pragma ComponentBehavior: Bound
import QtQuick
import qs.modules.theme
import qs.modules.services
import qs.modules.components
import qs.modules.components.kit
import "../widgets/CalendarModel.js" as CalendarModel
import "StageModel.js" as StageModel

// The week strip of the stage home: the month as the label, seven day
// pills (narrow weekday over the date, an accent dot on days with an
// event, past days quiet; today a solid accent pill, the others raise on
// hover). Clicking a day or "Month" opens the full month as the home's
// detail (`openMonth()`).
Group {
    id: root

    property var events: []
    property date now: new Date()
    readonly property int firstDay: CalendarModel.firstDayOf("locale", Qt.locale().firstDayOfWeek)
    readonly property var days: StageModel.weekDays(root.now, root.firstDay)
    readonly property var marked: StageModel.eventDays(root.events)
    readonly property real dayH: Space.controlL + Space.m

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

    Row {
        id: strip
        objectName: "weekStrip"
        width: parent.width
        height: root.dayH
        spacing: Space.xs

        Repeater {
            model: root.days

            Item {
                id: cell
                required property var modelData
                readonly property bool today: cell.modelData.today
                readonly property color ink: cell.today ? Type.accentInk : (cell.modelData.past ? Type.muted : Type.text)

                width: (strip.width - strip.spacing * 6) / 7
                height: strip.height

                // Raised pill on hover; today a solid accent pill.
                Rectangle {
                    anchors.fill: parent
                    radius: Look.bigRadius(width)
                    visible: !cell.today
                    color: Look.raisedFill(dayHover.containsMouse)
                    opacity: dayHover.containsMouse ? 1 : 0.6
                }

                StyledRect {
                    objectName: cell.today ? "weekToday" : ""
                    anchors.fill: parent
                    variant: "primary"
                    backgroundOpacity: 1
                    enableBorder: false
                    radius: Look.bigRadius(width)
                    visible: cell.today
                }

                Column {
                    anchors.centerIn: parent
                    spacing: Space.xs / 2

                    KitText {
                        anchors.horizontalCenter: parent.horizontalCenter
                        role: "caption"
                        color: cell.today ? cell.ink : Type.muted
                        text: Qt.locale(I18n.resolvedLanguage).dayName(cell.modelData.weekday, Locale.NarrowFormat)
                    }

                    KitText {
                        anchors.horizontalCenter: parent.horizontalCenter
                        role: "title"
                        tabular: true
                        text: cell.modelData.day
                        color: cell.ink
                        font.weight: cell.today ? Font.Bold : Look.labelWeight
                    }

                    // The event dot (a placeholder keeps the dates aligned).
                    Item {
                        anchors.horizontalCenter: parent.horizontalCenter
                        width: Space.xs + 2
                        height: width

                        Rectangle {
                            objectName: "eventDot"
                            anchors.fill: parent
                            radius: width / 2
                            visible: root.marked[cell.modelData.iso] === true
                            color: cell.today ? Type.accentInk : Type.accent
                        }
                    }
                }

                MouseArea {
                    id: dayHover
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: root.openMonth()
                }
            }
        }
    }
}
