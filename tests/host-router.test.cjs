const { test } = require('node:test');
const assert = require('node:assert/strict');
const path = require('node:path');
const { loadLibrary } = require('./lib/qmljs.cjs');
const R = loadLibrary(path.join(__dirname, '../modules/shell/hosts/HostRouter.js'));
const L = loadLibrary(path.join(__dirname, '../modules/shell/EdgeLayout.js'));

const layout = (launcher, dashboard) => ({ launcher: { host: launcher }, dashboard: { host: dashboard } });
const vis = (o) => Object.assign({ launcher: false, dashboard: false, powermenu: false, tools: false, aiquick: false }, o);

test('known hosts map through', () => {
    assert.equal(R.hostFor(layout('spotlight', 'sheet'), 'launcher'), 'spotlight');
    assert.equal(R.hostFor(layout('spotlight', 'sheet'), 'dashboard'), 'sheet');
});
test('unknown host, missing config or unroutable module fall back to notch', () => {
    assert.equal(R.hostFor(layout('bogus', 42), 'launcher'), 'notch');
    assert.equal(R.hostFor(layout('bogus', 42), 'dashboard'), 'notch');
    assert.equal(R.hostFor(null, 'launcher'), 'notch');
    assert.equal(R.hostFor({ launcher: null }, 'launcher'), 'notch');
    assert.equal(R.hostFor(layout('sheet', 'sheet'), 'powermenu'), 'notch');
    assert.equal(R.isKnown('bogus'), false);
    assert.equal(R.isKnown('sheet'), true);
});
test('moduleIn returns the open module routed to a host', () => {
    const l = layout('spotlight', 'sheet');
    assert.equal(R.moduleIn(vis({ launcher: true }), l, 'spotlight'), 'launcher');
    assert.equal(R.moduleIn(vis({ launcher: true }), l, 'sheet'), '');
    assert.equal(R.moduleIn(vis({ dashboard: true }), l, 'sheet'), 'dashboard');
    assert.equal(R.moduleIn(vis({ powermenu: true }), l, 'sheet'), '');
    assert.equal(R.moduleIn(null, l, 'sheet'), '');
});
test('the notch only opens for modules it hosts', () => {
    const l = layout('spotlight', 'notch');
    assert.equal(R.notchOpen(vis({ launcher: true }), l), false);
    assert.equal(R.notchOpen(vis({ dashboard: true }), l), true);
    assert.equal(R.notchOpen(vis({ tools: true }), l), true);
    assert.equal(R.notchOpen(vis({ aiquick: true }), l), true);
    assert.equal(R.notchOpen(vis({}), l), false);
    assert.equal(R.notchOpen(null, l), false);
    assert.equal(R.notchOpen(vis({ launcher: true }), null), true);
});

const EDGES = ['top', 'bottom', 'left', 'right'];
const env = (bar, dock, notch) => ({ screen: { w: 1920, h: 1080 }, frame: 0,
    bar: { pos: bar, size: 40, visible: true }, dock: { pos: dock, size: 64, visible: true },
    notch: { pos: notch, height: 36, visible: true } });
const overlaps = (a, b) => a.x < b.x + b.w && b.x < a.x + a.w && a.y < b.y + b.h && b.y < a.y + a.h;
const barRect = (e) => ({ top: { x: 0, y: 0, w: 1920, h: 40 }, bottom: { x: 0, y: 1040, w: 1920, h: 40 },
    left: { x: 0, y: 0, w: 40, h: 1080 }, right: { x: 1880, y: 0, w: 40, h: 1080 } }[e.bar.pos]);

test('the sheet fills the work area height on its side and never covers the bar', () => {
    for (const bar of EDGES) for (const dock of EDGES) for (const notch of ['top', 'bottom']) {
        const e = env(bar, dock, notch);
        const w = L.workArea(e);
        const r = L.sheetRect(e, 'auto', 440);
        const tag = `${bar}/${dock}/${notch}`;
        assert.equal(r.y, w.y, tag);
        assert.equal(r.h, w.h, tag);
        assert.equal(r.w, 440, tag);
        assert.ok(!overlaps(r, barRect(e)), tag);
        assert.equal(r.side, L.sheetSide(e, 'auto'), tag);
        if (r.side === 'right') assert.equal(r.x + r.w, w.x + w.w, tag);
        else assert.equal(r.x, w.x, tag);
    }
});
test('a right bar puts the auto sheet on the left; explicit sides win', () => {
    assert.equal(L.sheetRect(env('right', 'bottom', 'top'), 'auto', 400).side, 'left');
    assert.equal(L.sheetRect(env('top', 'bottom', 'top'), 'left', 400).side, 'left');
});
test('the sheet width is clamped to the work area', () => {
    const e = env('left', 'right', 'top');
    const r = L.sheetRect(e, 'auto', 5000);
    assert.equal(r.w, L.workArea(e).w);
});
