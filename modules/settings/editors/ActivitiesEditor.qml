import QtQuick
import qs.modules.widgets.dashboard.controls
import qs.modules.settings.store

// Live activities (notch.liveActivities): reuses the existing group editor
// (master switch, presentation, max visible, downloads, sources), writing
// through SettingsStore.set like every row.
Item {
    id: root

    property var entry

    implicitHeight: group.implicitHeight

    BarActivitiesSettings {
        id: group
        width: root.width
        write: v => SettingsStore.set("notch.liveActivities", v)
    }
}
