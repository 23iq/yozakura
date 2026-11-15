pragma ComponentBehavior: Bound

import QtQuick
import qs.config
import qs.modules.components.preview

// The real panels of a screen at its native size (give it LiveTarget's
// size; the parent scales it): every bar panel (LiveBars) and the dock
// (modules/dock/DockContent.qml, by URL), each the shell's own component
// with a PreviewContext. Inert: it takes no input. Geometry for the page,
// in native px of this item: `bars` (LiveBars), `depth(edge)` (bars),
// `dockOn`, `dockEdge`, `dockDepth`, `dockRect()`.
Item {
    id: root

    property var screen: LiveTarget.screen
    property var preview: PreviewContext {}
    property bool showDock: true
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
}
