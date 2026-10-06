const { test } = require('node:test');
const assert = require('node:assert/strict');
const path = require('node:path');
const { loadLibrary } = require('./lib/qmljs.cjs');

const M = loadLibrary(path.join(__dirname, '../modules/services/DisplayModel.js'));
const plain = v => JSON.parse(JSON.stringify(v));

const out = (name, id, extra = {}) => ({
    id, name, enabled: true, width: 1920, height: 1080, refresh: 60, x: 0, y: 0,
    scale: 1, transform: 0, vrr: false, modes: [], ...extra,
});
const cfg = (name, id, extra = {}) => ({
    id, name, enabled: true, width: 1920, height: 1080, refresh: 60, x: 0, y: 0,
    autoPosition: false, scale: 1, transform: 0, vrr: 0, ...extra,
});

test('resolveSaved matches by id and rewrites the connector name', () => {
    const r = plain(M.resolveSaved([cfg('DP-1', 'A', { x: 5 })], [out('DP-3', 'A')]));
    assert.equal(r.length, 1);
    assert.equal(r[0].name, 'DP-3');
    assert.equal(r[0].x, 5);
});

test('resolveSaved falls back to the name and drops unmatched entries', () => {
    const r = plain(M.resolveSaved([cfg('DP-1', ''), cfg('HDMI-9', 'Z')], [out('DP-1', 'Q')]));
    assert.deepEqual(r.map(c => c.name), ['DP-1']);
    assert.equal(r[0].id, 'Q');
});

test('resolveSaved keeps identical monitors without serial apart', () => {
    const saved = [cfg('DP-1', 'D', { x: 0 }), cfg('DP-2', 'D', { x: 1920 })];
    // connectors swapped after a replug
    const r = plain(M.resolveSaved(saved, [out('DP-2', 'D'), out('DP-1', 'D')]));
    assert.deepEqual(r.map(c => [c.name, c.x]), [['DP-1', 0], ['DP-2', 1920]]);
    // only one is connected: the one with the same name wins
    const one = plain(M.resolveSaved(saved, [out('DP-2', 'D')]));
    assert.deepEqual(one.map(c => [c.name, c.x]), [['DP-2', 1920]]);
});

test('outputToConfig and the wire conversions round-trip', () => {
    const c = M.outputToConfig(out('DP-1', 'A', { vrr: true, refresh: 144 }));
    assert.equal(c.vrr, 1);
    assert.equal(c.autoPosition, false);
    const w = plain(M.toWire({ ...c, autoPosition: true }));
    assert.equal(w.auto_position, true);
    assert.equal(w.vrr, 1);
    assert.deepEqual(plain(M.fromWire(w, [out('DP-1', 'A')])), { ...plain(c), autoPosition: true });
});

test('logicalSize honours scale and 90/270 transforms', () => {
    assert.deepEqual(plain(M.logicalSize({ width: 2560, height: 1440, scale: 2, transform: 0 })), { w: 1280, h: 720 });
    assert.deepEqual(plain(M.logicalSize({ width: 1920, height: 1080, scale: 1, transform: 1 })), { w: 1080, h: 1920 });
    assert.deepEqual(plain(M.logicalSize({ width: 1920, height: 1080, scale: 1, transform: 3 })), { w: 1080, h: 1920 });
    assert.deepEqual(plain(M.logicalSize({ width: 1920, height: 1080, scale: 1, transform: 2 })), { w: 1920, h: 1080 });
});

test('arrange snaps to a neighbour edge and normalizes to 0,0', () => {
    const list = [cfg('A', 'a', { x: 0, y: 0 }), cfg('B', 'b', { x: 3000, y: 0 })];
    const r = plain(M.arrange(list, 'B', 1950, 20));
    const b = r.find(o => o.name === 'B');
    assert.equal(b.x, 1920);
    assert.equal(b.y, 0);
    const moved = plain(M.arrange(list, 'A', -300, -10));
    assert.equal(Math.min(...moved.map(o => o.x)), 0);
    assert.equal(Math.min(...moved.map(o => o.y)), 0);
});

