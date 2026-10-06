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
