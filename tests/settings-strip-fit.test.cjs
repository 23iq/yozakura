// The card width of the terminal picture strips (modules/settings/editors/
// StripFit.js): a strip that runs on cuts its last card about in half.
const { test } = require('node:test');
const assert = require('node:assert/strict');
const path = require('node:path');
const { loadLibrary } = require('./lib/qmljs.cjs');

const S = loadLibrary(path.join(__dirname, '..', 'modules/settings/editors/StripFit.js'));

// the share of the last card the edge shows
function lastShown(room, inset, gap, w) {
    const start = room - inset;
    const slot = w + gap;
    const k = Math.floor(start / slot);
    return (start - k * slot) / w;
}

test('a strip that fits keeps its natural cards', () => {
    assert.equal(S.cardWidth(1000, 12, 12, 200, 3), 200);
});

test('a strip that runs on shows about half of its last card', () => {
    for (const room of [300, 420, 470, 520, 640, 800]) {
        const w = S.cardWidth(room, 12, 12, 210, 8);
        assert.ok(w >= 210 * 0.7 && w <= 210 * 1.3, `room ${room}: width ${w} within the give`);
        const part = lastShown(room, 12, 12, w);
        assert.ok(part > 0.35 && part < 0.65, `room ${room}: the last card shows ${part.toFixed(2)}`);
    }
});

test('nothing to fit: the natural width', () => {
    assert.equal(S.cardWidth(0, 12, 12, 200, 5), 200);
    assert.equal(S.cardWidth(500, 12, 12, 200, 0), 200);
});
