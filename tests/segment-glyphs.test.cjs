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

test('segments are pointed hexagons inside the cell that never touch', () => {
    for (const [w, h, t] of [[23, 40, 5.2], [10, 18, 2.3]]) {
        const polys = [0, 1, 2, 3, 4, 5, 6].map(i => plain(G.polygon(i, w, h, t)));
        for (const p of polys) {
            assert.equal(p.length, 6);
            for (const [x, y] of p)
                assert.ok(x >= -1e-9 && y >= -1e-9 && x <= w + 1e-9 && y <= h + 1e-9, JSON.stringify(p));
        }
        // Every vertex of one segment stays a gap away from every vertex of another.
        for (let i = 0; i < 7; i++)
            for (let j = i + 1; j < 7; j++)
                for (const [ax, ay] of polys[i])
                    for (const [bx, by] of polys[j])
                        assert.ok(Math.hypot(ax - bx, ay - by) > 0.5, `${G.SEGMENTS[i]} / ${G.SEGMENTS[j]} at ${w}x${h}`);
    }
});
