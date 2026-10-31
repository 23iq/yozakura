const { test } = require('node:test');
const assert = require('node:assert/strict');
const path = require('node:path');
const { loadLibrary } = require('./lib/qmljs.cjs');

const G = loadLibrary(path.join(__dirname, '../modules/components/kit/SegmentGlyphs.js'));
const plain = v => JSON.parse(JSON.stringify(v));

test('digits light the classic seven-segment patterns', () => {
    assert.deepEqual(plain(G.mask('8')), [true, true, true, true, true, true, true]);
    assert.deepEqual(plain(G.mask('1')), [false, true, true, false, false, false, false]);
    assert.equal(G.lit('7'), 'abc');
    assert.equal(G.lit('-'), 'g');
});

test('letters are case-insensitive; unknown characters light nothing', () => {
    assert.equal(G.lit('f'), G.lit('F'));
    assert.equal(G.lit(' '), '');
    assert.equal(G.lit('%'), '');
    assert.deepEqual(plain(G.mask('?')), [false, false, false, false, false, false, false]);
});

test('colon and dot are separators', () => {
    assert.ok(G.isSeparator(':') && G.isSeparator('.'));
    assert.ok(!G.isSeparator('0') && !G.isSeparator(' '));
});

test('segments stay inside the cell and never overlap', () => {
    const w = 22, h = 40, t = 5;
    const boxes = [0, 1, 2, 3, 4, 5, 6].map(i => G.segment(i, w, h, t));
    for (const b of boxes) {
        assert.ok(b.x >= 0 && b.y >= 0 && b.x + b.w <= w + 1e-9 && b.y + b.h <= h + 1e-9, JSON.stringify(b));
        assert.ok(b.w > 0 && b.h > 0);
    }
    for (let i = 0; i < 7; i++)
        for (let j = i + 1; j < 7; j++) {
            const a = boxes[i], b = boxes[j];
            const overlap = a.x < b.x + b.w && b.x < a.x + a.w && a.y < b.y + b.h && b.y < a.y + a.h;
            assert.ok(!overlap, `${G.SEGMENTS[i]} / ${G.SEGMENTS[j]}`);
        }
});
