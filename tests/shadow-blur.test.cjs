const { test } = require('node:test');
const assert = require('node:assert/strict');
const path = require('node:path');
const { loadLibrary } = require('./lib/qmljs.cjs');
const B = loadLibrary(path.join(__dirname, '../modules/components/shape/ShadowBlur.js'));
const sum = (r) => r.w.reduce((a, b) => a + b, 0) + r.sharp;

test('blur 0 is the sharp shape only', () => {
    const r = B.weights(0);
    assert.deepEqual(Array.from(r.w), [0, 0, 0, 0]);
    assert.equal(r.sharp, 1);
    assert.equal(r.reach, 0);
});

test('weights always add up to one, at and between table steps', () => {
    for (let b = 0; b <= 1.0001; b += 0.013) {
        const r = B.weights(b);
        assert.ok(Math.abs(sum(r) - 1) < 1e-9, `blur ${b}`);
        for (const v of r.w) assert.ok(v >= 0, `blur ${b}`);
        assert.ok(r.sharp >= 0);
    }
});

test('between two steps the weights interpolate linearly', () => {
    const a = B.weights(0.5), c = B.weights(0.55), m = B.weights(0.525);
    for (let k = 0; k < 4; k++) assert.ok(Math.abs(m.w[k] - (a.w[k] + c.w[k]) / 2) < 1e-9);
});

test('more blur reaches further and keeps less of the sharp shape', () => {
    assert.ok(B.weights(1).reach > B.weights(0.5).reach);
    assert.ok(B.weights(0.5).reach > B.weights(0.1).reach);
    assert.ok(B.weights(1).sharp < B.weights(0.25).sharp);
    assert.equal(B.weights(1).reach, 48);
});

test('out-of-range and invalid blur clamp like MultiEffect', () => {
    assert.deepEqual(B.weights(3), B.weights(1));
    assert.deepEqual(B.weights(-1), B.weights(0));
    assert.deepEqual(B.weights(undefined), B.weights(0));
    assert.deepEqual(B.weights(NaN), B.weights(0));
});
