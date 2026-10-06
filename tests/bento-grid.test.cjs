const { test } = require('node:test');
const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');
const { loadLibrary } = require('./lib/qmljs.cjs');

const dir = path.join(__dirname, '../modules/widgets/dashboard/widgets');
const R = loadLibrary(path.join(dir, 'WidgetRegistry.js'));
const G = loadLibrary(path.join(dir, 'BentoGrid.js'));
const T = loadLibrary(path.join(__dirname, '../modules/widgets/dashboard/DashboardTabs.js'));
const plain = v => JSON.parse(JSON.stringify(v));

function overlaps(cells) {
    for (let i = 0; i < cells.length; i++)
        for (let j = i + 1; j < cells.length; j++) {
            const a = cells[i], b = cells[j];
            if (a.x < b.x + b.w && b.x < a.x + a.w && a.y < b.y + b.h && b.y < a.y + a.h)
                return true;
        }
    return false;
}
const at = (cells, id) => plain(cells.find(c => c.widget === id));

// ------------------------------------------------------------ registry

test('every registry widget is complete, host-agnostic and its file exists', () => {
    assert.deepEqual(plain(R.ids()), ['player', 'quickControls', 'calendar', 'specials', 'notifications', 'levels', 'weather', 'metricsSummary', 'pomodoro', 'worldClocks', 'agenda']);
    for (const w of R.widgets) {
        assert.ok(w.labelKey && w.icon && w.url, w.id);
        assert.ok(fs.existsSync(path.join(dir, w.url)), w.url);
        assert.ok(w.minW >= 1 && w.minH >= 1 && w.defaultW >= w.minW && w.defaultH >= w.minH, w.id);
        assert.ok(w.maxW >= w.defaultW && w.maxH >= w.defaultH, w.id);
    }
    assert.equal(R.byId('nope'), null);
});

test('the default grid reproduces the old widgets tab (player | controls+calendar+specials | notifications | levels)', () => {
    const cells = R.defaultGrid(4);
    assert.deepEqual(plain(cells.map(c => c.widget)), ['player', 'quickControls', 'calendar', 'notifications', 'specials', 'levels']);
    assert.ok(!overlaps(cells));
    assert.deepEqual(at(cells, 'player'), { widget: 'player', x: 0, y: 0, w: 1, h: 3 });
    assert.deepEqual(at(cells, 'levels'), { widget: 'levels', x: 3, y: 0, w: 1, h: 3 });
    assert.ok(at(cells, 'calendar').y < at(cells, 'specials').y);
    // narrower hosts still get a valid grid
    for (const cols of [1, 2, 3, 6])
        assert.ok(!overlaps(G.normalize(R.defaultGrid(cols), cols, R)), String(cols));
});

// ------------------------------------------------------------ normalize

test('empty or corrupt input gives the default grid', () => {
    const def = plain(G.normalize(R.defaultGrid(4), 4, R));
    for (const bad of [[], null, undefined, 'x', 42, { a: 1 }, [null, 3, 'a'], [{ widget: 'ghost', x: 0, y: 0, w: 1, h: 1 }]])
        assert.deepEqual(plain(G.normalize(bad, 4, R)), def, JSON.stringify(bad));
});

test('normalize drops unknown ids and duplicates', () => {
    const out = G.normalize([
        { widget: 'calendar', x: 0, y: 0, w: 1, h: 1 },
        { widget: 'ghost', x: 1, y: 0, w: 1, h: 1 },
        { widget: 'calendar', x: 2, y: 0, w: 1, h: 1 }
    ], 4, R);
    assert.deepEqual(plain(out), [{ widget: 'calendar', x: 0, y: 0, w: 1, h: 1 }]);
});

test('normalize clamps out-of-bounds positions and sizes', () => {
    const out = G.normalize([
        { widget: 'quickControls', x: 9, y: -3, w: 99, h: 0 },
        { widget: 'player', x: -2, y: 5.6, w: 'a', h: 1 }
    ], 4, R);
    const qc = at(out, 'quickControls');
    assert.equal(qc.x + qc.w <= 4, true);
    assert.equal(qc.y, 0);
    assert.equal(qc.w, R.byId('quickControls').maxW);
    assert.equal(qc.h, R.byId('quickControls').minH);
    const p = at(out, 'player');
    assert.equal(p.x, 0);
    assert.equal(p.h, R.byId('player').minH);
    assert.equal(p.w, R.byId('player').minW);
    // wider than cols: clamped to cols
    const one = G.normalize([{ widget: 'quickControls', x: 0, y: 0, w: 2, h: 1 }], 1, R);
    assert.equal(at(one, 'quickControls').w, 1);
});

test('normalize resolves overlaps by pushing down and compacts upward', () => {
    const out = G.normalize([
        { widget: 'calendar', x: 0, y: 0, w: 2, h: 2 },
        { widget: 'specials', x: 1, y: 1, w: 2, h: 1 },
        { widget: 'notifications', x: 3, y: 7, w: 1, h: 2 }
    ], 4, R);
    assert.ok(!overlaps(out));
    assert.deepEqual(at(out, 'specials'), { widget: 'specials', x: 1, y: 2, w: 2, h: 1 });
    assert.equal(at(out, 'notifications').y, 0);
});

