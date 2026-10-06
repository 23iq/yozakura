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

// Notch on any edge, aligned start/center/end along it.
const envN = (bar, dock, notch, align) => Object.assign(env(bar, dock, notch), { notch: { pos: notch, height: 36, visible: true, align } });
const ALIGNS = ['start', 'center', 'end'];
test('notch rect touches its edge, stays on screen and leaves bars and docks alone', () => {
    for (const bar of EDGES) for (const dock of EDGES) for (const notch of EDGES) for (const align of ALIGNS) {
        const e = envN(bar, dock, notch, align);
        const r = L.notchRect(e, { along: 300, across: 36 });
        const tag = `${bar}/${dock}/${notch}/${align}`;
        assert.ok(inside(r, e.screen), tag);
        assert.equal(r.vertical, notch === 'left' || notch === 'right', tag);
        assert.equal(r.vertical ? r.h : r.w, 300, tag);
        if (notch === 'top') assert.equal(r.y, 0, tag);
        if (notch === 'bottom') assert.equal(r.y + r.h, 1080, tag);
        // a side notch sits next to a bar or dock on its own edge
        const own = (bar === notch ? 40 : 0) + (dock === notch ? 64 : 0);
        if (notch === 'left') assert.equal(r.x, own, tag);
        if (notch === 'right') assert.equal(r.x + r.w, 1920 - own, tag);
        // the ends stay clear of a bar or dock on the perpendicular edges
        const along = r.vertical ? [r.y, r.y + r.h] : [r.x, r.x + r.w];
        const lo = r.vertical ? 'top' : 'left', hi = r.vertical ? 'bottom' : 'right';
        const total = r.vertical ? 1080 : 1920;
        const res = edge => (bar === edge ? 40 : 0) + (dock === edge ? 64 : 0);
        assert.ok(along[0] >= res(lo) && along[1] <= total - res(hi), tag);
    }
});
test('notch alignment orders start < center < end', () => {
    for (const notch of EDGES) {
        const at = a => L.notchRect(envN('top', 'bottom', notch, a), { along: 200, across: 36 });
        const k = (notch === 'left' || notch === 'right') ? 'y' : 'x';
        assert.ok(at('start')[k] < at('center')[k] && at('center')[k] < at('end')[k], notch);
    }
    const c = L.notchRect(envN('left', 'left', 'top', 'center'), { along: 200, across: 36 });
    assert.equal(c.x, 860, 'center is the screen center, not the work area');
    const bad = L.notchRect(envN('top', 'bottom', 'top', 'sideways'), { along: 200, across: 36 });
    assert.equal(bad.x, 860, 'unknown align falls back to center');
});
test('notch panels open toward the screen center and grow from the aligned end', () => {
    assert.equal(L.notchOpenDir('top'), 'down');
    assert.equal(L.notchOpenDir('bottom'), 'up');
    assert.equal(L.notchOpenDir('left'), 'right');
    assert.equal(L.notchOpenDir('right'), 'left');
    for (const notch of EDGES) for (const align of ALIGNS) {
        const e = envN('top', 'bottom', notch, align);
        const small = L.notchRect(e, { along: 200, across: 36 });
        const big = L.notchRect(e, { along: 500, across: 300 });
        const v = small.vertical, s0 = v ? small.y : small.x, b0 = v ? big.y : big.x;
        const s1 = s0 + 200, b1 = b0 + 500;
        if (align === 'start') assert.equal(b0, s0, `${notch}/${align}`);
        if (align === 'end') assert.equal(b1, s1, `${notch}/${align}`);
        if (align === 'center') assert.equal(b0 + b1, s0 + s1, `${notch}/${align}`);
        assert.ok(inside(big, e.screen), `${notch}/${align}`);
    }
});
test('a side notch reserves its thickness on that edge', () => {
    const e = envN('top', 'bottom', 'right', 'center');
    assert.equal(L.insets(e).right, 36);
    assert.equal(L.workArea(e).w, 1920 - 36);
});

test('a side notch is offset by the bar, dock and frame on its edge and never overlaps them', () => {
    const rects = (e, edge, size) => ({
        left: { x: 0, y: 0, w: size, h: e.screen.h }, right: { x: e.screen.w - size, y: 0, w: size, h: e.screen.h },
        top: { x: 0, y: 0, w: e.screen.w, h: size }, bottom: { x: 0, y: e.screen.h - size, w: e.screen.w, h: size }
    })[edge];
    const overlaps = (a, b) => a.x < b.x + b.w && b.x < a.x + a.w && a.y < b.y + b.h && b.y < a.y + a.h;
    for (const notch of ['left', 'right']) for (const bar of EDGES) for (const dock of EDGES) for (const align of ALIGNS) {
        const e = envN(bar, dock, notch, align);
        e.frame = 6;
        const tag = `${notch}/${bar}/${dock}/${align}`;
        for (const size of [{ along: 220, across: 36 }, { along: 600, across: 420 }]) {
            const r = L.notchRect(e, size);
            assert.ok(inside(r, e.screen), tag);
            assert.equal(r.dir, notch === 'left' ? 'right' : 'left', tag);
            assert.ok(!overlaps(r, rects(e, bar, 6 + 40)), `bar ${tag}`);
            assert.ok(!overlaps(r, rects(e, dock, 6 + (bar === dock ? 40 : 0) + 64)), `dock ${tag}`);
        }
    }
    // hidden bar: back to the frame
    const e = envN('left', 'bottom', 'left', 'center');
    e.bar.visible = false;
    assert.equal(L.notchRect(e, { along: 200, across: 36 }).x, 0);
});
test('a top or bottom notch stays flush with its edge (the bar keeps a gap for it)', () => {
    for (const bar of EDGES) {
        assert.equal(L.notchRect(envN(bar, 'left', 'top', 'center'), { along: 200, across: 36 }).y, 0, bar);
        assert.equal(L.notchRect(envN(bar, 'left', 'bottom', 'center'), { along: 200, across: 36 }).y, 1080 - 36, bar);
    }
});
