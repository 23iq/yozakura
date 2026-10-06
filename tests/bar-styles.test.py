"""bar.layout.style looks (full/classic, floating, islands, pills, dock-like,
none) on all four edges, offscreen: the reserved zone equals the depth the
body occupies (EdgeLayout.insets: frame + bar size), nothing is clipped,
dock-like centers, none has no bar at all."""
import json
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent / "lib"))
from panels_env import PanelsEnv  # noqa: E402
from PySide6.QtTest import QTest  # noqa: E402

W, H, FRAME = 1600, 900, 6
EDGES = ["top", "bottom", "left", "right"]
STYLES = ["classic", "floating", "islands", "pills", "dock-like", "none"]
LAYOUT = {"left": ["launcher", "workspaces"], "right": ["battery", "clock", "power"], "drawer": ["systray"]}
ENV = PanelsEnv("bar-styles", bar={"position": "top", "frameEnabled": True, "frameThickness": FRAME,
                                   "layout": {"style": "classic", **LAYOUT}})
WIN = ENV.scene(W, H, windows=False)
HOST = ENV.h.find(WIN, "host")


def insets(frame, edge, size):
    """modules/shell/EdgeLayout.js insets() for a bar alone."""
    r = {e: frame for e in EDGES}
    r[edge] += size
    return r


def scene(style, edge):
    """Switch the live bar (one engine for every case, like a user would)."""
    ENV.h.eval(HOST, "Config.bar.position = '%s'" % edge)
    ENV.h.eval(HOST, "Config.bar.layout = Object.assign({}, Config.bar.layout, {style: '%s'})" % style)
    QTest.qWait(150)
    return ENV, WIN, HOST


for style in STYLES:
    for edge in EDGES:
        env, win, host = scene(style, edge)
        ev = lambda expr, env=env, host=host: env.h.eval(host, expr)  # noqa: E731
        where = (style, edge)
        zones = {e: ev("zones." + e) for e in EDGES}
        if style == "none":
            assert ev("bars.length") == 0, where
            assert zones == {e: 0 for e in EDGES}, (where, zones)
            assert ev("hitRegions.length") == 0, where
            continue

        assert ev("bars.length") == 1, where
        assert ev("primary.styleItem !== null"), where
        zone = zones[edge]
        assert zone > 0 and zone == ev("primary.edgeDepth"), (where, zones)
        assert all(zones[e] == 0 for e in EDGES if e != edge), (where, zones)

        # Body of the style in window coordinates
        r = json.loads(ev("(function(s){ const p = s.mapToItem(host, 0, 0); return JSON.stringify([p.x, p.y, s.width, s.height]); })(primary.styleItem)"))
        x, y, w, h = r
        far = {"top": y + h, "bottom": H - y, "left": x + w, "right": W - x}[edge]
        near = {"top": y, "bottom": H - y - h, "left": x, "right": W - x - w}[edge]
        assert abs(far - insets(FRAME, edge, zone)[edge]) <= 1, (where, far, zone)
        assert near >= FRAME - 0.5, (where, near)
        assert x >= -0.5 and y >= -0.5 and x + w <= W + 0.5 and y + h <= H + 0.5, (where, r)
        assert w > 0 and h > 0, (where, r)

        # Nothing clipped: the style's visible parts stay inside its body
        kids = json.loads(ev("(function(s){ const out = []; for (let i = 0; i < s.children.length; i++) { const c = s.children[i];"
                  " if (c.visible && c.width > 0) out.push([c.x, c.y, c.width, c.height]); } return JSON.stringify(out); })(primary.styleItem)"))
        for cx, cy, cw, ch in kids:
            assert cx >= -0.5 and cy >= -0.5 and cx + cw <= w + 0.5 and cy + ch <= h + 0.5, (where, (cx, cy, cw, ch), (w, h))

        length = w if edge in ("top", "bottom") else h
        if style == "dock-like":
            span, start = ev("primary.spanLength"), ev("primary.spanStart")
            edge_len = W if edge in ("top", "bottom") else H
            assert abs(2 * start + span - edge_len) <= 1, (where, start, span)
            assert span < edge_len - 2 * FRAME, (where, span)
            assert ev("primary.panelLength") <= span + 0.5, where
        else:
            edge_len = W if edge in ("top", "bottom") else H
            assert length > edge_len / 2, (where, length)
        if style in ("floating", "pills"):
            assert ev("primary.effectiveOuterMargin") > 4, where
            assert ev("primary.contained") is False, where

# Switching style live keeps one bar and only changes its depth
env, win, host = scene("classic", "top")
before = env.h.eval(host, "zones.top")
env.h.eval(host, "Config.bar.layout = Object.assign({}, Config.bar.layout, {style: 'floating'})")
QTest.qWait(150)
assert env.h.eval(host, "bars.length") == 1
assert env.h.eval(host, "primary.panelStyle") == "floating"
assert env.h.eval(host, "zones.top") > before

print("bar-styles: ok", flush=True)
# Type check + temp cleanup, then leave without Qt's destructor pass
ENV.h.exit(0)