test('arrange leaves distant drops alone and never overlaps', () => {
    const list = [cfg('A', 'a'), cfg('B', 'b', { x: 1920 })];
    const far = plain(M.arrange(list, 'B', 2500, 400));
    assert.deepEqual(far.find(o => o.name === 'B'), { ...list[1], x: 2500, y: 400 });
    const r = plain(M.arrange(list, 'B', 1000, 100));
    const [a, b] = [r.find(o => o.name === 'A'), r.find(o => o.name === 'B')];
    const apart = b.x >= a.x + 1920 || a.x >= b.x + 1920 || b.y >= a.y + 1080 || a.y >= b.y + 1080;
    assert.ok(apart, 'outputs overlap: ' + JSON.stringify(r));
});

test('suggestScale from pixel density', () => {
    assert.equal(M.suggestScale({ width: 2560, height: 1440, physical_width_mm: 597 }), 1);
    assert.equal(M.suggestScale({ width: 2880, height: 1800, physical_width_mm: 302 }), 2);
    assert.equal(M.suggestScale({ width: 2560, height: 1440, physical_width_mm: 345 }), 1.5);
    assert.equal(M.suggestScale({ width: 1920, height: 1080 }), 1);
});

test('refresh helpers', () => {
    const o = out('DP-1', 'A', {
        refresh: 60,
        modes: [
            { width: 2560, height: 1440, refresh: 59.95 },
            { width: 2560, height: 1440, refresh: 144 },
            { width: 1920, height: 1080, refresh: 240 },
        ],
        width: 2560, height: 1440,
    });
    assert.deepEqual(plain(M.refreshesFor(o, 2560, 1440)), [144, 59.95]);
    assert.equal(M.bestRefresh(o), 144);
    assert.equal(M.canUpgradeRefresh(o), true);
    assert.equal(M.canUpgradeRefresh({ ...o, refresh: 143.9 }), false);
    assert.deepEqual(plain(M.resolutions(o)), [{ width: 2560, height: 1440 }, { width: 1920, height: 1080 }]);
});

test('renderList keeps disconnected monitors and uses saved list without outputs', () => {
    const saved = [cfg('DP-1', 'A'), cfg('HDMI-1', 'B', { x: 1920 })];
    assert.deepEqual(plain(M.renderList(saved, [])), saved);
    const r = plain(M.renderList(saved, [out('DP-5', 'A')]));
    assert.deepEqual(r.map(c => c.name), ['DP-5', 'HDMI-1']);
});

const Gate = loadLibrary(path.join(__dirname, '../modules/services/WriteGate.js'));
const Kb = loadLibrary(path.join(__dirname, '../modules/services/KeyboardModel.js'));

test('write gate defers while pending and releases once after', () => {
    const g = Gate.create();
    assert.equal(Gate.request(g, false), true);
    assert.equal(Gate.release(g, false), false);
    assert.equal(Gate.request(g, true), false);
    assert.equal(Gate.request(g, true), false);
    assert.equal(Gate.release(g, true), false, 'still pending');
    assert.equal(Gate.release(g, false), true);
    assert.equal(Gate.release(g, false), false, 'only once');
});

test('mergeSaved matches by id then name, appends new', () => {
    const saved = [cfg('DP-1', 'A', { x: 0 }), cfg('DP-2', 'B', { x: 1 })];
    const r = plain(M.mergeSaved(saved, [cfg('DP-7', 'A', { x: 9 }), cfg('HDMI-1', 'C'), cfg('DP-2', '', { x: 5 })]));
    assert.deepEqual(r.map(c => [c.name, c.x]), [['DP-7', 9], ['DP-2', 5], ['HDMI-1', 0]]);
});

test('keyboard shortName', () => {
    assert.equal(Kb.shortName('us'), 'EN');
    assert.equal(Kb.shortName('ru'), 'RU');
    assert.equal(Kb.shortName(undefined), '');
});
