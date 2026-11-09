const { test } = require('node:test');
const assert = require('node:assert/strict');
const path = require('node:path');
const { loadLibrary } = require('./lib/qmljs.cjs');
const F = loadLibrary(path.join(__dirname, '../modules/shell/FrameShadow.js'));

const hole = { x: 6, y: 40, w: 1908, h: 1034 };

test('a frame on every side keeps its hole', () => {
    const r = F.openHole(hole, { left: 6, top: 40, right: 6, bottom: 6 }, 3000);
    assert.deepEqual({ ...r }, hole);
});

test('a side of thickness 0 opens the hole past that screen edge', () => {
    const r = F.openHole({ x: 0, y: 40, w: 1920, h: 1040 }, { left: 0, top: 40, right: 0, bottom: 0 }, 3000);
    assert.deepEqual({ ...r }, { x: -3000, y: 40, w: 7920, h: 4040 });
});

test('fullscreen (no side at all): the hole covers far beyond the screen', () => {
    const r = F.openHole({ x: 0, y: 0, w: 1920, h: 1080 }, { left: 0, top: 0, right: 0, bottom: 0 }, 3000);
    assert.ok(r.x <= -3000 && r.y <= -3000);
    assert.ok(r.x + r.w >= 4920 && r.y + r.h >= 4080);
});
