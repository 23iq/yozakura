pragma ComponentBehavior: Bound

import QtQuick
import qs.config
import qs.modules.services
import "DockMagnify.js" as DockMagnify
import qs.modules.theme

// Pinned + running apps (TaskbarApps). On a dock panel: big icons with
// running dots, magnification and launch bounce (dock.magnification,
// dock.magnificationScale, dock.launchBounce); elsewhere a taskbar row
// (moduleOptions.taskbar: showPinned, showLabels).
BarModuleBase {
    id: root

    moduleKey: "taskbar"

    readonly property bool dock: panelStyle === "dock"
    readonly property bool showPinned: options.showPinned !== false
    readonly property bool showLabels: !dock && options.showLabels === true
    readonly property var apps: TaskbarApps.apps.filter(a => a && (a.appId === "SEPARATOR" ? showPinned : (showPinned || (a.toplevels && a.toplevels.length > 0))))
    readonly property bool magnifyOn: dock && Config.dock && Config.dock.magnification === true
    readonly property real maxScale: Config.dock && Config.dock.magnificationScale ? Config.dock.magnificationScale : 1.6
    // Pointer position along the row (-1 when outside)
    property real pointer: -1

    readonly property int spacing: dock ? 4 : 2
    // Resting (unmagnified) centers along the row; magnified icons spill
    // over their neighbours without moving the pointer's frame of reference
    readonly property var restCenters: {
        const out = [];
        let pos = 0;
        for (let i = 0; i < apps.length; i++) {
            const w = apps[i].appId === "SEPARATOR" ? Math.round(moduleSize * 0.32) : moduleSize;
            out.push(pos + w / 2);
            pos += w + spacing;
        }
        return out;
    }
    readonly property real restLength: apps.length > 0 ? restCenters[apps.length - 1] + (apps[apps.length - 1].appId === "SEPARATOR" ? Math.round(moduleSize * 0.32) : moduleSize) / 2 : 0

    // Room for magnified icons to spread into, constant so the pointer's
    // frame of reference never moves under it
    readonly property real spreadPad: magnifyOn ? Math.round((maxScale - 1) * moduleSize * 1.1) : 0

    contentLength: magnifyOn ? restLength + 2 * spreadPad : (vertical ? list.implicitHeight : list.implicitWidth)

    HoverHandler {
        id: hover
        enabled: root.magnifyOn
        onPointChanged: root.pointer = root.vertical ? point.position.y : point.position.x
        onHoveredChanged: if (!hovered)
            root.pointer = -1
    }

    Grid {
        id: list
        anchors.centerIn: parent
        rows: root.vertical ? -1 : 1
        columns: root.vertical ? 1 : -1
        spacing: root.spacing

        Repeater {
            model: root.apps
            delegate: TaskbarButton {
                id: button
                required property var modelData
                required property int index
                app: modelData
                dock: root.dock
                vertical: root.vertical
                edge: root.edge
                cell: root.moduleSize
                showLabel: root.showLabels
                bounceOnLaunch: root.dock && Config.dock && Config.dock.launchBounce === true
                magnify: root.magnifyOn && root.pointer >= 0 && !separator ? DockMagnify.scaleAt(root.pointer - root.spreadPad - root.restCenters[index], root.moduleSize, root.maxScale) : 1
                Behavior on magnify {
                    enabled: Config.animDuration > 0
                    NumberAnimation {
                        duration: Motion.morph.duration
                        easing.type: Motion.morph.easing
                    }
                }
            }
        }
    }
}
