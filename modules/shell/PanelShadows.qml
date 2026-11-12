pragma ComponentBehavior: Bound

import QtQuick
import qs.config
import qs.modules.components
import qs.modules.components.shape
import qs.modules.globals
import "FrameShadow.js" as FrameShadow

// Theme shadows of the unified panel's surfaces. Sits below every surface
// (shadows never darken a neighbour: the notch's shadow ends under the
// frame, so fillets merge seamlessly).
//
// Surfaces with a known rounded shape that animate (the notch's morph and
// reveal, the dock's reveal, the frame's growth) cast an analytic shadow
// (ShapeShadow): one quad driven by their geometry, no capture, no blur
// pass, no texture, so a morph costs nothing extra per frame. Bar panels
// and live activities have free-form silhouettes (groups, pills, chips)
// and keep a captured shadow (ShadowCaster) of a rectangle around them,
// grown by the widest fillet and snapped to a 16 px grid so animated sizes
// do not reallocate textures every frame.
Item {
    id: root

    // Surfaces (untyped: their types live in modules that import this one's
    // siblings)
    property var frame: null
    // Every bar panel of the screen (PanelHost.bars); one caster each
    property var bars: []
    property var notch: null
    property var dock: null
    property var activities: null

    property bool barEnabled: true
    property bool dockEnabled: true
    // The frame is drawn by its own window below this one
    // (performance.splitFrame, FrameWindow): no frame shadow here, and the
    // other shadows stop at the frame's hole instead of passing under it
    property bool frameElsewhere: false

    readonly property bool frameEnabled: Config.bar?.frameEnabled ?? false
    readonly property int frameThickness: Config.bar?.frameThickness ?? 6
    readonly property bool clipToHole: root.frameElsewhere && root.frameEnabled && !!root.frame && root.frame.hasHole
    readonly property rect holeClip: root.clipToHole ? root.openHole(root.frame.holeRect, root.frame) : Qt.rect(0, 0, 0, 0)
    readonly property real holeClipRadius: root.frame ? root.frame.innerRadius : 0
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

    // The frame's hole grown past every screen edge whose side has no
    // thickness (FrameShadow.openHole)
    function openHole(hole, f) {
        const b = FrameShadow.openHole({
            "x": hole.x,
            "y": hole.y,
            "w": hole.width,
            "h": hole.height
        }, {
            "left": f.leftThickness,
            "top": f.topThickness,
            "right": f.rightThickness,
            "bottom": f.bottomThickness
        }, root.width + root.height);
        return Qt.rect(b.x, b.y, b.w, b.h);
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

    // Frame: everything outside its rounded hole (FrameShapeShadow), here
    // while the frame is drawn in this panel
    FrameShapeShadow {
        frame: root.frame
        shown: !root.frameElsewhere
    }
    ShadowHoleClip {
        area: root
        clipped: root.clipToHole
        hole: root.holeClip
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
    }
    // Dock: its body and (default theme) two concave corners, sliding with
    // the reveal and fading in step with it (same RenderFade)
    ShapeShadow {
        readonly property var surface: root.dock ? root.dock.surface : null
        active: root.dockEnabled && !!surface && root.dock.visible
        box: root.dock ? root.dock.surfaceRect : Qt.rect(0, 0, 0, 0)
        radii: surface ? surface.shadowRadii : Qt.vector4d(0, 0, 0, 0)
        fillet: surface && surface.isDefault ? surface.cornerSize : 0
        edge: surface ? surface.position : "bottom"
        holeClipped: root.clipToHole
        holeClip: root.holeClip
        holeClipRadius: root.holeClipRadius
        strength: surface ? surface.fillAlpha : 1
        opacity: root.dock && root.dock.reveal ? 1 : 0
        RenderFade on opacity {
            duration: root.dock ? root.dock.fadeDuration : 0
            easingType: root.dock ? root.dock.fadeEasing : Easing.Linear
        }
    }
    ShadowHoleClip {
        area: root
        clipped: root.clipToHole
        hole: root.holeClip
        ShadowCaster {
            source: root.activities
            sourceRect: root.activityRect
        }
    }
    // Notch: its silhouette as it morphs (radii, concave corners of the
    // attached style), sliding with the reveal and fading in step with it
    ShapeShadow {
        readonly property var silhouette: root.notch ? root.notch.silhouette : null
        active: !!silhouette && root.notch.visible
        box: root.notch ? root.notch.silhouetteRect : Qt.rect(0, 0, 0, 0)
        radii: silhouette ? Qt.vector4d(silhouette.tl, silhouette.tr, silhouette.br, silhouette.bl) : Qt.vector4d(0, 0, 0, 0)
        fillet: silhouette && silhouette.attached ? silhouette.cornerSize : 0
        edge: silhouette ? silhouette.position : "top"
        holeClipped: root.clipToHole
        holeClip: root.holeClip
        holeClipRadius: root.holeClipRadius
        strength: silhouette ? silhouette.surfaceAlpha : 1
        opacity: root.notch && root.notch.reveal ? 1 : 0
        RenderFade on opacity {
            duration: root.notch ? root.notch.fadeDuration : 0
            easingType: root.notch ? root.notch.fadeEasing : Easing.Linear
        }
    }
    // The notch's notification popup (a rounded box beside the open notch),
    // sliding and fading with the same reveal
    ShapeShadow {
        id: popupShadow
        active: !!root.notch && root.notch.visible
        box: root.notch ? root.notch.notificationPopupRect : Qt.rect(0, 0, 0, 0)
        radii: {
            const r = root.notch ? Math.min(root.notch.notificationPopupRadius, popupShadow.box.width / 2, popupShadow.box.height / 2) : 0;
            return Qt.vector4d(r, r, r, r);
        }
        strength: root.notch ? root.notch.notificationPopupAlpha : 1
        holeClipped: root.clipToHole
        holeClip: root.holeClip
        holeClipRadius: root.holeClipRadius
        opacity: root.notch && root.notch.reveal ? 1 : 0
        RenderFade on opacity {
            duration: root.notch ? root.notch.fadeDuration : 0
            easingType: root.notch ? root.notch.fadeEasing : Easing.Linear
        }
    }
}
