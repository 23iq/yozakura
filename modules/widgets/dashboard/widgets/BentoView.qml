pragma ComponentBehavior: Bound
import QtQuick
import qs.modules.theme
import qs.modules.components
import qs.modules.services
import qs.config
import "BentoGrid.js" as BentoGrid
import "WidgetRegistry.js" as WidgetRegistry
// Reaches time/ for Quickshell's scanner (widgets are loaded by URL).
import "time"

// Bento grid of registry widgets, editable in place. Host-agnostic: the host
// passes `cols` and the saved `cells`, binds `editing` and stores the cells
// it gets from `commit` (emitted when edit mode ends).
//
// Edit mode: drag a tile (snap ghost), resize from its corner, x removes,
// toolbar adds/resets/finishes. Keyboard: Tab/Shift+Tab select a tile,
// arrows move it, Shift+arrows resize it, Delete removes it, Insert/+ opens
// the picker, Escape or Enter finishes.
Item {
    id: root

    // {ids(), byId(id), defaultGrid(cols)}; another host may pass its own.
    property var registry: ({
            "ids": WidgetRegistry.ids,
            "byId": WidgetRegistry.byId,
            "defaultGrid": WidgetRegistry.defaultGrid
        })
    property int cols: 4
    property var cells: []
    property bool editing: false
    property real cellH: Metrics.bentoCell
    property real gap: Metrics.spacing

    signal commit(var cells)
    signal editingRequested(bool on)

    readonly property real cellW: Math.max(1, (width - (cols - 1) * gap) / cols)
    readonly property var normalized: BentoGrid.normalize(cells, cols, registry)
    property var working: []
    property var preview: null
    property string activeId: ""
    property string selectedId: ""
    readonly property var shown: editing ? (preview || working) : normalized
    readonly property int rows: BentoGrid.rows(shown)
    readonly property real gridHeight: Math.max(0, rows * (cellH + gap) - gap)
    readonly property var available: BentoGrid.available(shown, registry)

    implicitWidth: cols * Metrics.bentoCell + (cols - 1) * gap
    implicitHeight: gridHeight

    function cellOf(list, id) {
        for (let i = 0; i < list.length; i++)
            if (list[i].widget === id)
                return list[i];
        return null;
    }

    function apply(next) {
        working = next;
        preview = null;
        activeId = "";
    }

    function dragTo(id, px, py) {
        const s = BentoGrid.snap(px, py, cellW, gap, cellH);
        activeId = id;
        preview = BentoGrid.move(working, id, s.x, s.y, cols, registry);
    }

    function resizeTo(id, pw, ph) {
        activeId = id;
        preview = BentoGrid.resize(working, id, BentoGrid.span(pw, cellW, gap), BentoGrid.span(ph, cellH, gap), cols, registry);
    }

    function endGesture() {
        apply(preview || working);
    }

    function nudge(id, dx, dy, grow) {
        const c = cellOf(working, id);
        if (!c)
            return;
        apply(grow ? BentoGrid.resize(working, id, c.w + dx, c.h + dy, cols, registry) : BentoGrid.move(working, id, c.x + dx, c.y + dy, cols, registry));
    }

    function removeTile(id) {
        apply(BentoGrid.remove(working, id));
        if (selectedId === id)
            selectedId = "";
    }

    function addWidget(id) {
        apply(BentoGrid.add(working, id, cols, registry));
        selectedId = id;
        picker.visible = false;
        root.forceActiveFocus();
        const c = cellOf(working, id);
        if (c)
            flick.contentY = Math.max(0, Math.min(c.y * (cellH + gap), flick.contentHeight - flick.height));
    }

    function resetLayout() {
        apply(BentoGrid.normalize([], cols, registry));
    }

    function selectNext(delta) {
        const order = working.map(c => c.widget);
        if (order.length === 0)
            return;
        const i = order.indexOf(selectedId);
        selectedId = order[i < 0 ? 0 : (i + delta + order.length) % order.length];
    }

    onEditingChanged: {
        if (editing) {
            apply(normalized);
            selectedId = "";
            root.forceActiveFocus();
            for (let i = 0; i < tiles.count; i++) {
                const t = tiles.itemAt(i) as BentoTile;
                if (t && t.visible)
                    t.pulse();
            }
        } else {
            picker.visible = false;
            const out = BentoGrid.serialize(preview || working);
            preview = null;
            activeId = "";
            selectedId = "";
            if (JSON.stringify(out) !== JSON.stringify(BentoGrid.serialize(normalized)))
                commit(out);
        }
    }

    Keys.onPressed: event => {
        if (!root.editing)
            return;
        const shift = (event.modifiers & Qt.ShiftModifier) !== 0;
        const dirs = {
            [Qt.Key_Left]: [-1, 0],
            [Qt.Key_Right]: [1, 0],
            [Qt.Key_Up]: [0, -1],
            [Qt.Key_Down]: [0, 1]
        };
        if (event.key === Qt.Key_Escape || event.key === Qt.Key_Return || event.key === Qt.Key_Enter) {
            root.editingRequested(false);
        } else if (event.key === Qt.Key_Tab || event.key === Qt.Key_Backtab) {
            root.selectNext(event.key === Qt.Key_Backtab || shift ? -1 : 1);
        } else if (dirs[event.key] !== undefined) {
            if (root.selectedId === "")
                root.selectNext(1);
            else
                root.nudge(root.selectedId, dirs[event.key][0], dirs[event.key][1], shift);
        } else if ((event.key === Qt.Key_Delete || event.key === Qt.Key_Backspace) && root.selectedId !== "") {
            root.removeTile(root.selectedId);
        } else if (event.key === Qt.Key_Insert || event.key === Qt.Key_Plus) {
            picker.open();
        } else {
            return;
        }
        event.accepted = true;
    }

    Flickable {
        id: flick
        anchors.fill: parent
        contentWidth: width
        contentHeight: root.gridHeight + (root.editing ? toolbar.height + root.gap * 2 : 0)
        interactive: root.activeId === "" && contentHeight > height
        boundsBehavior: Flickable.StopAtBounds
        clip: true

        Item {
            id: canvas
            width: flick.width
            height: root.gridHeight

            // Snap ghost: where the dragged or resized tile will land.
            StyledRect {
                id: ghost
                objectName: "bentoGhost"
                readonly property var c: root.activeId !== "" && root.preview ? root.cellOf(root.preview, root.activeId) : null
                visible: c !== null
                variant: "primary"
                backgroundOpacity: 0.22
                radius: Styling.radius(4)
                x: c ? c.x * (root.cellW + root.gap) : 0
                y: c ? c.y * (root.cellH + root.gap) : 0
                width: c ? c.w * root.cellW + (c.w - 1) * root.gap : 0
                height: c ? c.h * root.cellH + (c.h - 1) * root.gap : 0

                Behavior on x {
                    enabled: Motion.enter.duration > 0
                    NumberAnimation {
                        duration: Motion.enter.duration
                        easing.type: Motion.enter.easing
                    }
                }
                Behavior on y {
                    enabled: Motion.enter.duration > 0
                    NumberAnimation {
                        duration: Motion.enter.duration
                        easing.type: Motion.enter.easing
                    }
                }
            }

            Repeater {
                id: tiles
                model: root.registry.ids()

                delegate: BentoTile {
                    id: tileDelegate

                    required property string modelData
                    readonly property var placed: root.cellOf(modelData === root.activeId ? root.working : root.shown, modelData)

                    entry: root.registry.byId(modelData)
                    present: placed !== null
                    cell: placed || ({
                            "x": 0,
                            "y": 0,
                            "w": 1,
                            "h": 1
                        })
                    cellW: root.cellW
                    cellH: root.cellH
                    gap: root.gap
                    editing: root.editing
                    selected: root.editing && root.selectedId === modelData
                    onPressed: {
                        root.selectedId = modelData;
                        root.forceActiveFocus();
                    }
                    onDragMoved: (px, py) => root.dragTo(modelData, px, py)
                    onResizeMoved: (pw, ph) => root.resizeTo(modelData, pw, ph)
                    onDragEnded: root.endGesture()
                    onResizeEnded: root.endGesture()
                    onRemoveRequested: root.removeTile(modelData)
                }
            }
        }
    }

    BentoToolbar {
        id: toolbar
        objectName: "bentoToolbar"
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.bottom: parent.bottom
        anchors.bottomMargin: root.gap
        canAdd: root.available.length > 0
        visible: opacity > 0
        opacity: root.editing ? 1 : 0
        onAddRequested: picker.open()
        onResetRequested: root.resetLayout()
        onDoneRequested: root.editingRequested(false)

        Behavior on opacity {
            enabled: Motion.enter.duration > 0
            NumberAnimation {
                duration: root.editing ? Motion.enter.duration : Motion.exit.duration
                easing.type: root.editing ? Motion.enter.easing : Motion.exit.easing
            }
        }
    }

    WidgetPicker {
        id: picker
        objectName: "bentoPicker"
        anchors.centerIn: parent
        visible: false
        z: 20
        registry: root.registry
        ids: root.available
        onPicked: id => root.addWidget(id)
        onClosed: root.forceActiveFocus()
    }
}
