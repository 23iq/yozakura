import QtQuick
import qs.modules.theme
import qs.modules.settings.store
import qs.modules.settings.live
import "../live/LivePatch.js" as LivePatch

// Card picture of a dock style (dock.theme): your real dock (live/LiveDock:
// your apps, size and indicators) in style `value`: "default" standing on
// the edge, "floating" above it; "integrated" is your bar hosting it
// (live/LivePanel, a classic bar). Pictured once, again when it changes.
MiniScreen {
    id: root

    property var entry
    property var value: "default"
    readonly property bool integrated: String(root.value) === "integrated"
    // pictured again when the dock or the colours change
    readonly property string look: JSON.stringify([SettingsStore.get("dock.iconSize"), SettingsStore.get("dock.height"), SettingsStore.get("dock.spacing"), SettingsStore.get("dock.indicator"), SettingsStore.get("dock.showPinButton"), SettingsStore.get("dock.showOverviewButton"), String(Colors.primary), String(Colors.background)])

    LiveDock {
        id: dock
        anchors.fill: parent
        anchors.margins: Math.round(root.u * 5)
        active: !root.integrated
        snapshot: true
        refreshKey: root.look
        overrides: ({
                "dock.theme": String(root.value)
            })
    }

    LivePanel {
        anchors.fill: parent
        anchors.margins: Math.round(root.u * 5)
        active: root.integrated
        snapshot: true
        refreshKey: root.look
        nativeWidth: 900
        patch: Object.assign(LivePatch.style("classic"), LivePatch.only(["launcher", "clock"]))
        overrides: ({
                "dock.theme": "integrated",
                "dock.enabled": true
            })
    }
}
