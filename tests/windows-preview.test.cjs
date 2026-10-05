// Windows page preview geometry/colors (modules/settings/previews/WindowsPreviewModel.js).
const { test } = require('node:test');
const assert = require('node:assert/strict');
const path = require('node:path');
const { loadLibrary } = require('./lib/qmljs.cjs');

const M = loadLibrary(path.join(__dirname, '..', 'modules/settings/previews/WindowsPreviewModel.js'));
const plain = v => JSON.parse(JSON.stringify(v));

test('Hyprland colors become Qt #aarrggbb', () => {
    assert.equal(M.qtColor('rgb(feb0d1)'), '#fffeb0d1');
    assert.equal(M.qtColor('rgba(00000066)'), '#66000000');
    assert.equal(M.qtColor('bogus'), '#00000000');
    assert.deepEqual(plain(M.border({ colors: ['rgb(ff0000)', 'rgba(00ff0080)'], angle: 45 })), { colors: ['#ffff0000', '#8000ff00'], angle: 45 });
    assert.deepEqual(plain(M.border('rgb(010203)')), { colors: ['#ff010203'], angle: 0 });
});

test('tiles honour gaps_out at the edges and 2 x gaps_in between', () => {
    const [a, b] = M.tiles(1000, 400, 6, 12);
    assert.equal(a.x, 12);
    assert.equal(a.y, 12);
    assert.equal(b.x - (a.x + a.w), 12);
    assert.equal(1000 - (b.x + b.w), 12);
    assert.equal(a.h, 376);
    assert.deepEqual(plain(M.single(1000, 400, 0)), { x: 0, y: 0, w: 1000, h: 400 });
});

test('gradient line, offsets and blur amount', () => {
    const l = M.gradientLine(0, 100, 50);
    assert.deepEqual(plain(l), { x1: 0, y1: 25, x2: 100, y2: 25 });
    const d = M.gradientLine(90, 100, 50);
    assert.ok(Math.abs(d.x1 - 50) < 1e-9 && Math.abs(d.y1) < 1e-9 && Math.abs(d.y2 - 50) < 1e-9);
    assert.deepEqual(plain(M.offset('3 -4')), { x: 3, y: -4 });
    assert.deepEqual(plain(M.offset('x')), { x: 0, y: 0 });
    assert.equal(M.blurAmount({ enabled: false, size: 8, passes: 3 }), 0);
    assert.ok(M.blurAmount({ enabled: true, size: 8, passes: 3 }) > 0.4);
});
