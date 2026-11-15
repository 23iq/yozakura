pragma ComponentBehavior: Bound

import QtQuick
import qs.modules.theme
import qs.modules.settings.store
import qs.modules.settings.live

// Card picture of the island's screen edge (notch.position): your island
// at rest, the shell's own (live/LiveIsland), on edge `value`, in a piece
// of the screen around it: along the top or bottom edge it lies along it,
// on a side edge it stands upright, as the shell lays it out there.
// Pictured once, again when the island's look changes.
MiniScreen {
    id: root

    property var entry
    property var value: "top"
    // pictured again when the island or the colours change
    readonly property string look: JSON.stringify([SettingsStore.get("notch.style"), SettingsStore.get("notch.align"), SettingsStore.get("notch.noMediaDisplay"), SettingsStore.get("theme.roundness"), String(Colors.primary), String(Colors.background)])

    LiveIsland {
        anchors.fill: parent
        snapshot: true
        refreshKey: root.look
        // a quarter of the screen's width in the picture
        zoom: root.width / (LiveTarget.width * 0.26)
        overrides: ({
                "notch.position": String(root.value)
            })
    }
}
