const { test } = require('node:test');
const assert = require('node:assert/strict');
const path = require('node:path');
const { loadLibrary } = require('./lib/qmljs.cjs');
const L = loadLibrary(path.join(__dirname, '../modules/shell/EdgeLayout.js'));
const EDGES = ['top', 'bottom', 'left', 'right'];
const env = (bar, dock, notch) => ({ screen: { w: 1920, h: 1080 }, frame: 0,
    bar: { pos: bar, size: 40, visible: true }, dock: { pos: dock, size: 64, visible: true },
    notch: { pos: notch, height: 36, visible: true } });
const inside = (r, s) => r.x >= 0 && r.y >= 0 && r.x + r.w <= s.w && r.y + r.h <= s.h;

test('popups stay on screen and open away from the bar, for every edge combination', () => {
    for (const bar of EDGES) for (const dock of EDGES) for (const notch of ['top', 'bottom']) {
        const e = env(bar, dock, notch);
        const a = { top: { x: 1900, y: 0, w: 20, h: 40 }, bottom: { x: 0, y: 1040, w: 20, h: 40 },
                    left: { x: 0, y: 1060, w: 40, h: 20 }, right: { x: 1880, y: 0, w: 40, h: 20 } }[bar];
        const p = L.popupPlacement(a, { w: 300, h: 400 }, bar, e, 8);
        assert.ok(inside({ x: p.x, y: p.y, w: 300, h: 400 }, e.screen), `${bar}/${dock}/${notch}`);
        assert.equal(p.dir, { top: 'down', bottom: 'up', left: 'right', right: 'left' }[bar]);
    }
});
test('popups flip when they do not fit', () => {
    const e = env('top', 'bottom', 'top');
    const p = L.popupPlacement({ x: 100, y: 700, w: 20, h: 40 }, { w: 300, h: 400 }, 'top', e, 8);
    assert.equal(p.flipped, true);
    assert.equal(p.dir, 'up');
});
test('work area excludes bar and dock even on the same edge', () => {
    const w = L.workArea(env('left', 'left', 'top'));
    assert.equal(w.x, 104); assert.equal(w.w, 1920 - 104);
});
test('sheet auto opens opposite a vertical bar', () => {
    assert.equal(L.sheetSide(env('right', 'bottom', 'top'), 'auto'), 'left');
    assert.equal(L.sheetSide(env('left', 'bottom', 'top'), 'auto'), 'right');
    assert.equal(L.sheetSide(env('top', 'bottom', 'top'), 'auto'), 'right');
    assert.equal(L.sheetSide(env('right', 'bottom', 'top'), 'right'), 'right');
});
test('osd and toasts avoid occupied edges', () => {
    for (const bar of EDGES) for (const dock of EDGES) {
        const e = env(bar, dock, 'top');
        const o = L.osdPlacement(e, 'auto', { w: 220, h: 48 });
        assert.ok(o.edge !== bar && o.edge !== dock, `${bar}/${dock} -> ${o.edge}`);
        const c = L.freeCorner(e, 'auto');
        // opposite bar/dock edges leave no free corner: then touch as few as possible
        const free = ['top-right', 'top-left', 'bottom-right', 'bottom-left']
            .filter(k => !k.includes(bar) && !k.includes(dock));
        if (free.length) assert.ok(free.includes(c), `${bar}/${dock} -> ${c}`);
        else assert.ok(!c.includes(bar) || !c.includes(dock), `${bar}/${dock} -> ${c}`);
    }
});
test('invisible bars and docks reserve nothing', () => {
    const e = env('top', 'bottom', 'top');
    e.bar.visible = false; e.dock.visible = false; e.notch.visible = false; e.frame = 6;
    assert.deepEqual(JSON.parse(JSON.stringify(L.insets(e))), { top: 6, right: 6, bottom: 6, left: 6 });
});
test('spotlight is inside the work area', () => {
    for (const bar of EDGES) {
        const e = env(bar, 'bottom', 'top'), w = L.workArea(e), r = L.spotlightRect(e, { w: 900, h: 400 });
        assert.ok(r.x >= w.x && r.y >= w.y && r.x + r.w <= w.x + w.w && r.y + r.h <= w.y + w.h, bar);
    }
});
