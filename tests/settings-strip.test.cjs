const { test } = require('node:test');
const assert = require('node:assert/strict');
const path = require('node:path');

const qmljs = require('./lib/qmljs.cjs');
const lib = file => qmljs.loadLibrary(path.join(__dirname, '..', file));

const Strip = lib('modules/settings/controls/Strip.js');

test('landscape strip: three whole pictures and a peek, capped by height', () => {
    const w = Strip.landscapeWidth(450, 150, 6, 8, 24, 96);
    assert.ok(Math.abs((450 - 16) - (3.4 * w + 3 * 8)) < 0.01);
    // a short card: the height decides, never under the minimum
    const short = Strip.landscapeWidth(450, 80, 6, 8, 24, 96);
    assert.equal(short, 96);
    assert.ok(Math.abs(Strip.landscapeWidth(450, 110, 6, 8, 24, 96) - (110 - 16 - 24) * 1.6) < 1e-9);
    // all fit
    const all = Strip.landscapeWidth(2000, 150, 4, 8, 24, 96);
    assert.ok(Math.abs(all - (150 - 16 - 24) * 1.6) < 1e-9);
});

test('revealX scrolls the least to show a picture whole', () => {
    // view 300, pictures 100 + gap 10: picture 0 at 10..110
    assert.equal(Strip.revealX(0, 300, 670, 1, 100, 10), 0);
    assert.equal(Strip.revealX(0, 300, 670, 4, 100, 10), 450 + 100 + 10 - 300);
    assert.equal(Strip.revealX(300, 300, 670, 0, 100, 10), 0);
    assert.equal(Strip.revealX(120, 300, 670, -1, 100, 10), 120);
    assert.equal(Strip.revealX(0, 300, 670, 5, 100, 10), 370);
});
