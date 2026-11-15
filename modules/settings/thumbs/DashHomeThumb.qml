import QtQuick
import qs.modules.theme
import qs.modules.components.kit
import qs.modules.settings.store
import qs.modules.settings.live

// Card picture of the dashboard's home view (layout.dashboard.home): the
// real dashboard (live/LiveHosted, Dashboard.qml) with home `value` (the
// stage, the composed home or your widget grid) and your live widgets,
// centred in its frame. Pictured once, again when the look changes.
MiniScreen {
    id: root

    property var entry
    property var value: "stage"
    // pictured again when what it shows changes
    readonly property var look: [SettingsStore.get("layout.dashboard.tabs"), SettingsStore.get("layout.dashboard.grid"), SettingsStore.get("layout.dashboard.heroTint"), SettingsStore.get("layout.dashboard.showMetrics"), String(Colors.primary), String(Colors.background), Look.language]

    LiveHosted {
        anchors.fill: parent
        anchors.margins: Math.round(root.u * 2)
        surface: "dashboard"
        host: "spotlight"
        margin: 0
        source: Qt.resolvedUrl("../../widgets/dashboard/Dashboard.qml")
        snapshot: true
        settleMs: 500
        refreshKey: root.look
        overrides: ({
                "layout.dashboard.home": String(root.value)
            })
        samples: ({
                "dashboard.tab": 0
            })
    }
}
