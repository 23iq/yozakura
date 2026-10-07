pragma ComponentBehavior: Bound
import QtQuick
import qs.config
import qs.modules.desktop.widgets
import "WidgetGeometry.js" as Geometry
import qs.modules.theme

// The widgets of one screen (desktop.widgets placed on `screenName`), drawn
// on the desktop layer, plus the edit desktop mode (backdrop with the snap
// grid and the clock area, toolbar, drag/resize/remove). A widget the
// windows of the active workspace fully cover is hidden and inactive (no
// polling); `obscured` (fullscreen) hides them all.
Item {
    id: root

    property string screenName: ""
    // yozd monitor and client list, for window coverage (null = never covered).
    property var monitor: null
    property var windows: []
    property bool obscured: false
    // Area widgets may use, in screen pixels (outside the bar / frame).
    property var bounds: Geometry.rect(0, 0, width, height)

    readonly property bool editing: DesktopWidgets.editMode
    readonly property var widgets: DesktopWidgets.enabled ? DesktopWidgets.forScreen(screenName) : []
    readonly property var clockArea: DesktopWidgets.clockArea(screenName)
    readonly property int grid: Math.max(0, Config.desktop.widgetGrid ?? 24)

    function entry(id) {
        for (let i = 0; i < widgets.length; i++) {
            if (widgets[i].id === id)
                return widgets[i];
        }
        return null;
    }

    function addWidget(type) {
        const bar = toolbar.item as Item;
        const avoid = bar ? [Geometry.rect(toolbar.x, toolbar.y, bar.width, bar.height)] : [];
        DesktopWidgets.add(type, screenName, width, height, bounds, avoid);
    }

    onWidgetsChanged: ids.sync(widgets.map(w => w.id))
    Component.onCompleted: ids.sync(widgets.map(w => w.id))

    focus: editing
    Keys.onEscapePressed: DesktopWidgets.editMode = false

    WidgetIdModel {
        id: ids
    }

    EditBackdrop {
        anchors.fill: parent
        opacity: root.editing ? 1 : 0
        visible: opacity > 0
        grid: root.grid
        bounds: root.bounds
        clockArea: root.clockArea
        Behavior on opacity {
            enabled: Config.animDuration > 0
            NumberAnimation {
                duration: Motion.enter.duration
                easing.type: Motion.enter.easing
            }
        }
    }

    Repeater {
        model: ids
        WidgetFrame {
            id: frame
            required property string wid
            readonly property bool covered: !root.editing && Geometry.covered(frame.geom, root.monitor, root.windows)
            widget: root.entry(frame.wid)
            visible: frame.widget !== null && (root.editing || !(root.obscured || frame.covered))
            active: frame.visible
            screenW: root.width
            screenH: root.height
            bounds: root.bounds
            grid: root.grid
            editing: root.editing
            clockArea: root.clockArea
            onCommitted: rel => DesktopWidgets.update(frame.wid, rel)
            onRemoveRequested: DesktopWidgets.remove(frame.wid)
            onOptionChanged: (key, value) => DesktopWidgets.setOption(frame.wid, key, value)
        }
    }

    Loader {
        id: toolbar
        active: root.editing
        anchors.horizontalCenter: parent.horizontalCenter
        y: root.bounds.y + 16
        sourceComponent: EditToolbar {
            onAddRequested: type => root.addWidget(type)
            onDoneRequested: DesktopWidgets.editMode = false
        }
    }
}
