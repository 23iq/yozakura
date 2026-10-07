pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import qs.config
import qs.modules.theme
import qs.modules.services
import qs.modules.components
import qs.modules.bar as Bar
import qs.modules.bar.panels
import "DockSplit.js" as DockSplit

// "dock": a floating container detached from the edge, sized to its
// content (align: center/start/end), groups packed in one row with a
// divider between non-empty groups. Pairs with the taskbar, downloads and
// workspacePreviews modules (dock.magnification / launchBounce).
// On the notch's edge (both centered) it parts around the grown notch
// (DockSplit.js): the end group and the rest slide apart, the notch grows
// in place between them instead of dropping past the bar.
PanelStyleBase {
    id: dock

    readonly property var b: dock.barRoot
    readonly property int moduleSize: b ? b.moduleSize : BarMetrics.moduleSize
    readonly property int pad: Math.round(moduleSize * 0.14)
    readonly property int spacing: 4
    readonly property var runs: b ? DockSplit.runs(b.startIds, b.centerIds, b.endIds) : ({
            left: [],
            right: []
        })

    // Surface variant and own shadow ("dock-like" uses the bar surface)
    property string surface: "bg"
    property bool ownShadow: true

    // ── Parting around the notch ──
    readonly property var notchItem: b && !vertical && b.notchPosition === b.barPosition ? Visibilities.getNotchForScreen(b.screen.name) : null
    readonly property bool centered: !!b && b.aligned && b.spec.align !== "start" && b.spec.align !== "end" && (!Config.notch || !Config.notch.align || Config.notch.align === "center")
    readonly property real claim: notchItem && notchItem.edgeClaim !== undefined ? notchItem.edgeClaim : 0
    readonly property real leftLength: vertical ? leftRow.implicitHeight : leftRow.implicitWidth
    readonly property real rightLength: dock.runs.right.length > 0 ? (vertical ? rightRow.implicitHeight : rightRow.implicitWidth) : 0
    readonly property real sepBlock: rightLength > 0 ? (vertical ? sep.implicitHeight : sep.implicitWidth) + 2 * spacing : 0
    readonly property bool parted: DockSplit.parts({
        enabled: !!notchItem && centered,
        left: leftLength,
        right: rightLength,
        pad: pad,
        gap: Metrics.spacing,
        claim: claim,
        max: b ? b.edgeLength - 2 * b.frameOffset : 0
    })
    // The free middle; kept from the last parting while closing back
    property real gapLength: 0
    onPartedChanged: if (parted)
        gapLength = claim + 2 * Metrics.spacing
    onClaimChanged: if (parted)
        gapLength = claim + 2 * Metrics.spacing
    property real part: parted ? 1 : 0
    Behavior on part {
        enabled: Config.animDuration > 0
        NumberAnimation {
            duration: Motion.morph.duration
            easing.type: Motion.morph.easing
        }
    }
    readonly property var geo: DockSplit.layout({
        left: leftLength,
        right: rightLength,
        pad: pad,
        sep: sepBlock,
        gap: gapLength,
        part: part
    })
    readonly property bool split: part > 0
    readonly property real mid: (vertical ? height : width) / 2

    implicitThickness: moduleSize + 2 * pad
    // Parted length until the runs are back (clicks land on them meanwhile)
    implicitLength: parted || split ? DockSplit.partedLength({
        left: leftLength,
        right: rightLength,
        pad: pad,
        gap: gapLength
    }) : DockSplit.restLength({
        left: leftLength,
        right: rightLength,
        pad: pad,
        sep: sepBlock
    })
    outerMargin: Math.round(moduleSize * 0.16)
    sideMargin: 0
    startReach: parted ? geo.startReach : 0
    endReach: parted ? geo.endReach : 0

    readonly property real radius: Math.min(Styling.radius(10), dock.implicitThickness / 2)

    // Start-side surface (the whole capsule while resting)
    StyledRect {
        readonly property real from: dock.geo.leftFrom
        readonly property real to: dock.split ? dock.geo.leftTo : dock.geo.rightTo
        variant: dock.surface
        enableShadow: dock.ownShadow
        radius: dock.radius
        topRightRadius: dock.split ? dock.radius * dock.part : dock.radius
        bottomRightRadius: topRightRadius
        x: dock.vertical ? 0 : dock.mid + from
        y: dock.vertical ? dock.mid + from : 0
        width: dock.vertical ? parent.width : to - from
        height: dock.vertical ? to - from : parent.height
    }

    // End-side surface, once parting
    StyledRect {
        visible: dock.split
        variant: dock.surface
        enableShadow: dock.ownShadow
        radius: dock.radius
        topLeftRadius: dock.radius * dock.part
        bottomLeftRadius: topLeftRadius
        x: dock.mid + dock.geo.rightFrom
        y: 0
        width: dock.geo.rightTo - dock.geo.rightFrom
        height: parent.height
    }

    // Divider between the runs, fading out as they part
    Bar.BarSeparator {
        id: sep
        visible: dock.rightLength > 0
        opacity: 1 - dock.part
        vertical: dock.vertical
        moduleSize: dock.moduleSize
        x: dock.vertical ? (parent.width - width) / 2 : dock.mid + dock.geo.seam - width / 2
        y: dock.vertical ? dock.mid + dock.geo.seam - height / 2 : (parent.height - height) / 2
    }

    component Run: GridLayout {
        id: run
        property var ids: []
        flow: dock.vertical ? GridLayout.TopToBottom : GridLayout.LeftToRight
        rowSpacing: dock.spacing
        columnSpacing: dock.spacing
        width: dock.vertical ? dock.moduleSize : implicitWidth
        height: dock.vertical ? implicitHeight : dock.moduleSize

        Bar.BarModuleGroup {
            barRoot: dock.b
            ids: run.ids
            // Non-flat modules (dock-like) draw their group pills
            outerRadius: dock.b ? dock.b.outerRadius : 0
            innerRadius: dock.b ? dock.b.innerRadius : 0
            enableShadow: false
            separatorStyle: "line"
        }
    }

    Run {
        id: leftRow
        ids: dock.runs.left
        x: dock.vertical ? (parent.width - width) / 2 : dock.mid + dock.geo.leftRun
        y: dock.vertical ? dock.mid + dock.geo.leftRun : (parent.height - height) / 2
    }

    Run {
        id: rightRow
        visible: dock.runs.right.length > 0
        ids: dock.runs.right
        x: dock.vertical ? (parent.width - width) / 2 : dock.mid + dock.geo.rightRun
        y: dock.vertical ? dock.mid + dock.geo.rightRun : (parent.height - height) / 2
    }
}
