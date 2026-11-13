const { test } = require('node:test');
const assert = require('node:assert/strict');
const path = require('node:path');

const qmljs = require('./lib/qmljs.cjs');
const lib = file => qmljs.loadLibrary(path.join(__dirname, '..', file));
const plain = v => JSON.parse(JSON.stringify(v));

const Shape = lib('modules/settings/thumbs/BarShape.js');
const Strip = lib('modules/settings/controls/Strip.js');
const Styles = lib('modules/bar/panels/PanelStyles.js');

const L = 160;
const t = 33;

test('every panel style has a silhouette across the picture', () => {
    for (const s of Styles.STYLES) {
        const sk = plain(Shape.shape(s.id, L, t));
        assert.ok(sk.shapes.length > 0, s.id);
        for (const p of sk.shapes) {
            assert.ok(p.w > 0 && p.h > 0, s.id);
            // within a third of the picture height of the edge
            assert.ok(p.y + p.h <= t + 1, `${s.id} thicker than t`);
        }
    }
});

test('styles differ by outline', () => {
    const outline = id => JSON.stringify(plain(Shape.shape(id, L, t)).shapes);
    const ids = Styles.BAR_STYLES;
    assert.equal(new Set(ids.map(outline)).size, ids.length);
    // classic touches both ends and the edge; floating does not
    const classic = plain(Shape.shape('classic', L, t)).shapes[0];
    assert.deepEqual([classic.x, classic.y, classic.w], [0, 0, L]);
    const floating = plain(Shape.shape('floating', L, t)).shapes[0];
    assert.ok(floating.x > 0 && floating.y > 0);
    assert.equal(plain(Shape.shape('islands', L, t)).shapes.length, 3);
    assert.equal(plain(Shape.shape('none', L, t)).shapes[0].kind, 'ghost');
});

test('marks stay inside their shape and drop when there is no room', () => {
    for (const id of Styles.BAR_STYLES) {
        const sk = plain(Shape.shape(id, L, t));
        for (const m of sk.marks) {
            assert.ok(m.x >= 0 && m.x + m.w <= L + 0.01, `${id} mark off the picture`);
            assert.ok(m.y >= 0 && m.y + m.h <= t, `${id} mark off the bar`);
        }
        assert.ok(sk.marks.length >= (id === 'none' ? 0 : 1) && sk.marks.length <= 6, id);
    }
    // a short side bar: words become dots, then marks drop
    assert.deepEqual(plain(Shape.fit(['word', 'word'], t * 0.7, t, 4)), ['dot', 'dot']);
    assert.deepEqual(plain(Shape.fit(['dot', 'dot', 'dot'], t * 0.3, t, 4)), ['dot']);
    assert.deepEqual(plain(Shape.fit(['dot'], 1, t, 4)), []);
});

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
