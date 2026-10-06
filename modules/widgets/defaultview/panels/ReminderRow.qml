import QtQuick
import qs.config
import qs.modules.theme
import qs.modules.services
import qs.modules.widgets.defaultview.activities
import "../../../services/timers/TimerFormat.js" as TimerFormat

// One reminder: message, wall-clock time and time left; cancel.
Item {
    id: row

    property var reminder: null
    property real unit: 4

    readonly property var r: row.reminder || ({})
    readonly property real iconSize: Math.round(Styling.fontSize(6))

    implicitHeight: Math.max(row.iconSize, textColumn.implicitHeight, cancel.implicitHeight) + row.unit * 2

    Text {
        id: glyph
        width: Math.round(row.iconSize * 0.96)
        anchors.verticalCenter: parent.verticalCenter
        horizontalAlignment: Text.AlignHCenter
        text: Icons.alarm
        font.family: Icons.font
        font.pixelSize: Math.round(row.iconSize * 0.7)
        color: Colors.secondary
    }

    Column {
        id: textColumn
        anchors.left: glyph.right
        anchors.leftMargin: row.unit * 2
        anchors.right: cancel.left
        anchors.rightMargin: row.unit * 2
        anchors.verticalCenter: parent.verticalCenter
        spacing: 1

        Text {
            width: parent.width
            text: row.r.message || I18n.t("timers.reminder")
            textFormat: Text.PlainText
            elide: Text.ElideRight
            color: Colors.overBackground
            font.family: Config.theme.font
            font.pixelSize: Styling.fontSize(-1)
            font.weight: Font.DemiBold
        }
        Text {
            width: parent.width
            text: I18n.t("timers.reminder_at", TimerFormat.timeOfDay(row.r.at || 0, TimersService.use12h), TimerFormat.compact(row.r.leftMs || 0))
            textFormat: Text.PlainText
            elide: Text.ElideRight
            color: Colors.overSurfaceVariant
            font.family: Config.theme.font
            font.pixelSize: Styling.fontSize(-2)
            font.features: ({
                    "tnum": 1
                })
        }
    }

    NotchIconButton {
        id: cancel
        objectName: "reminderCancel"
        anchors.right: parent.right
        anchors.verticalCenter: parent.verticalCenter
        icon: Icons.cancel
        tooltip: I18n.t("timers.cancel")
        onClicked: TimersService.reminderCancel(row.r.id)
    }
}
