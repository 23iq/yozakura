pragma ComponentBehavior: Bound
import QtQuick
import qs.modules.theme
import qs.modules.services
import qs.modules.components.kit
import "../../../services/timers/TimerFormat.js" as TimerFormat

// One reminder as a ListRow: message, wall-clock time and time left; cancel.
ListRow {
    id: row

    property var reminder: null
    property real unit: Space.xs

    readonly property var r: row.reminder || ({})

    title: row.r.message || I18n.t("timers.reminder")
    subtitle: I18n.t("timers.reminder_at", TimerFormat.timeOfDay(row.r.at || 0, TimersService.use12h), TimerFormat.compact(row.r.leftMs || 0))

    leading: Component {
        Art {
            width: Space.controlS
            height: Space.controlS
            icon: Icons.alarm
        }
    }
    trailing: Component {
        IconButton {
            objectName: "reminderCancel"
            size: "s"
            icon: Icons.cancel
            Accessible.name: I18n.t("timers.cancel")
            onClicked: TimersService.reminderCancel(row.r.id)
        }
    }
}
