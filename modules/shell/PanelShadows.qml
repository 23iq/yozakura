pragma ComponentBehavior: Bound

import QtQuick
import qs.config
import qs.modules.components
import qs.modules.globals

// Theme shadows of the unified panel's surfaces, one ShadowCaster per
// surface instead of one MultiEffect over a full-screen layer. Sits below
// every surface (shadows never darken a neighbour: the notch's shadow ends
// under the frame, so fillets merge seamlessly), and a change inside one
// surface (cava, clock, a hover) only re-renders that surface's region.
//
// Each caster captures a rectangle around its surface's visuals: the
// surface item itself fills the panel, so the rectangle comes from the
// surface's own geometry (hitboxes, notch region, bar strip), grown by the
// widest fillet and snapped to a 16 px grid so animated sizes do not
// reallocate textures every frame.
Item {
    id: root

    // Surfaces (untyped: their types live in modules that import this one's
    // siblings; ShadowCaster only needs them as Items)
    property Item frame: null
    // Every bar panel of the screen (PanelHost.bars); one caster each
    property var bars: []
    property var notch: null
    property var dock: null
    property var activities: null
    property var sidebar: null

    property bool barEnabled: true
    property bool dockEnabled: true

    readonly property bool frameEnabled: Config.bar?.frameEnabled ?? false
    readonly property int frameThickness: Config.bar?.frameThickness ?? 6
    // Room for fillets, outlines and the island gap around each surface
    readonly property real pad: (Config.roundness > 0 ? Config.roundness + 4 : 0) + 8

    function region(x, y, w, h) {
        if (!(w > 0 && h > 0))
            return Qt.rect(0, 0, 0, 0);
        const g = 16;
        const x0 = Math.max(0, Math.floor((x - root.pad) / g) * g);
        const y0 = Math.max(0, Math.floor((y - root.pad) / g) * g);
        const x1 = Math.min(root.width, Math.ceil((x + w + root.pad) / g) * g);
        const y1 = Math.min(root.height, Math.ceil((y + h + root.pad) / g) * g);
        return x1 > x0 && y1 > y0 ? Qt.rect(x0, y0, x1 - x0, y1 - y0) : Qt.rect(0, 0, 0, 0);
    }

    function itemRegion(item) {
        return item && item.visible ? root.region(item.x, item.y, item.width, item.height) : Qt.rect(0, 0, 0, 0);
    }

    // A bar panel: its span along the edge (the whole edge, or a floating
    // panel's own span) and its full depth, independent of the reveal
    // animation so a sliding panel is never clipped
    function barRect(b) {
        if (!b)
            return Qt.rect(0, 0, 0, 0);
        const vertical = b.barPosition === "left" || b.barPosition === "right";
        const t = (vertical ? b.barTargetWidth : b.barTargetHeight) + b.baseOuterMargin * 2 + root.frameThickness * 2;
        const start = b.aligned ? b.spanStart : 0;
        const along = b.aligned ? b.spanLength : (vertical ? root.height : root.width);
        switch (b.barPosition) {
        case "bottom":
            return root.region(start, root.height - t, along, t);
        case "left":
            return root.region(0, start, t, along);
        case "right":
            return root.region(root.width - t, start, t, along);
        default:
            return root.region(start, 0, along, t);
        }
    }

    // Dock: the band along its edge, also independent of reveal
    readonly property rect dockRect: {
        const d = root.dock;
        if (!d)
            return Qt.rect(0, 0, 0, 0);
        const t = d.dockSize + d.totalMargin + root.frameThickness * 2;
        switch (d.position) {
        case "left":
            return root.region(0, 0, t, root.height);
        case "right":
            return root.region(root.width - t, 0, t, root.height);
        default:
            return root.region(0, root.height - t, root.width, t);
        }
    }

    readonly property rect activityRect: {
        const a = root.activities;
        const l = a ? a.leftHitbox : null;
        const r = a ? a.rightHitbox : null;
        const boxes = [l, r].filter(i => i && i.width > 0 && i.height > 0);
        if (boxes.length === 0)
            return Qt.rect(0, 0, 0, 0);
        const x0 = Math.min(...boxes.map(i => i.x));
        const y0 = Math.min(...boxes.map(i => i.y));
        const x1 = Math.max(...boxes.map(i => i.x + i.width));
        const y1 = Math.max(...boxes.map(i => i.y + i.height));
        return root.region(x0, y0, x1 - x0, y1 - y0);
    }

    ShadowCaster {
        source: root.frame
        active: root.frameEnabled
        sourceRect: Qt.rect(0, 0, root.width, root.height)
    }
    // A contained panel is part of the frame's silhouette: the frame casts it
    Repeater {
        model: root.bars
        delegate: ShadowCaster {
            id: caster
            required property var modelData
            source: caster.modelData
            active: root.barEnabled && !caster.modelData.contained
            sourceRect: root.barRect(caster.modelData)
        }
    }
    ShadowCaster {
        source: root.dock
        active: root.dockEnabled
        sourceRect: root.dockRect
    }
    ShadowCaster {
        source: root.activities
        sourceRect: root.activityRect
    }
    ShadowCaster {
        source: root.notch
        sourceRect: root.itemRegion(root.notch ? root.notch.visualRegion : null)
    }
    // A sidebar pinned inside the frame is part of the frame's silhouette
    ShadowCaster {
        source: root.sidebar
        active: !(root.frameEnabled && GlobalStates.assistantPinned)
        sourceRect: {
            const s = root.sidebar;
            const box = s ? s.hitbox : null;
            return box && box.visible ? root.region(s.x + box.x, s.y + box.y, box.width, box.height) : Qt.rect(0, 0, 0, 0);
        }
    }
}
