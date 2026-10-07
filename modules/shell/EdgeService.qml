pragma Singleton
import QtQuick
import Quickshell
import qs.config
import qs.modules.theme
import "EdgeLayout.js" as EdgeLayout
import "../bar/panels/PanelLayout.js" as PanelLayout

// Builds the EdgeLayout environment for a screen from Config.bar/dock/notch
// and exposes the placement helpers bound to it. All edge-aware UI (popups,
// sheets, OSD, spotlight, toasts) goes through here; no placement math lives
// in QML.
Singleton {
    id: root

    // The rendered panels publish their measured style/content depth. Config
    // is the fallback before the per-screen PanelHost has been constructed.
    property var panelGeometry: ({})

    function setPanels(name, panels) {
        const next = Object.assign({}, panelGeometry);
        if (panels === null)
            delete next[name];
        else
            next[name] = panels;
        panelGeometry = next;
    }

    function panelsFor(screen, visible) {
        const name = screen ? screen.name : "";
        const measured = panelGeometry[name];
        if (measured !== undefined)
            return measured.map(p => ({
                        pos: p.pos,
                        size: p.size,
                        visible: visible
                    }));
        const all = PanelLayout.normalize(Config.bar).panels;
        const screens = Quickshell.screens;
        let index = 0;
        for (let i = 0; screens && i < screens.length; i++) {
            if (screens[i].name === name)
                index = i;
        }
        return PanelLayout.forScreen(all, name, index).map(p => ({
                    pos: p.edge,
                    size: PanelLayout.estimateDepth(p, BarMetrics.moduleSize),
                    visible: visible
                }));
    }

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
            "panels": panelsFor(screen, vis.bar ?? true),
            "dock": {
                "pos": dock && dock.position ? dock.position : "bottom",
                "size": dock && dock.height ? dock.height : 0,
                "visible": (vis.dock ?? true) && !!(dock && dock.enabled)
            },
            "notch": {
                "pos": notch && notch.position ? notch.position : "top",
                "height": BarMetrics.notchRestHeight,
                "align": notch && notch.align ? notch.align : "center",
                "visible": (vis.notch ?? true) && !(notch && notch.enabled === false)
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

    function sheetRect(screen, pref, width) {
        return EdgeLayout.sheetRect(envFor(screen), pref || "auto", width);
    }

    function spotlightRect(screen, size) {
        return EdgeLayout.spotlightRect(envFor(screen), size);
    }

    function osdPlacement(screen, pref, size) {
        return EdgeLayout.osdPlacement(envFor(screen), pref || "auto", size);
    }

    // Notch of `size` {along, across} on its edge, aligned (notch.align);
    // `.dir` is where its panels open (toward the screen center)
    function notchRect(screen, size) {
        return EdgeLayout.notchRect(envFor(screen), size);
    }

    function freeCorner(screen, pref) {
        return EdgeLayout.freeCorner(envFor(screen), pref || "auto");
    }
}
