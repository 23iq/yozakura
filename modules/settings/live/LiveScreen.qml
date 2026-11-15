pragma ComponentBehavior: Bound

import QtQuick
import qs.config
import qs.modules.components.preview
import "LiveSamples.js" as LiveSamples

// The real panels of a screen at its native size (give it LiveTarget's
// size; the parent scales it): every bar panel (LiveBars), the dock
// (modules/dock/DockContent.qml, by URL) and the island at rest
// (modules/shell/NotchPreview.qml, by URL, LiveSamples' "rest": nothing
// playing, no notification), each the shell's own component with a
// PreviewContext. Inert: it takes no input. Geometry for the page, in
// native px of this item: `bars` (LiveBars), `depth(edge)` (bars),
// `dockOn`, `dockEdge`, `dockDepth`, `dockRect()`, `islandOn`,
// `islandRect()`.
Item {
    id: root

    property var screen: LiveTarget.screen
    // the screen the island places itself on ({name, width, height}: the
    // overview's when this item is laid out smaller than the real screen)
    property var islandScreen: root.screen
    property var preview: PreviewContext {}
    property bool showDock: true
    property bool showIsland: true
    readonly property alias bars: bars

    enabled: false

    readonly property Item dock: dockLoader.item as Item
    readonly property bool dockOn: root.showDock && !!root.dock && Config.dock.enabled !== false && !(Config.dock.theme === "integrated" && root.integratedHosted)
    // an integrated dock lives in the primary bar when it is a classic one
    readonly property bool integratedHosted: {
        for (const k in bars.bars) {
            const b = bars.bars[k];
            if (b && b.integratedDockEnabled)
                return true;
        }
        return false;
    }
    readonly property string dockEdge: root.dock ? root.dock.position : "bottom"
    // the room the dock takes on its edge (as the shell reserves it)
    readonly property real dockDepth: root.dockOn ? root.dock.dockSize + root.dock.totalMargin : 0
    function dockRect() {
        return root.dockOn ? root.dock.surfaceRect : Qt.rect(0, 0, 0, 0);
    }
    function depth(edge) {
        return bars.depth(edge);
    }

    readonly property Item island: islandLoader.item as Item
    readonly property bool islandOn: root.showIsland && !!root.island && Config.notch.enabled !== false
    function islandRect() {
        return root.islandOn ? root.island.notchRect : Qt.rect(0, 0, 0, 0);
    }
    PreviewContext {
        id: islandContext
        overrides: root.preview ? root.preview.overrides : ({})
        samples: LiveSamples.island("rest", 0, "", null)
    }

    LiveBars {
        id: bars
        anchors.fill: parent
        screen: root.screen
        preview: root.preview
    }

    Loader {
        id: dockLoader
        anchors.fill: parent
        asynchronous: true
        active: root.showDock && !!root.screen && Config.dock.enabled !== false
        visible: root.dockOn
        Component.onCompleted: LiveGate.ask(dockLoader, () => dockLoader.setSource(Qt.resolvedUrl("../../dock/DockContent.qml"), {
                "screen": root.screen,
                "preview": root.preview
            }))
        Component.onDestruction: LiveGate.forget(dockLoader)
    }

    Loader {
        id: islandLoader
        anchors.fill: parent
        asynchronous: true
        active: root.showIsland && !!root.screen && Config.notch.enabled !== false
        visible: root.islandOn
        Component.onCompleted: LiveGate.ask(islandLoader, () => islandLoader.setSource(Qt.resolvedUrl("../../shell/NotchPreview.qml"), {
                "screen": root.islandScreen,
                "preview": islandContext
            }))
        Component.onDestruction: LiveGate.forget(islandLoader)
    }
}
