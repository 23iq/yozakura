import QtQuick
import qs.config
import qs.modules.services
import qs.modules.bar.workspaces
import qs.modules.theme
import "WallpaperCoverage.js" as Coverage

// Whether no pixel of this screen's wallpaper is visible: windows of the
// active workspace cover the monitor without gaps (gaps 0, monocle, a
// maximized tiled window...). See WallpaperCoverage.js.
QtObject {
    id: root

    property string screenName: ""
    // yozd monitor (YozdService.monitorFor)
    property var monitor: null
    property bool enabled: true

    readonly property var reservation: Visibilities.reservations[root.screenName] ?? null

    // The shell's reserved strips only hide the wallpaper when they are
    // painted edge to edge with opaque surfaces: a frame that contains a
    // classic bar, opaque bar and frame backgrounds, and no floating dock or
    // pinned sidebar (both leave margins). Otherwise windows must cover the
    // whole monitor.
    readonly property bool shellOpaque: {
        const r = root.reservation;
        if (!r || !(Config.bar.frameEnabled ?? false) || !(Config.bar.containBar ?? false))
            return false;
        if ((Config.bar.layout?.style ?? "classic") === "islands")
            return false;
        if ((r.dockEnabled && r.dockPinned) || (r.sidebarEnabled && r.sidebarPinned))
            return false;
        const frameOpacity = Styling.getStyledRectConfig("frame").opacity ?? 1;
        return (Config.theme.srBarBg.opacity ?? 1) >= 0.99 && frameOpacity >= 0.99;
    }
    readonly property var insets: root.shellOpaque ? {
        top: root.reservation.topZone,
        bottom: root.reservation.bottomZone,
        left: root.reservation.leftZone,
        right: root.reservation.rightZone
    } : null

    readonly property bool covered: root.enabled && Coverage.covered(root.monitor, CompositorData.windowList, root.insets, Config.compositorBorderSize ?? 0)
}
