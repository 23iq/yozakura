pragma ComponentBehavior: Bound

import QtQuick
import qs.modules.theme
import qs.modules.services
import qs.config
import qs.modules.settings
import qs.modules.settings.controls
import "../BarModules.js" as BarModules
import "../Ui.js" as Ui

// Generic drag & drop editor of bar modules split in groups (the legacy
// bar.layout editor and the panels editor use it). One MouseArea on top
// owns the gesture, so chips can be re-created while they move (the drop
// slot reflows the groups live). Keyboard: click a chip, arrows move it
// (Up/Down change group), Delete removes it, Enter adds an available one.
// Hosts read display(group) for a live preview of the drag.
Item {
    id: root

    // [{id, title, icon, hint}] in display order
    property var groups: []
    // {groupId: [moduleId...]}
    property var layout: ({})
    property var available: []
    // Group Enter adds an available module to
    property string addGroup: groups.length > 0 ? groups[groups.length - 1].id : ""
    signal moveRequested(string moduleId, string group, int index)

    readonly property var groupOrder: groups.map(g => g.id).concat(["available"])
    readonly property bool wide: width >= 640
    readonly property int columns: wide ? Math.min(3, Math.max(1, groups.length)) : 1
    readonly property real rowHeight: {
        let h = 0;
        for (let i = 0; i < zoneRepeater.count; i++) {
            const z = zoneRepeater.itemAt(i) as Zone;
            if (z)
                h = Math.max(h, z.naturalHeight);
        }
        return h;
    }

    property string selectedId: ""
    property string hoverId: ""
    property string pressId: ""
    property point pressPos: Qt.point(0, 0)
    property bool dragging: false
    property point dragPos: Qt.point(0, 0)
    property string dropGroup: ""
    property int dropIndex: -1
    property point lastDropPos: Qt.point(-100, -100)

    implicitHeight: column.implicitHeight
    activeFocusOnTab: true

    function moveTo(id, group, index) {
        moveRequested(id, group, index === undefined ? -1 : index);
    }

    // Items shown in a zone: the group's modules, with the drop slot.
    function display(group) {
        let ids = group === "available" ? available.slice() : (layout[group] || []).slice();
        if (dragging) {
            const own = ids.indexOf(pressId);
            if (own !== -1 && dropGroup === group)
                ids.splice(own, 1);
            if (dropGroup === group)
                ids.splice(Math.max(0, Math.min(dropIndex, ids.length)), 0, "__slot__");
        }
        return ids;
    }

    function zoneItems() {
        const out = [];
        for (let i = 0; i < zoneRepeater.count; i++) {
            const z = zoneRepeater.itemAt(i);
            if (z)
                out.push(z);
        }
        out.push(availableZone);
        return out;
    }

    function zoneAt(p) {
        const zones = zoneItems();
        for (let i = 0; i < zones.length; i++) {
            const z = zones[i];
            const q = z.mapFromItem(root, p.x, p.y);
            if (q.x >= 0 && q.y >= 0 && q.x <= z.width && q.y <= z.height)
                return z;
        }
        return null;
    }

    function chipAt(p) {
        const z = zoneAt(p);
        if (!z)
            return null;
        const chips = z.chipItems();
        for (let i = 0; i < chips.length; i++) {
            const c = chips[i];
            const q = c.mapFromItem(root, p.x, p.y);
            if (q.x >= 0 && q.y >= 0 && q.x <= c.width && q.y <= c.height)
                return c;
        }
        return null;
    }

    // Insertion index among a zone's chips (slot and dragged chip skipped).
    function indexIn(zone, p) {
        const chips = zone.chipItems().filter(c => c.moduleId !== "__slot__" && c.moduleId !== pressId);
        let idx = 0;
        for (let i = 0; i < chips.length; i++) {
            const c = chips[i].mapToItem(root, 0, 0);
            const w = chips[i].width;
            const h = chips[i].height;
            if (p.y > c.y + h || (p.y >= c.y && p.x > c.x + w / 2))
                idx = i + 1;
        }
        return idx;
    }

    function updateDrop(p) {
        const z = zoneAt(p);
        if (!z) {
            dropGroup = "";
            return;
        }
        if (z.group === dropGroup && Math.abs(p.x - lastDropPos.x) < 6 && Math.abs(p.y - lastDropPos.y) < 6)
            return;
        lastDropPos = p;
        dropGroup = z.group;
        dropIndex = z.group === "available" ? 0 : indexIn(z, p);
    }

    function endDrag(apply) {
        if (apply && dropGroup !== "")
            moveTo(pressId, dropGroup, dropIndex);
        dragging = false;
        dropGroup = "";
        dropIndex = -1;
        pressId = "";
    }

    function where(id) {
        for (let g = 0; g < groups.length; g++) {
            const i = (layout[groups[g].id] || []).indexOf(id);
            if (i !== -1)
                return {
                    "group": groups[g].id,
                    "index": i
                };
        }
        return {
            "group": "available",
            "index": available.indexOf(id)
        };
    }

    Keys.onPressed: event => {
        if (!selectedId)
            return;
        const at = where(selectedId);
        let handled = true;
        if (event.key === Qt.Key_Left && at.group !== "available")
            moveTo(selectedId, at.group, Math.max(0, at.index - 1));
        else if (event.key === Qt.Key_Right && at.group !== "available")
            moveTo(selectedId, at.group, at.index + 1);
        else if (event.key === Qt.Key_Up || event.key === Qt.Key_Down) {
            const gi = groupOrder.indexOf(at.group);
            const next = groupOrder[(gi + (event.key === Qt.Key_Down ? 1 : groupOrder.length - 1)) % groupOrder.length];
            moveTo(selectedId, next, -1);
        } else if (event.key === Qt.Key_Delete || event.key === Qt.Key_Backspace)
            moveTo(selectedId, "available", -1);
        else if ((event.key === Qt.Key_Return || event.key === Qt.Key_Enter) && at.group === "available")
            moveTo(selectedId, addGroup, -1);
        else if (event.key === Qt.Key_Escape)
            selectedId = "";
        else
            handled = false;
        event.accepted = handled;
    }

    Column {
        id: column
        width: parent.width
        spacing: 14

        Grid {
            id: zones
            width: parent.width
            columns: root.columns
            spacing: 10

            Repeater {
                id: zoneRepeater
                model: root.groups
                delegate: Zone {
                    required property var modelData
                    group: modelData.id
                    icon: modelData.icon
                    title: modelData.title
                    hint: modelData.hint || ""
                }
            }
        }

        Zone {
            id: availableZone
            width: parent.width
            group: "available"
            icon: "plus"
            title: I18n.t("prefs.bar.group.available")
            hint: I18n.t("prefs.bar.group.available.hint")
        }

        Text {
            width: parent.width
            wrapMode: Text.WordWrap
            text: I18n.t("prefs.bar.layout.keys")
            font.family: Config.theme.font
            font.pixelSize: Styling.fontSize(-3)
            color: Ui.alpha(Colors.overSurfaceVariant, 0.8)
        }
    }

    // Owns press / drag / click for every chip.
    MouseArea {
        id: input
        anchors.fill: parent
        hoverEnabled: true
        preventStealing: true
        cursorShape: root.dragging ? Qt.ClosedHandCursor : (root.hoverId ? Qt.OpenHandCursor : Qt.ArrowCursor)

        onPressed: mouse => {
            const chip = root.chipAt(Qt.point(mouse.x, mouse.y));
            if (!chip || chip.moduleId === "__slot__") {
                mouse.accepted = false;
                return;
            }
            root.forceActiveFocus();
            root.pressId = chip.moduleId;
            root.pressPos = Qt.point(mouse.x, mouse.y);
        }
        onPositionChanged: mouse => {
            const p = Qt.point(mouse.x, mouse.y);
            if (!pressed) {
                const chip = root.chipAt(p);
                root.hoverId = chip && chip.moduleId !== "__slot__" ? chip.moduleId : "";
                return;
            }
            if (!root.dragging && root.pressId && (Math.abs(p.x - root.pressPos.x) > 5 || Math.abs(p.y - root.pressPos.y) > 5)) {
                root.dragging = true;
                root.selectedId = root.pressId;
                root.lastDropPos = Qt.point(-100, -100);
            }
            if (root.dragging) {
                root.dragPos = p;
                root.updateDrop(p);
            }
        }
        onReleased: mouse => {
            if (root.dragging) {
                root.endDrag(true);
                return;
            }
            const chip = root.chipAt(Qt.point(mouse.x, mouse.y));
            if (chip && chip.moduleId === root.pressId) {
                if (chip.group === "available")
                    root.moveTo(chip.moduleId, root.addGroup, -1);
                else if (chip.overRemove(input.mapToItem(chip, mouse.x, mouse.y)))
                    root.moveTo(chip.moduleId, "available", -1);
                else
                    root.selectedId = root.selectedId === chip.moduleId ? "" : chip.moduleId;
            }
            root.pressId = "";
        }
        onCanceled: root.endDrag(false)
        onExited: root.hoverId = ""
    }

    // Floating chip under the pointer while dragging.
    Chip {
        id: ghost
        visible: root.dragging
        moduleId: root.pressId || "launcher"
        group: "ghost"
        x: root.dragPos.x - width / 2
        y: root.dragPos.y - height / 2
        z: 20
        scale: 1.06
        opacity: 0.95
    }

    component Zone: Item {
        id: zone
        property string group
        property string title
        property string icon
        property string hint: ""
        readonly property var ids: root.display(group)
        readonly property bool target: root.dragging && root.dropGroup === group

        width: root.wide && group !== "available" ? (zones.width - zones.spacing * (root.columns - 1)) / root.columns : parent.width
        readonly property real naturalHeight: Math.max(group === "available" || !root.wide ? 70 : 110, flow.implicitHeight + 50)
        height: root.wide && group !== "available" ? root.rowHeight : naturalHeight

        function chipItems() {
            const out = [];
            for (let i = 0; i < chipRepeater.count; i++) {
                const it = chipRepeater.itemAt(i);
                if (it)
                    out.push(it);
            }
            return out;
        }

        Rectangle {
            anchors.fill: parent
            radius: Math.min(Styling.radius(2), 18)
            color: zone.target ? Ui.alpha(Colors.primary, 0.1) : Ui.alpha(Colors.overBackground, zone.group === "available" ? 0.03 : 0.05)
            border.width: zone.target ? 2 : 1
            border.color: zone.target ? Colors.primary : Ui.alpha(Colors.outlineVariant, 0.7)
            Behavior on color {
                enabled: Config.animDuration > 0
                ColorAnimation {
                    duration: 120
                }
            }
        }

        Row {
            id: zoneHeader
            x: 12
            y: 10
            spacing: 6
            Text {
                anchors.verticalCenter: parent.verticalCenter
                text: Icons[zone.icon] ?? ""
                font.family: Icons.font
                font.pixelSize: 12
                color: Colors.overSurfaceVariant
            }
            Text {
                anchors.verticalCenter: parent.verticalCenter
                text: zone.title
                font.family: Config.theme.font
                font.pixelSize: Styling.fontSize(-2)
                font.weight: Font.Bold
                color: Colors.overSurfaceVariant
            }
            Text {
                anchors.verticalCenter: parent.verticalCenter
                visible: zone.hint !== ""
                text: "· " + zone.hint
                font.family: Config.theme.font
                font.pixelSize: Styling.fontSize(-3)
                color: Ui.alpha(Colors.overSurfaceVariant, 0.7)
            }
        }

        Flow {
            id: flow
            x: 10
            y: 34
            width: parent.width - 20
            spacing: 6
            move: Transition {
                enabled: Config.animDuration > 0
                NumberAnimation {
                    properties: "x,y"
                    duration: 140
                    easing.type: Easing.OutCubic
                }
            }

            Repeater {
                id: chipRepeater
                model: zone.ids
                delegate: Chip {
                    required property string modelData
                    moduleId: modelData
                    group: zone.group
                }
            }
        }

        Text {
            anchors.centerIn: flow
            anchors.verticalCenterOffset: 6
            visible: zone.ids.length === 0
            text: zone.group === "available" ? I18n.t("prefs.bar.group.all_used") : I18n.t("prefs.bar.group.empty")
            font.family: Config.theme.font
            font.pixelSize: Styling.fontSize(-2)
            color: Ui.alpha(Colors.overSurfaceVariant, 0.6)
        }
    }

    component Chip: Item {
        id: chip
        property string moduleId
        property string group
        readonly property bool slot: moduleId === "__slot__"
        readonly property var info: BarModules.info(slot ? root.pressId : moduleId)
        readonly property bool selected: !slot && root.selectedId === moduleId && group !== "ghost"
        readonly property bool hovered: !slot && root.hoverId === moduleId && !root.dragging
        readonly property bool lifted: root.dragging && root.pressId === moduleId && group !== "ghost"

        width: row.implicitWidth + 22
        height: 32
        opacity: lifted ? 0.3 : 1

        function overRemove(p) {
            return removeIcon.visible && p.x >= removeIcon.x - 4;
        }

        Rectangle {
            anchors.fill: parent
            radius: height / 2
            color: chip.slot ? "transparent" : (chip.selected ? Ui.alpha(Colors.primary, 0.22) : (chip.group === "available" ? Ui.alpha(Colors.overBackground, 0.06) : Colors.surfaceContainerHigh))
            border.width: chip.slot || chip.selected ? 2 : 1
            border.color: chip.slot || chip.selected ? Colors.primary : Ui.alpha(Colors.outlineVariant, chip.hovered ? 1 : 0.6)
            opacity: chip.slot ? 0.8 : 1
        }

        Row {
            id: row
            anchors.verticalCenter: parent.verticalCenter
            x: 11
            spacing: 7
            opacity: chip.slot ? 0.45 : 1

            Text {
                anchors.verticalCenter: parent.verticalCenter
                text: Icons[chip.info.icon] ?? ""
                font.family: Icons.font
                font.pixelSize: 14
                color: chip.group === "available" ? Colors.overSurfaceVariant : Colors.primary
            }
            Text {
                anchors.verticalCenter: parent.verticalCenter
                text: I18n.t(chip.info.label)
                font.family: Config.theme.font
                font.pixelSize: Styling.fontSize(-1)
                font.weight: Font.Medium
                color: chip.group === "available" ? Colors.overSurfaceVariant : Colors.overBackground
            }
            Text {
                id: removeIcon
                anchors.verticalCenter: parent.verticalCenter
                visible: !chip.slot && chip.group !== "ghost"
                text: chip.group === "available" ? Icons.plus : Icons.cancel
                font.family: Icons.font
                font.pixelSize: 11
                color: chip.group === "available" ? Colors.primary : Colors.overSurfaceVariant
                opacity: chip.group === "available" || chip.hovered || chip.selected ? 0.9 : 0.35
            }
        }
    }
}
