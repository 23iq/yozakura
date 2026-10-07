pragma ComponentBehavior: Bound

import QtQuick
import qs.config
import qs.modules.theme
import qs.modules.services.activities
import "ActivityLayout.js" as Layout

// Places live activity islands in the free spans left and right of the notch
// (see ActivityLayout.js for sides and overflow). Geometry comes from
// ActivityHost. Islands keep their delegate while they retract, so removed
// activities animate back into the edge instead of vanishing.
Item {
    id: gaps

    property string screenName: ""
    property string mode: "tab"
    property string edge: "top"
    property bool revealed: true
    // Outer x bounds of the notch (fillets included) and of the free span
    property real notchStart: width / 2
    property real notchEnd: width / 2
    property real leftLimit: 0
    property real rightLimit: width
    // Distance from the screen edge to the islands' attached side
    property real edgeOffset: 0
    property real thickness: 32
    property real fillet: 0
    property real cornerRadius: 0
    property real gap: 6
    property real spacing: 6
    property real indicatorSize: 16
    property real fontSize: Styling.fontSize(-1)
    property int maxVisible: ActivityService.maxVisible

    readonly property real hPadding: Math.round(thickness * 0.34)
    readonly property real islandY: edge === "bottom" ? height - edgeOffset - thickness : edgeOffset

    // ── Model: current activities + those still retracting ──
    property var byId: ({})
    property var leaving: ({})
    property var widths: ({})
    ListModel {
        id: present
    }

    function sync() {
        const list = ActivityService.activities;
        const map = Object.assign({}, byId);
        const ids = [];
        for (const a of list) {
            map[a.id] = a;
            ids.push(a.id);
        }
        const nextLeaving = {};
        const known = {};
        for (let i = 0; i < present.count; i++) {
            const id = present.get(i).aid;
            known[id] = true;
            if (ids.indexOf(id) === -1)
                nextLeaving[id] = true;
        }
        byId = map;
        leaving = nextLeaving;
        for (const id of ids)
            if (!known[id])
                present.append({
                    aid: id
                });
    }

    function finishLeave(id) {
        if (!leaving[id])
            return;
        for (let i = 0; i < present.count; i++) {
            if (present.get(i).aid === id) {
                present.remove(i);
                break;
            }
        }
        const map = Object.assign({}, byId);
        delete map[id];
        byId = map;
        const w = Object.assign({}, widths);
        delete w[id];
        widths = w;
        const lv = Object.assign({}, leaving);
        delete lv[id];
        leaving = lv;
    }

    function setWidth(id, w) {
        if (widths[id] === w)
            return;
        const next = Object.assign({}, widths);
        next[id] = w;
        widths = next;
    }

    Connections {
        target: ActivityService
        function onActivitiesChanged() {
            gaps.sync();
        }
    }
    Component.onCompleted: sync()

    // ── Layout ──
    readonly property real overflowFootprint: overflowIsland.footprint
    readonly property var result: {
        const items = [];
        for (const a of ActivityService.activities)
            items.push({
                id: a.id,
                category: a.category,
                width: widths[a.id] !== undefined ? widths[a.id] : thickness * 3
            });
        return Layout.distribute(items, {
            leftSpace: notchStart - gap - leftLimit,
            rightSpace: rightLimit - notchEnd - gap,
            spacing: spacing,
            maxVisible: maxVisible,
            overflowWidth: overflowFootprint
        });
    }
    readonly property var placed: {
        const out = {};
        for (const id of result.left)
            out[id] = true;
        for (const id of result.right)
            out[id] = true;
        return out;
    }
    readonly property var xs: Layout.positions(result, widths, notchStart, notchEnd, gap, spacing, overflowFootprint)

    // Bounding boxes of each side, for the input mask
    function sideBounds(side) {
        let min = Infinity, max = -Infinity;
        const ids = result[side].slice();
        if (result.overflow && result.overflow.side === side)
            ids.push("__overflow");
        for (const id of ids) {
            const w = id === "__overflow" ? overflowFootprint : (widths[id] || 0);
            min = Math.min(min, xs[id]);
            max = Math.max(max, xs[id] + w);
        }
        return isFinite(min) && revealed ? Qt.rect(min, islandY, max - min, thickness) : Qt.rect(0, 0, 0, 0);
    }
    readonly property rect leftBounds: sideBounds("left")
    readonly property rect rightBounds: sideBounds("right")

    Item {
        id: leftHitbox
        x: gaps.leftBounds.x
        y: gaps.leftBounds.y
        width: gaps.leftBounds.width
        height: gaps.leftBounds.height
    }
    Item {
        id: rightHitbox
        x: gaps.rightBounds.x
        y: gaps.rightBounds.y
        width: gaps.rightBounds.width
        height: gaps.rightBounds.height
    }
    readonly property Item leftHitboxItem: leftHitbox
    readonly property Item rightHitboxItem: rightHitbox

    readonly property bool idle: present.count === 0 && !overflowIsland.visible

    // ── Islands ──
    Repeater {
        model: present
        delegate: ActivityIsland {
            id: isl
            required property string aid
            readonly property var activity: gaps.byId[isl.aid] || null
            readonly property bool isLeaving: gaps.leaving[isl.aid] === true
            readonly property bool isPlaced: gaps.placed[isl.aid] === true

            mode: gaps.mode
            edge: gaps.edge
            thickness: gaps.thickness
            fillet: gaps.fillet
            cornerRadius: gaps.cornerRadius
            hPadding: gaps.hPadding
            shown: gaps.revealed && !isl.isLeaving && isl.isPlaced
            tooltip: isl.activity ? isl.activity.detail : ""
            contentItem: body
            y: gaps.islandY

            // Keep the last slot while hidden/retracting
            property real slotX: 0
            readonly property var targetX: gaps.xs[isl.aid]
            function follow() {
                if (isl.isPlaced && isl.targetX !== undefined)
                    isl.slotX = isl.targetX;
            }
            onTargetXChanged: isl.follow()
            onIsPlacedChanged: isl.follow()
            x: isl.slotX + (isl.tab ? isl.fillet : 0)
            Behavior on slotX {
                enabled: Config.animDuration > 0 && isl.presence > 0.05
                NumberAnimation {
                    duration: Motion.morph.duration
                    easing.type: Motion.morph.easing
                }
            }

            onFootprintChanged: gaps.setWidth(isl.aid, isl.footprint)
            Component.onCompleted: {
                gaps.setWidth(isl.aid, isl.footprint);
                isl.follow();
            }
            onRetracted: if (isl.isLeaving)
                Qt.callLater(gaps.finishLeave, isl.aid)
            onIsLeavingChanged: if (isl.isLeaving && isl.presence <= 0)
                Qt.callLater(gaps.finishLeave, isl.aid)
            onClicked: button => ActivityService.activate(isl.activity, button, gaps.screenName)

            ActivityContent {
                id: body
                anchors.centerIn: parent
                activity: isl.activity
                indicatorSize: gaps.indicatorSize
                fontSize: gaps.fontSize
            }
        }
    }

    // "+N": the activities that did not fit
    ActivityIsland {
        id: overflowIsland
        readonly property var ids: gaps.result.overflow ? gaps.result.overflow.ids : []
        property int count: 0
        onIdsChanged: if (overflowIsland.ids.length > 0)
            overflowIsland.count = overflowIsland.ids.length

        mode: gaps.mode
        edge: gaps.edge
        thickness: gaps.thickness
        fillet: gaps.fillet
        cornerRadius: gaps.cornerRadius
        hPadding: gaps.hPadding
        shown: gaps.revealed && overflowIsland.ids.length > 0
        contentItem: overflowBody
        y: gaps.islandY
        tooltip: overflowIsland.ids.map(id => {
            const a = gaps.byId[id];
            return a ? (a.label + (a.detail ? " · " + a.detail : "")) : "";
        }).join("\n")

        property real slotX: 0
        readonly property var targetX: gaps.xs.__overflow
        onTargetXChanged: if (overflowIsland.targetX !== undefined)
            overflowIsland.slotX = overflowIsland.targetX
        x: overflowIsland.slotX + (overflowIsland.tab ? overflowIsland.fillet : 0)
        Behavior on slotX {
            enabled: Config.animDuration > 0 && overflowIsland.presence > 0.05
            NumberAnimation {
                duration: Motion.morph.duration
                easing.type: Motion.morph.easing
            }
        }

        ActivityContent {
            id: overflowBody
            anchors.centerIn: parent
            overflowCount: overflowIsland.count
            indicatorSize: gaps.indicatorSize
            fontSize: gaps.fontSize
        }
    }
}
