import QtQuick
import qs.config
import qs.modules.components.shape
import "FrameShadow.js" as FrameShadow

// The screen frame's analytic shadow: everything outside its rounded hole
// (a contained panel is part of the frame's silhouette, it narrows the
// hole). A side of thickness 0 (a fullscreen window hides it) draws no
// frame, so it casts nothing: the hole runs past that screen edge instead
// of ending on it. Fills its parent; drawn under the frame, by the unified
// panel (PanelShadows) or by the frame's own window (FrameWindow).
ShapeShadow {
    id: root

    // ScreenFrameContent
    property var frame: null
    property bool shown: true

    readonly property bool frameEnabled: Config.bar?.frameEnabled ?? false
    readonly property real span: root.parent ? root.parent.width + root.parent.height : 0

    // The frame's hole grown past every screen edge whose side has no
    // thickness (far enough that no blur or light offset reaches back)
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
        }, root.span);
        return Qt.rect(b.x, b.y, b.w, b.h);
    }

    active: root.shown && root.frameEnabled && !!root.frame && root.frame.hasHole
    inverted: true
    box: root.frame ? root.openHole(root.frame.holeRect, root.frame) : Qt.rect(0, 0, 0, 0)
    radii: {
        const r = root.frame ? Math.min(root.frame.innerRadius, root.frame.holeRect.width / 2, root.frame.holeRect.height / 2) : 0;
        return Qt.vector4d(r, r, r, r);
    }
    strength: root.frame ? root.frame.fillAlpha : 1
}
