pragma ComponentBehavior: Bound

import QtQuick
import qs.config
import qs.modules.theme
import qs.modules.bar
import qs.modules.notch
import qs.modules.services.activities
import "ActivityLayout.js" as Layout

// Live activities for one screen. Reads where the notch and the bar are and
// hands ActivityGaps the free spans next to the notch. Nothing is loaded
// while there are no activities (the last one is kept until it retracted).
Item {
    id: host

    required property string screenName
    // BarContent and NotchContent of the same UnifiedShellPanel
    required property BarContent bar
    required property NotchContent notch
    property bool barEnabled: true

    readonly property Item notchItem: host.notch ? host.notch.notchContainerRef : null
    readonly property var place: Layout.placement({
        barEnabled: barEnabled,
        barStyle: bar && bar.styleMeta.activity === "tab" ? "islands" : "classic",
        barPosition: bar ? bar.barPosition : "top",
        notchPosition: Config.notchPosition || "top",
        notchTheme: Config.notchTheme || "default"
    })

    readonly property bool frameOn: Config.bar && Config.bar.frameEnabled && !(notch && notch.activeWindowFullscreen)
    readonly property real frameOffset: frameOn ? (Config.bar.frameThickness !== undefined ? Config.bar.frameThickness : 6) : 0
    readonly property real roundFillet: Config.roundness > 0 ? Config.roundness + 4 : 0

    // ── Size per mode ──
    readonly property real thickness: {
        switch (place.mode) {
        case "pill":
            return BarMetrics.moduleSize;
        case "floating":
            return BarMetrics.notchIslandHeight;
        default:
            return BarMetrics.notchRestHeight - 2 * BarMetrics.islandPadding - 2;
        }
    }
    readonly property real cornerRadius: {
        if (place.mode === "pill")
            return Math.min(Styling.radius(0), thickness / 2);
        return Math.min(roundFillet, thickness / 2);
    }
    readonly property real fillet: place.mode === "tab" ? Math.min(roundFillet, thickness * 0.75) : 0

    // Distance from the attached screen edge to the islands
    readonly property real edgeOffset: {
        if (place.mode === "pill" && bar) {
            const barBody = bar.totalBarHeight - bar.barTargetHeight;
            return barBody + (bar.barTargetHeight - thickness) / 2;
        }
        if (place.mode === "floating")
            return frameOffset + 4;
        return frameOffset;
    }

    // ── Free span along the edge ──
    readonly property real notchWidth: notchItem ? notchItem.width : 0
    readonly property real notchStart: (width - notchWidth) / 2
    readonly property real notchEnd: (width + notchWidth) / 2
    readonly property real margin: Math.max(8, roundFillet)
    readonly property real leftLimit: {
        if (place.sameEdge && bar)
            return bar.startExtent + (place.mode === "tab" ? bar.islandFillet : 0) + spacing;
        let lim = frameOffset + margin;
        if (barEnabled && bar && bar.barPosition === "left")
            lim += bar.totalBarWidth;
        return lim;
    }
    readonly property real rightLimit: {
        if (place.sameEdge && bar)
            return width - bar.endExtent - (place.mode === "tab" ? bar.islandFillet : 0) - spacing;
        let lim = width - frameOffset - margin;
        if (barEnabled && bar && bar.barPosition === "right")
            lim -= bar.totalBarWidth;
        return lim;
    }
    readonly property real spacing: Math.max(4, Math.round(thickness / 6))

    // Retract with the notch, and while it is opened (launcher, dashboard...)
    readonly property bool revealed: notch !== null && notch.reveal && !notch.screenNotchOpen

    // ── Lifetime: only alive while something is (or was just) showing ──
    property bool lingering: false
    // Only for notch.liveActivities.presentation "islands"; "notch" renders inside
    // the notch (modules/widgets/defaultview/activities)
    readonly property bool wanted: ActivityService.presentation === "islands" && ActivityService.count > 0
    onWantedChanged: {
        if (wanted) {
            lingerTimer.stop();
            lingering = true;
        } else {
            lingerTimer.restart();
        }
    }
    Timer {
        id: lingerTimer
        interval: Config.animDuration + 100
        onTriggered: host.lingering = false
    }

    readonly property ActivityGaps gapsItem: loader.item as ActivityGaps
    readonly property Item leftHitbox: host.gapsItem ? host.gapsItem.leftHitboxItem : null
    readonly property Item rightHitbox: host.gapsItem ? host.gapsItem.rightHitboxItem : null

    Loader {
        id: loader
        anchors.fill: parent
        active: host.wanted || host.lingering
        sourceComponent: ActivityGaps {
            screenName: host.screenName
            mode: host.place.mode
            edge: host.place.edge
            revealed: host.revealed
            notchStart: host.notchStart
            notchEnd: host.notchEnd
            leftLimit: host.leftLimit
            rightLimit: host.rightLimit
            edgeOffset: host.edgeOffset
            thickness: host.thickness
            fillet: host.fillet
            cornerRadius: host.cornerRadius
            gap: host.place.mode === "tab" ? host.spacing : host.spacing * 2
            spacing: host.spacing
            indicatorSize: BarMetrics.iconSize(16)
            fontSize: Styling.fontSize(BarMetrics.compact ? -2 : -1)
        }
    }
}
