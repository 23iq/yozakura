.pragma library
.import "../../shell/EdgeLayout.js" as EdgeLayout

// Geometry of the Layout page's edge preview, in screen pixels: where the
// bar, dock and notch sit and where the launcher, dashboard and OSD appear
// for the current hosts. Host placement comes from EdgeLayout (the same math
// the hosts use); the bar/dock/notch strips are only drawn here.
//   e:   EdgeLayout environment (EdgeService.envFor)
//   cfg: {launcherHost, dashboardHost, sheetSide, launcher: {w,h},
//         dashboard: {w,h}, sheetW, osdPosition, osd: {w,h}}

function _strip(e, pos, size, offset, length) {
    var s = e.screen;
    var f = e.frame || 0;
    var o = f + (offset || 0);
    if (pos === "top" || pos === "bottom") {
        var w = length || s.w - 2 * f;
        return { x: (s.w - w) / 2, y: pos === "top" ? o : s.h - o - size, w: w, h: size };
    }
    var h = length || s.h - 2 * f;
    return { x: pos === "left" ? o : s.w - o - size, y: (s.h - h) / 2, w: size, h: h };
}

function _sameEdge(a, b) {
    return a && b && a.visible && b.visible && a.pos === b.pos;
}

function _hostRect(e, host, size, cfg) {
    if (host === "spotlight")
        return EdgeLayout.spotlightRect(e, size);
    if (host === "sheet")
        return EdgeLayout.sheetRect(e, cfg.sheetSide, Math.max(cfg.sheetW || 0, size.w));
    // notch: grows away from its edge, below/above the bar on that edge
    var s = e.screen;
    var off = (e.frame || 0) + (_sameEdge(e.bar, { pos: e.notch.pos, visible: true }) ? e.bar.size : 0);
    var w = Math.min(size.w, s.w);
    return {
        x: Math.round((s.w - w) / 2),
        y: e.notch.pos === "bottom" ? s.h - off - size.h : off,
        w: w,
        h: size.h
    };
}

function scene(e, cfg) {
    var out = [];
    if (e.bar && e.bar.visible)
        out.push(Object.assign({ id: "bar" }, _strip(e, e.bar.pos, e.bar.size, 0, 0)));
    if (e.dock && e.dock.visible) {
        var long = e.dock.pos === "top" || e.dock.pos === "bottom" ? e.screen.w : e.screen.h;
        out.push(Object.assign({ id: "dock" }, _strip(e, e.dock.pos, e.dock.size, _sameEdge(e.bar, e.dock) ? e.bar.size : 0, Math.round(long * 0.4))));
    }
    if (e.notch && e.notch.visible) {
        var nOff = _sameEdge(e.bar, { pos: e.notch.pos, visible: true }) ? e.bar.size : 0;
        out.push(Object.assign({ id: "notch" }, _strip(e, e.notch.pos, e.notch.height, nOff, Math.round(e.screen.w * 0.12))));
    }
    out.push(Object.assign({ id: "launcher", host: cfg.launcherHost }, _hostRect(e, cfg.launcherHost, cfg.launcher, cfg)));
    out.push(Object.assign({ id: "dashboard", host: cfg.dashboardHost }, _hostRect(e, cfg.dashboardHost, cfg.dashboard, cfg)));
    var osd = EdgeLayout.osdPlacement(e, cfg.osdPosition || "auto", cfg.osd);
    out.push({ id: "osd", x: osd.x, y: osd.y, w: cfg.osd.w, h: cfg.osd.h });
    return out;
}
