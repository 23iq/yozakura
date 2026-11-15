pragma ComponentBehavior: Bound

import QtQuick
import qs.modules.theme
import qs.modules.settings.store
import qs.modules.settings.live

// Card picture of the island's shape (notch.style): your island at rest,
// the shell's own (live/LiveIsland), in shape `value`, hanging from the
// picture's top edge (your edge when it is the bottom one) as from the
// screen's: "attached" flows out of the edge, "island" floats under it,
// "pill" rests as a small capsule (at about the others' scale). Pictured
// once, again when the island's look changes.
MiniScreen {
    id: root

    property var entry
    property var value: "attached"
    readonly property string edge: SettingsStore.get("notch.position") === "bottom" ? "bottom" : "top"
    // pictured again when the island or the colours change
    readonly property string look: JSON.stringify([root.edge, SettingsStore.get("notch.noMediaDisplay"), SettingsStore.get("notch.customText"), SettingsStore.get("theme.roundness"), SettingsStore.get("theme.font"), String(Colors.primary), String(Colors.background)])

    LiveIsland {
        id: live
        anchors.fill: parent
        snapshot: true
        refreshKey: root.look
        anchors.margins: Math.round(root.u * 4)
        // the island and its edge, at a size where its text reads; a long
        // island shows its two ends (the fillets, the float, the capsule)
        frame: "island"
        readableGlyph: 10
        cut: "ends"
        overrides: ({
                "notch.style": String(root.value),
                "notch.position": root.edge,
                "notch.align": "center"
            })
    }
}
