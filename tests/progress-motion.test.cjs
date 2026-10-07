const { test } = require('node:test');
const assert = require('node:assert/strict');
const path = require('node:path');
const { loadLibrary } = require('./lib/qmljs.cjs');

const P = loadLibrary(path.join(__dirname, '../modules/components/kit/ProgressMotion.js'));

test('a sweep lasts four emphasis tokens; no motion without the token', () => {
    assert.equal(P.cycle(450), 1800);
    assert.equal(P.cycle(0), 0);
    assert.equal(P.cycle(-1), 0);
});

test('the segment enters from the left edge and leaves at the right', () => {
    assert.deepEqual({ ...P.segment(0, 200, false) }, { x: 0, width: 0 });
    assert.deepEqual({ ...P.segment(1, 200, false) }, { x: 200, width: 0 });
    const mid = P.segment(0.5, 200, false);
    assert.ok(Math.abs(mid.width - 60) < 1e-9);
    assert.ok(Math.abs(mid.x - 70) < 1e-9);
});

test('the segment stays clipped to the track', () => {
    for (let t = 0; t <= 1; t += 0.05) {
        const s = P.segment(t, 120, false);
        assert.ok(s.x >= 0 && s.width >= 0 && s.x + s.width <= 120 + 1e-9, String(t));
    }
    assert.deepEqual({ ...P.segment(-3, 120, false) }, { x: 0, width: 0 });
});

test('without motion the segment rests centered', () => {
    assert.deepEqual({ ...P.segment(0.9, 200, true) }, { x: 70, width: 60 });
});
