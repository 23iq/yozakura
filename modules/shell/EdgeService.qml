pragma Singleton
import QtQuick
import Quickshell
import qs.config
import qs.modules.theme
import "EdgeLayout.js" as EdgeLayout

// Builds the EdgeLayout environment for a screen from Config.bar/dock/notch
// and exposes the placement helpers bound to it. All edge-aware UI (popups,
// sheets, OSD, spotlight, toasts) goes through here; no placement math lives
// in QML.
Singleton {
    id: root

    // `screen` is a ShellScreen (or anything with width/height).
    // Optional `visibility` overrides {bar, dock, notch} -> bool (default true,
    // dock follows Config.dock.enabled).
    function envFor(screen, visibility) {
        const vis = visibility || {};
        const bar = Config.bar;
        const dock = Config.dock;
        const notch = Config.notch;
        const frame = bar && bar.frameEnabled ? (bar.frameThickness ?? 0) : 0;
        return {
            "screen": {
                "w": screen ? screen.width : 0,
                "h": screen ? screen.height : 0
            },
            "frame": frame,
            "bar": {
                "pos": bar && bar.position ? bar.position : "top",
                "size": BarMetrics.moduleSize,
                "visible": vis.bar ?? true
            },
            "dock": {
                "pos": dock && dock.position ? dock.position : "bottom",
                "size": dock && dock.height ? dock.height : 0,
                "visible": (vis.dock ?? true) && !!(dock && dock.enabled)
            },
            "notch": {
                "pos": notch && notch.position ? notch.position : "top",
                "height": BarMetrics.notchRestHeight,
                "visible": vis.notch ?? true
            }
        };
    }

    function insets(screen, visibility) {
        return EdgeLayout.insets(envFor(screen, visibility));
    }

    function workArea(screen, visibility) {
        return EdgeLayout.workArea(envFor(screen, visibility));
    }

    function popupPlacement(screen, anchor, size, edge, gap) {
        return EdgeLayout.popupPlacement(anchor, size, edge, envFor(screen), gap);
    }

    function sheetSide(screen, pref) {
        return EdgeLayout.sheetSide(envFor(screen), pref || "auto");
    }

    function spotlightRect(screen, size) {
        return EdgeLayout.spotlightRect(envFor(screen), size);
    }

    function osdPlacement(screen, pref, size) {
        return EdgeLayout.osdPlacement(envFor(screen), pref || "auto", size);
    }

    function freeCorner(screen, pref) {
        return EdgeLayout.freeCorner(envFor(screen), pref || "auto");
    }
}
