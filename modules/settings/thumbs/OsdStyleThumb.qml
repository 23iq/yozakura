pragma ComponentBehavior: Bound

import QtQuick
import qs.modules.theme
import qs.modules.services
import qs.modules.components.kit
import qs.modules.components.preview
import qs.modules.settings.store
import qs.modules.settings.live
import "../live/LivePatch.js" as LivePatch
import "../live/LiveSamples.js" as LiveSamples
import "../../shell/osd/OsdStyles.js" as OsdStyles

// Card picture of an OSD style (layout.osd.style): the real style
// component (by URL, live/LivePart: inert, built after the page) showing a
// volume level; "in the bar" is your bar (live/LivePanel) whose controls
// button holds the level, as the shell grows it there. The styles are
// pictured once, again when the look changes.
MiniScreen {
    id: root

    property var entry
    property var value: "pill"
    readonly property string style: OsdStyles.normalize(root.value)
    readonly property bool inline: root.style === "bar-inline"
    readonly property var size: OsdStyles.sizeFor(root.style, false, Metrics.osdW)
    // pictured again when the colours or the type change
    readonly property var look: [String(Colors.primary), String(Colors.background), SettingsStore.get("theme.font"), SettingsStore.get("theme.roundness")]

    LivePart {
        anchors.fill: parent
        anchors.margins: Math.round(root.u * 9)
        active: !root.inline
        snapshot: true
        refreshKey: JSON.stringify(root.look)
        source: Qt.resolvedUrl("../../shell/osd/" + OsdStyles.fileFor(root.style))
        nativeWidth: root.size.w
        nativeHeight: root.size.h
        properties: LiveSamples.osd()
        // its text at a size it reads; a long one shows its two ends
        readableGlyph: 10
        cut: "ends"
    }

    LivePanel {
        anchors.fill: parent
        anchors.margins: Math.round(root.u * 5)
        active: root.inline
        snapshot: true
        nativeWidth: 640
        frame: "modules"
        readableGlyph: 10
        cut: "ends"
        patch: LivePatch.only(["controls"])
        samples: ({
                "osd": LiveSamples.osd()
            })
    }
}
