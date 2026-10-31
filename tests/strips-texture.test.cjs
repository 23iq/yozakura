const { test } = require('node:test');
const assert = require('node:assert/strict');
const path = require('node:path');
const { loadLibrary } = require('./lib/qmljs.cjs');
const T = loadLibrary(path.join(__dirname, '../modules/notifications/strips/StripTexture.js'));

test('plain has no texture, junk materials neither', () => {
    assert.equal(T.strokes('plain', 1, 40, 160).length, 0);
    assert.equal(T.strokes('marble', 1, 40, 160).length, 0);
    assert.equal(T.strokes('paper', 1, 0, 160).length, 0);
});

test('same seed, same texture; another seed, another one', () => {
    const a = JSON.stringify(T.strokes('paper', 42, 40, 160));
    assert.equal(a, JSON.stringify(T.strokes('paper', 42, 40, 160)));
    assert.notEqual(a, JSON.stringify(T.strokes('paper', 43, 40, 160)));
});

test('strokes stay subtle and name palette roles, never colours', () => {
    for (const m of ['paper', 'washi']) {
        const s = T.strokes(m, 7, 40, 160);
        assert.ok(s.length > 3, m);
        s.forEach(k => {
            assert.ok(k.alpha > 0 && k.alpha <= 0.12, m + ' alpha ' + k.alpha);
            assert.ok(k.tint === 'ink' || k.tint === 'accent');
        });
    }
    assert.ok(T.strokes('washi', 7, 40, 160).some(k => k.kind === 'cloud'));
    assert.ok(!T.strokes('paper', 7, 40, 160).some(k => k.kind === 'cloud'));
});

test('washi fibres run along the strip', () => {
    const s = T.strokes('washi', 3, 40, 200).filter(k => k.kind === 'fibre');
    const vertical = s.filter(k => Math.abs(k.y2 - k.y1) > Math.abs(k.x2 - k.x1)).length;
    assert.ok(vertical > s.length * 0.7);
});

test('texture is bounded for big cards', () => {
    assert.ok(T.strokes('paper', 1, 2000, 2000).length <= 400);
});
