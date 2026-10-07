import QtQuick
import qs.modules.theme
import qs.modules.services
import qs.modules.components.kit

// Top of the clock panel: the time in the display role over the full date
// (secondary); on the right the weather now (`showWeather`) or, in the
// bento style (`editable`), the pencil that toggles bento edit mode.
Item {
    id: root

    property date now: new Date()
    property bool use12h: false
    property bool editable: false
    property bool editing: false
    property bool showWeather: true
    signal editToggled

    readonly property var dayKeys: ["sunday", "monday", "tuesday", "wednesday", "thursday", "friday", "saturday"]
    readonly property var monthKeys: ["january", "february", "march", "april", "may", "june", "july", "august", "september", "october", "november", "december"]
    readonly property string dateText: I18n.t("calendar.day_full." + root.dayKeys[root.now.getDay()]) + ", " + I18n.t("calendar.month." + root.monthKeys[root.now.getMonth()]) + " " + root.now.getDate()

    implicitWidth: texts.implicitWidth + Space.l + Math.max(weather.implicitWidth, edit.implicitWidth)
    implicitHeight: texts.implicitHeight

    Column {
        id: texts
        anchors.left: parent.left
        anchors.right: side.left
        anchors.rightMargin: Space.m
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
            text: root.dateText
        }
    }

    Item {
        id: side
        anchors.right: parent.right
        anchors.top: parent.top
        anchors.topMargin: Space.s
        width: root.editable ? edit.width : weather.implicitWidth
        height: Math.max(weather.implicitHeight, edit.height)

        ClockWeatherNow {
            id: weather
            visible: root.showWeather && !root.editable && weather.ready
        }
        IconButton {
            id: edit
            objectName: "clockPanelEdit"
            visible: root.editable
            size: "s"
            icon: root.editing ? Icons.check : Icons.pencil
            active: root.editing
            Accessible.name: I18n.t(root.editing ? "bento.done" : "bento.edit")
            onClicked: root.editToggled()
        }
    }
}
