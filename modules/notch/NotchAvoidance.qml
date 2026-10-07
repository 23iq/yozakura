import QtQuick
import qs.config
import qs.modules.theme
import qs.modules.shell
import "NotchAvoid.js" as NotchAvoid

// Where a grown notch goes so it never covers the modules of a bar on its
// own edge (NotchAvoid.js): stays, slides between the bar groups, or drops
// past the bar. The decision uses the notch's target size (not its
// animated one), so it is taken once per change; the move itself is one
// Motion.morph animation running alongside the size morph. Non-visual.
Item {
    id: root
    visible: false

    // ShellScreen (or anything with name/width/height)
    property var screen: null
    // BarContent of the primary bar (Visibilities.barPanels), or null
    property var bar: null
    property string position: "top"
    // The notch shows more than its resting self
    property bool grown: false
    // Target size along the edge of the grown notch, and of the resting one
    property real targetAlong: 0
    property real restAlong: 0
    property real restAcross: 0
    // Notch's own gap to the edge, and the space to keep from the bar
    property real edgeGap: 0
    property real gap: 4

    readonly property bool vertical: position === "left" || position === "right"
    readonly property bool barShown: !!bar && bar.barPosition === position && (bar.reveal === undefined || bar.reveal) && bar.visible !== false
    readonly property var occupied: barShown ? NotchAvoid.occupied({
        lo: bar.spanStart,
        hi: bar.spanStart + bar.spanLength,
        inset: bar.aligned ? 0 : bar.frameOffset + bar.sideMargin,
        startReach: bar.styleItem ? bar.styleItem.startReach : 0,
        endReach: bar.styleItem ? bar.styleItem.endReach : 0,
        center: !!bar.centerIds && bar.centerIds.length > 0
    }) : []
    readonly property var targetRect: EdgeService.notchRect(screen, {
        along: targetAlong,
        across: 1
    })
    readonly property var result: NotchAvoid.avoid({
        pos: position,
        transient: grown,
        occupied: occupied,
        total: vertical ? (screen ? screen.height : 0) : (screen ? screen.width : 0),
        start: vertical ? targetRect.y : targetRect.x,
        length: targetAlong,
        barDepth: barShown ? bar.frameOffset + bar.edgeDepth : 0,
        edgeGap: edgeGap,
        gap: gap
    })
    readonly property bool dropped: result.mode === "drop"
    readonly property var target: NotchAvoid.offset(position, result)
    // Resting footprint on the edge and the hover bridge down to the notch
    readonly property var restRect: EdgeService.notchRect(screen, {
        along: restAlong,
        across: restAcross
    })
    readonly property var stem: NotchAvoid.stem(position, restRect, result.across + edgeGap, {
        w: screen ? screen.width : 0,
        h: screen ? screen.height : 0
    })

    // Animated translation of the notch region
    // (offsetX/Y: x/y are the Item's own)
    property real offsetX: target.x
    property real offsetY: target.y
    readonly property bool settling: xAnim.running || yAnim.running
    // Off the edge (slid or dropped)
    readonly property bool moved: result.mode !== "edge"
    // Sliding back to the edge: the silhouette may pass under a still
    // pointer, which must not count as arriving on it (no re-open loop)
    readonly property bool returning: returnTimer.running
    onMovedChanged: {
        if (!root.moved && Config.animDuration > 0)
            returnTimer.restart();
    }
    Timer {
        id: returnTimer
        interval: Motion.morph.duration
    }

    Behavior on offsetX {
        enabled: Config.animDuration > 0
        NumberAnimation {
            id: xAnim
            duration: Motion.morph.duration
            easing.type: Motion.morph.easing
        }
    }
    Behavior on offsetY {
        enabled: Config.animDuration > 0
        NumberAnimation {
            id: yAnim
            duration: Motion.morph.duration
            easing.type: Motion.morph.easing
        }
    }
}
