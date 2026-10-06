const { test } = require('node:test');
const assert = require('node:assert/strict');
const path = require('node:path');
const { loadLibrary } = require('./lib/qmljs.cjs');

const F = loadLibrary(path.join(__dirname, '../modules/settings/displays/DisplayFormat.js'));
const plain = v => JSON.parse(JSON.stringify(v));

const cfg = (name, extra = {}) => ({
    name, enabled: true, width: 1920, height: 1080, refresh: 60, x: 0, y: 0, scale: 1, transform: 0, ...extra,
});
const output = {
    make: 'Dell', model: 'U2723QE', width: 1920, height: 1080, refresh: 60,
    modes: [
        { width: 1920, height: 1080, refresh: 60 }, { width: 1920, height: 1080, refresh: 144.0004 },
        { width: 1280, height: 720, refresh: 60 },
    ],
};

test('formatHz drops zero decimals and keeps NTSC rates', () => {
    assert.equal(F.formatHz(240), '240 Hz');
    assert.equal(F.formatHz(59.9401), '59.94 Hz');
    assert.equal(F.formatHz(143.9999), '144 Hz');
});

test('resolution options and keys round trip', () => {
    const o = plain(F.resolutionOptions(output));
    assert.deepEqual(o.map(x => x.value), ['1920x1080', '1280x720']);
    assert.equal(o[0].label, '1920 × 1080');
    assert.deepEqual(plain(F.parseResolution('2560x1440')), { width: 2560, height: 1440 });
});

test('refresh options mark only the maximum, and only when there is a choice', () => {
    const r = plain(F.refreshOptions(output, cfg('A')));
    assert.deepEqual(r.map(x => x.value), [144, 60]);
    assert.deepEqual(r.map(x => x.max), [true, false]);
    const single = plain(F.refreshOptions(output, cfg('A', { width: 1280, height: 720 })));
    assert.deepEqual(single.map(x => x.max), [false]);
});

test('scale options keep a custom value and mark the suggestion', () => {
    const s = plain(F.scaleOptions(1.33, 1.5));
    assert.deepEqual(s.map(x => x.value), [1, 1.25, 1.33, 1.5, 1.75, 2, 3]);
    assert.deepEqual(s.filter(x => x.max).map(x => x.value), [1.5]);
    assert.equal(s[0].label, '100%');
    assert.equal(plain(F.scaleOptions(2, 1)).length, 6);
});

test('numbering orders by x then y, skipping disabled outputs', () => {
    const n = plain(F.numbering([cfg('R', { x: 1920 }), cfg('X', { x: 0, enabled: false }), cfg('L', { x: 0 })]));
    assert.deepEqual(n, { L: 1, R: 2 });
});

test('fitLayout centres the bounding box with drag room', () => {
    const one = plain(F.fitLayout([cfg('A')], 600, 300));
    assert.ok(one.scale > 0 && 1920 * one.scale < 600 && 1080 * one.scale < 300);
    assert.ok(Math.abs(one.ox + 960 * one.scale - 300) < 0.01);
    assert.ok(Math.abs(one.oy + 540 * one.scale - 150) < 0.01);
    const two = plain(F.fitLayout([cfg('A'), cfg('B', { x: 1920 })], 600, 300));
    assert.ok(3840 * two.scale < 600);
    assert.equal(plain(F.fitLayout([], 600, 300)).scale, 0.1);
});

test('title falls back to the connector', () => {
    assert.equal(F.title(output, cfg('DP-1')), 'Dell U2723QE');
    assert.equal(F.title(null, cfg('DP-1')), 'DP-1');
});
