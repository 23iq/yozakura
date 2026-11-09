const test = require('node:test');
const assert = require('node:assert');
const fs = require('node:fs');
const path = require('node:path');

const src = fs.readFileSync(path.join(__dirname, '..', 'modules/notch/NotchSilhouette.qml'), 'utf8');

// The attached surface is a rounded body plus two cornerSize concave pieces.
// Its StyledRects never take a corner style: one would mask them through a
// layer.effect (CornerMask) whose texture follows the morph every frame.
test('attached notch pieces never take a corner style (no morph-sized layer)', () => {
    const attached = src.slice(src.indexOf('// ── attached'), src.indexOf('// ── island'));
    const rects = attached.split('StyledRect {').slice(1);
    assert.ok(rects.length >= 2, 'body and concave-corner fill');
    for (const r of rects)
        assert.match(r.slice(0, r.indexOf('}')), /cornerStyled: false/);
});

test('no layer on the attached surface follows the silhouette size', () => {
    assert.doesNotMatch(src, /layer\.enabled: root\.attached/);
    // The only layers are the concave pieces and their masks (cornerSize)
    const layered = src.match(/layer\.enabled: true/g) || [];
    assert.strictEqual(layered.length, 2);
});
