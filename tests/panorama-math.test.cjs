const { test } = require('node:test');
const assert = require('node:assert/strict');
const path = require('node:path');
const { loadLibrary } = require('./lib/qmljs.cjs');

const P = loadLibrary(path.join(__dirname, '../modules/desktop/panorama/PanoramaMath.js'));

test('layout scales to the screen height', () => {
    const l = P.layout(6000, 1000, 1920, 1080);
    assert.equal(l.height, 1080);
    assert.equal(l.width, 6480);
    assert.equal(l.y, 0);
    assert.equal(l.travel, 6480 - 1920);
});

test('layout of a narrow image covers the width, no travel', () => {
    const l = P.layout(1000, 2000, 1920, 1080);
    assert.equal(l.width, 1920);
    assert.equal(l.travel, 0);
    assert.ok(l.y < 0);
});

test('layout tolerates missing sizes', () => {
    assert.deepEqual({ ...P.layout(0, 0, 1920, 1080) }, { width: 1920, height: 1080, y: 0, travel: 0 });
});

test('slots are a screen apart and centred when they fit', () => {
    const travel = 6480 - 1920;
    assert.equal(P.slotX(0, 3, travel, 1920), (travel - 3840) / 2);
    assert.equal(P.slotX(1, 3, travel, 1920) - P.slotX(0, 3, travel, 1920), 1920);
});

test('slots spread over the travel when there are too many', () => {
    const travel = 4560;
    assert.equal(P.slotX(0, 10, travel, 1920), 0);
    assert.equal(P.slotX(9, 10, travel, 1920), travel);
    assert.equal(P.slotX(42, 10, travel, 1920), travel);
});

test('single slot and no travel', () => {
    assert.equal(P.slotX(0, 1, 1000, 1920), 500);
    assert.equal(P.slotX(3, 5, 0, 1920), 0);
});

test('slot by id (hyprland, mango)', () => {
    assert.deepEqual({ ...P.slot(false, { activeWorkspace: { id: 4 } }, [], 10) }, { index: 3, count: 10 });
    assert.deepEqual({ ...P.slot(false, { activeWorkspace: { id: 12 } }, [], 10) }, { index: 11, count: 12 });
    assert.deepEqual({ ...P.slot(false, null, [], 0) }, { index: 0, count: 1 });
});

test('slot by position on the monitor (niri)', () => {
    const ws = [
        { id: 7, monitor: 'DP-1' },
        { id: 3, monitor: 'HDMI-A-1' },
        { id: 9, monitor: 'DP-1' },
        { id: 2, monitor: 'DP-1' }
    ];
    assert.deepEqual({ ...P.slot(true, { name: 'DP-1', activeWorkspace: { id: 9 } }, ws, 10) }, { index: 1, count: 3 });
    assert.deepEqual({ ...P.slot(true, { name: 'HDMI-A-1', activeWorkspace: { id: 3 } }, ws, 10) }, { index: 0, count: 1 });
    assert.deepEqual({ ...P.slot(true, { name: 'X', activeWorkspace: { id: 1 } }, ws, 10) }, { index: 0, count: 1 });
});

test('near layers lead mid-pan and line up at rest', () => {
    for (const layer of [0, 1, 2]) {
        assert.equal(P.layerX(100, 2020, 0, layer), 100);
        assert.ok(Math.abs(P.layerX(100, 2020, 1, layer) - 2020) < 1e-9);
    }
    const base = P.layerX(0, 1920, 0.5, 0);
    assert.equal(base, 960);
    assert.ok(P.layerX(0, 1920, 0.5, 1) > base);
    assert.ok(P.layerX(0, 1920, 0.5, 2) > P.layerX(0, 1920, 0.5, 1));
    assert.ok(P.layerX(1920, 0, 0.5, 2) < 960);
    assert.equal(P.decodeSize(1440).height, 1440);
});

test('depth map lives next to the image', () => {
    assert.equal(P.depthMapPath('/w/a.b/scroll.jpg'), '/w/a.b/scroll.depth.png');
    assert.equal(P.depthMapPath('/w/a.b/noext'), '/w/a.b/noext.depth.png');
    assert.equal(P.depthMapPath(''), '');
});
