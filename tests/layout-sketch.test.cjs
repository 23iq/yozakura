const { test } = require('node:test');
const assert = require('node:assert/strict');
const path = require('node:path');
const { loadLibrary } = require('./lib/qmljs.cjs');
const S = loadLibrary(path.join(__dirname, '../modules/settings/layout/LayoutSketch.js'));

const EDGES = ['top', 'bottom', 'left', 'right'];
const env = (bar, dock, notch) => ({ screen: { w: 1920, h: 1080 }, frame: 0,
    bar: { pos: bar, size: 40, visible: true }, dock: { pos: dock, size: 64, visible: true },
    notch: { pos: notch, height: 36, visible: true } });
const cfg = (l, d) => ({ launcherHost: l, dashboardHost: d, sheetSide: 'auto', sheetW: 420,
    launcher: { w: 464, h: 296 }, dashboard: { w: 900, h: 344 }, osdPosition: 'auto', osd: { w: 220, h: 48 } });
const byId = (list) => Object.fromEntries(list.map((r) => [r.id, r]));
const overlaps = (a, b) => a.x < b.x + b.w && b.x < a.x + a.w && a.y < b.y + b.h && b.y < a.y + a.h;
const inside = (r) => r.x >= 0 && r.y >= 0 && r.x + r.w <= 1920 && r.y + r.h <= 1080;

test('every item is on screen and no host covers the bar, for every edge combination', () => {
    for (const bar of EDGES) for (const dock of EDGES) for (const notch of ['top', 'bottom'])
        for (const hosts of [['notch', 'notch'], ['spotlight', 'sheet'], ['sheet', 'spotlight']]) {
            const r = byId(S.scene(env(bar, dock, notch), cfg(...hosts)));
            const tag = `${bar}/${dock}/${notch}/${hosts}`;
            for (const k of Object.keys(r)) assert.ok(inside(r[k]), `${tag} ${k}`);
            for (const k of ['launcher', 'dashboard', 'osd'])
                assert.ok(!overlaps(r[k], r.bar), `${tag} ${k} over bar`);
            assert.ok(!overlaps(r.dock, r.bar), `${tag} dock over bar`);
        }
});
test('notch-hosted views grow away from the notch edge', () => {
    const top = byId(S.scene(env('top', 'bottom', 'top'), cfg('notch', 'notch')));
    assert.equal(top.launcher.y, 40);
    const bottom = byId(S.scene(env('left', 'right', 'bottom'), cfg('notch', 'notch')));
    assert.equal(bottom.launcher.y + bottom.launcher.h, 1080);
});
test('the sheet follows the auto side and the host is reported', () => {
    const r = byId(S.scene(env('right', 'bottom', 'top'), cfg('spotlight', 'sheet')));
    assert.equal(r.dashboard.host, 'sheet');
    assert.equal(r.dashboard.side, 'left');
    assert.equal(r.dashboard.w, 900);
    assert.equal(r.launcher.host, 'spotlight');
});

const M = loadLibrary(path.join(__dirname, '../modules/shell/LayoutModel.js'));
const mock = { w: 400, h: 240, thick: 20, gap: 4, inset: 6 };
const layout = (bar, notch, dock, on = [true, true, true]) => ({
    bar: { enabled: on[0], edge: bar, style: 'classic', align: 'fill' },
    notch: { enabled: on[1], edge: notch, style: 'attached', align: 'center' },
    dock: { enabled: on[2], edge: dock, style: 'default', align: 'center' }
});
test('part rects: one per enabled part, inside the mock, never overlapping', () => {
    for (const bar of EDGES) for (const dock of EDGES) for (const notch of ['top', 'bottom'])
        for (const on of [[true, true, true], [false, true, true], [true, false, false], [false, false, true]]) {
            const l = layout(bar, notch, dock, on);
            const rects = S.partRects(l, M.stacking(l), mock);
            const tag = `${bar}/${dock}/${notch}/${on}`;
            assert.equal(rects.length, on.filter(Boolean).length, tag);
            for (const r of rects) {
                assert.ok(r.x >= 0 && r.y >= 0 && r.x + r.w <= mock.w && r.y + r.h <= mock.h, `${tag} ${r.id} inside`);
                assert.equal(r.vertical, r.edge === 'left' || r.edge === 'right');
            }
            for (let i = 0; i < rects.length; i++) for (let j = i + 1; j < rects.length; j++)
                assert.ok(!overlaps(rects[i], rects[j]), `${tag} ${rects[i].id}/${rects[j].id}`);
        }
});
test('part rects stack outward-in and follow the align', () => {
    const l = layout('top', 'top', 'top');
    const r = byId(S.partRects(l, M.stacking(l), mock));
    assert.equal(r.bar.y, 6);
    assert.equal(r.dock.y, 30);
    assert.equal(r.notch.y, 54);
    const s = layout('top', 'bottom', 'left');
    s.notch.align = 'start';
    s.bar.align = 'end';
    const q = byId(S.partRects(s, M.stacking(s), mock));
    assert.equal(q.notch.x, q.dock.x + q.dock.w + 4, 'a start notch clears the side dock');
    assert.equal(q.bar.x + q.bar.w, 394);
    assert.ok(q.bar.w < 388);
});
test('nearest edge of a point in the mock', () => {
    assert.equal(S.nearestEdge(200, 5, 400, 240), 'top');
    assert.equal(S.nearestEdge(200, 230, 400, 240), 'bottom');
    assert.equal(S.nearestEdge(3, 120, 400, 240), 'left');
    assert.equal(S.nearestEdge(390, 120, 400, 240), 'right');
    assert.equal(S.nearestEdge(200, 300, 400, 240), '', 'outside the screen');
});
