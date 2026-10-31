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
        return configuredPanels(screen).map(p => ({
                    pos: p.edge,
                    size: PanelLayout.estimateDepth(p, BarMetrics.moduleSize),
                    visible: visible
                }));
    }

    // Configured panels of a screen (before the PanelHost measured them).
    function configuredPanels(screen) {
        const name = screen ? screen.name : "";
        const all = PanelLayout.normalize(Config.bar).panels;
        const screens = Quickshell.screens;
        let index = 0;
        for (let i = 0; screens && i < screens.length; i++) {
            if (screens[i].name === name)
                index = i;
        }
        return PanelLayout.forScreen(all, name, index);
    }

    // The integrated dock is drawn by the primary panel of the screen, and
    // only when that panel is a classic bar (BarContent.integratedDockEnabled).
    function integratedDockHosted(screen) {
        const list = configuredPanels(screen);
        const i = PanelLayout.primaryIndex(list, PanelLayout.pairEdge(Config.bar, Config.notch));
        return i !== -1 && list[i].style === "classic";
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
                // The dock has no top edge (drawn at the bottom) and an
                // integrated dock lives inside the bar: no window, no inset.
                "pos": dock && (dock.position === "left" || dock.position === "right") ? dock.position : "bottom",
                "size": dock && dock.height ? dock.height : 0,
                "visible": (vis.dock ?? true) && !!(dock && dock.enabled) && !(dock.theme === "integrated" && integratedDockHosted(screen))
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

    // Floating card of `size` {w, h} beside the bar (CardHost), clear of
    // the corner claimed on its screen
    function cardRect(screen, size, margin) {
        const claimed = screen && screen.name ? (root.cornerClaims[screen.name] || "") : "";
        return EdgeLayout.cardRect(envFor(screen), size, "auto", margin, claimed);
    }

    // Corner taken per screen name (the corner toasts: CornerToasts), so
    // the card never lands on them; "" = none
    property var cornerClaims: ({})

    function claimCorner(name, corner) {
        if (!name || (root.cornerClaims[name] || "") === (corner || ""))
            return;
        const m = Object.assign({}, root.cornerClaims);
        m[name] = corner || "";
        root.cornerClaims = m;
    }

    function freeCorner(screen, pref) {
        return EdgeLayout.freeCorner(envFor(screen), pref || "auto");
    }
}
