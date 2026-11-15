import QtQuick
import qs.modules.settings.live
import "../live/LivePatch.js" as LivePatch

// Card picture of a dock style (dock.theme): your real dock (live/LiveDock:
// your apps, size and indicators) in style `value`: "default" standing on
// the edge, "floating" above it; "integrated" is your bar hosting it
// (live/LivePanel, a classic bar). Live (they follow every change): at a
// size where the icons read,
// the dock's two ends when it is longer than the card.
MiniScreen {
    id: root

    property var entry
    property var value: "default"
    readonly property bool integrated: String(root.value) === "integrated"

    LiveDock {
        id: dock
        anchors.fill: parent
        anchors.margins: Math.round(root.u * 5)
        active: !root.integrated
        // the icons at a size they read, the dock's two ends when it is
        // longer than the card (its shoulders, its pill, its end buttons)
        minZoom: 0.55
        cut: "ends"
        overrides: ({
                "dock.theme": String(root.value)
            })
    }

    LivePanel {
        anchors.fill: parent
        anchors.margins: Math.round(root.u * 5)
        active: root.integrated
        // your bar (classic: the style that hosts it) on your screen, its
        // middle where the dock sits, at a size where it reads
        nativeWidth: LiveTarget.width
        nativeHeight: 200
        readableGlyph: 10
        maxZoom: 1
        // (its middle: where the dock sits)
        cut: "center"
        patch: LivePatch.style("classic")
        overrides: ({
                "dock.theme": "integrated",
                "dock.enabled": true
            })
    }
}
