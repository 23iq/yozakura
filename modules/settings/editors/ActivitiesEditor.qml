import QtQuick
import qs.modules.widgets.dashboard.controls

// Live activities (bar.activities): reuses the existing group editor
// (master switch, presentation, max visible, downloads, sources). It stages
// through GlobalStates.markShellChanged like every shell key.
Item {
    id: root

    property var entry

    implicitHeight: group.implicitHeight

    BarActivitiesSettings {
        id: group
        width: root.width
    }
}