test('normalize is idempotent', () => {
    const messy = [
        { widget: 'weather', x: 1, y: 1, w: 2, h: 2 },
        { widget: 'calendar', x: 0, y: 0, w: 2, h: 2 },
        { widget: 'player', x: 3, y: 4, w: 1, h: 3 }
    ];
    const once = plain(G.normalize(messy, 4, R));
    assert.deepEqual(plain(G.normalize(once, 4, R)), once);
    const def = plain(G.normalize(R.defaultGrid(4), 4, R));
    assert.deepEqual(plain(G.normalize(def, 4, R)), def);
});

// ------------------------------------------------------------ edits

test('move pushes colliding tiles down and keeps the moved tile in place', () => {
    const base = G.normalize(R.defaultGrid(4), 4, R);
    const out = G.move(base, 'levels', 0, 0, 4, R);
    assert.ok(!overlaps(out));
    assert.deepEqual(at(out, 'levels'), { widget: 'levels', x: 0, y: 0, w: 1, h: 3 });
    assert.equal(at(out, 'player').x, 0);
    assert.ok(at(out, 'player').y >= 3);
    // moving off the right edge is clamped, unknown ids are a no-op
    assert.equal(at(G.move(base, 'quickControls', 10, 0, 4, R), 'quickControls').x, 2);
    assert.deepEqual(plain(G.move(base, 'ghost', 0, 0, 4, R)), plain(base));
});

test('resize clamps to the widget limits and pushes neighbours', () => {
    const base = G.normalize([
        { widget: 'calendar', x: 0, y: 0, w: 1, h: 1 },
        { widget: 'specials', x: 1, y: 0, w: 1, h: 1 }
    ], 4, R);
    const out = G.resize(base, 'calendar', 2, 2, 4, R);
    assert.ok(!overlaps(out));
    assert.deepEqual(at(out, 'calendar'), { widget: 'calendar', x: 0, y: 0, w: 2, h: 2 });
    assert.equal(at(out, 'specials').y, 2);
    const big = G.resize(base, 'calendar', 40, 40, 4, R);
    assert.equal(at(big, 'calendar').w, R.byId('calendar').maxW);
    assert.equal(at(big, 'calendar').h, R.byId('calendar').maxH);
    const small = G.resize(base, 'calendar', 0, 0, 4, R);
    assert.equal(at(small, 'calendar').w, 1);
});

test('add places a new widget at its default size below, once; remove drops it', () => {
    const base = G.normalize(R.defaultGrid(4), 4, R);
    assert.ok(G.available(base, R).includes('weather'));
    const out = G.add(base, 'weather', 4, R);
    const w = at(out, 'weather');
    assert.equal(w.w, R.byId('weather').defaultW);
    assert.ok(!overlaps(out));
    assert.ok(!G.available(out, R).includes('weather'));
    assert.deepEqual(plain(G.add(out, 'weather', 4, R)), plain(out));
    assert.deepEqual(plain(G.add(out, 'ghost', 4, R)), plain(out));
    const removed = G.remove(out, 'weather');
    assert.equal(removed.length, base.length);
    assert.equal(G.rows(base), 4);
    assert.equal(G.rows([]), 0);
});

test('snap converts pixels to grid cells', () => {
    assert.deepEqual(plain(G.snap(150, 290, 140, 8)), { x: 1, y: 2 });
    assert.deepEqual(plain(G.snap(-40, -10, 140, 8)), { x: 0, y: 0 });
    assert.equal(G.span(140 * 2 + 8 + 30, 140, 8), 2);
    assert.equal(G.span(10, 140, 8), 1);
});

// ------------------------------------------------------------ tabs

test('tab registry resolves order and visibility, never empty', () => {
    assert.deepEqual(plain(T.ids()), ['widgets', 'wallpapers', 'metrics']);
    assert.deepEqual(plain(T.resolve([{ id: 'metrics', visible: true }, { id: 'ghost', visible: true }, { id: 'widgets', visible: false }])),
        [{ id: 'metrics', visible: true }, { id: 'widgets', visible: false }, { id: 'wallpapers', visible: true }]);
    assert.deepEqual(plain(T.visibleIndices([{ id: 'metrics', visible: true }, { id: 'widgets', visible: false }])), [2, 1]);
    assert.deepEqual(plain(T.visibleIndices([{ id: 'widgets', visible: false }, { id: 'wallpapers', visible: false }, { id: 'metrics', visible: false }])), [0]);
    assert.deepEqual(plain(T.visibleIndices('garbage')), [0, 1, 2]);
    assert.deepEqual(plain(T.move(T.resolve([]), 'metrics', -1)).map(t => t.id), ['widgets', 'metrics', 'wallpapers']);
    assert.deepEqual(plain(T.move(T.resolve([]), 'widgets', -1)).map(t => t.id), ['widgets', 'wallpapers', 'metrics']);
    assert.equal(T.setVisible(T.resolve([]), 'metrics', false)[2].visible, false);
    assert.equal(T.step([2, 0, 1], 0, 1), 1);
    assert.equal(T.step([2, 0, 1], 1, 1), 2);
    assert.equal(T.step([2, 0, 1], 2, -1), 1);
    assert.equal(T.step([2, 0], 1, 1), 2);
});
