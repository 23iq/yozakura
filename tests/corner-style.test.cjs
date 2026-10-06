const { test } = require('node:test');
const assert = require('node:assert/strict');
const path = require('node:path');
const { loadLibrary } = require('./lib/qmljs.cjs');
const C = loadLibrary(path.join(__dirname, '../modules/components/shape/CornerStyle.js'));

const plain = (o) => JSON.parse(JSON.stringify(o));
const shape = (corners, popupCorners, cutSize) => ({ corners, popupCorners: popupCorners ?? '', cutSize: cutSize ?? 10 });

test('round everywhere by default, all corners styled, no mask', () => {
    const r = C.resolve({ radius: 16 }, shape('round'), false, '');
    assert.deepEqual(plain(r), { style: 'round', radius: 16, cut: 10, corners: [true, true, true, true] });
    assert.equal(C.needsMask(r), false);
});

test('missing or corrupt inputs fall back to round', () => {
    for (const s of [null, undefined, {}, shape('blob'), shape(42), shape('')]) {
        const r = C.resolve(null, s, false, '');
        assert.equal(r.style, 'round');
        assert.equal(C.needsMask(r), false);
        assert.equal(r.cut, s && s.cutSize === 10 ? 10 : C.DEFAULT_CUT);
    }
});

test('variant cornerStyle overrides the theme, unknown variant style inherits', () => {
    assert.equal(C.resolve({ cornerStyle: 'cut' }, shape('squircle'), false, '').style, 'cut');
    assert.equal(C.resolve({ cornerStyle: 'nope' }, shape('squircle'), false, '').style, 'squircle');
    assert.equal(C.resolve({ cornerStyle: '' }, shape('squircle'), false, '').style, 'squircle');
});

test('popupCorners overrides popups only; empty or invalid inherits', () => {
    assert.equal(C.resolve({}, shape('round', 'cut'), true, '').style, 'cut');
    assert.equal(C.resolve({}, shape('round', 'cut'), false, '').style, 'round');
    assert.equal(C.resolve({}, shape('squircle', ''), true, '').style, 'squircle');
    assert.equal(C.resolve({}, shape('squircle', 'bogus'), true, '').style, 'squircle');
    // a variant's own style wins over popupCorners
    assert.equal(C.resolve({ cornerStyle: 'round' }, shape('round', 'cut'), true, '').style, 'round');
});

test('squircle and cut need the mask', () => {
    assert.equal(C.needsMask(C.resolve({}, shape('squircle'), false, '')), true);
    assert.equal(C.needsMask(C.resolve({}, shape('cut'), false, '')), true);
});

test('tab squares the corners on the anchor edge', () => {
    const at = (edge) => plain(C.resolve({}, shape('tab'), true, edge).corners);
    assert.deepEqual(at('top'), [false, false, true, true]);
    assert.deepEqual(at('bottom'), [true, true, false, false]);
    assert.deepEqual(at('left'), [false, true, true, false]);
    assert.deepEqual(at('right'), [true, false, false, true]);
    const t = C.resolve({}, shape('tab'), true, 'top');
    assert.equal(t.style, 'tab');
    assert.equal(C.needsMask(t), true);
    assert.equal(C.shaderStyle(t.style), C.shaderStyle('round'));
});

test('tab without an anchor edge renders as plain round (no mask)', () => {
    const t = C.resolve({}, shape('tab'), false, '');
    assert.deepEqual(plain(t.corners), [true, true, true, true]);
    assert.equal(C.needsMask(t), false);
    assert.equal(C.needsMask(C.resolve({}, shape('tab'), true, 'diagonal')), false);
});

test('cut size is clamped to a sane range', () => {
    assert.equal(C.resolve({}, shape('cut', '', 0), false, '').cut, C.MIN_CUT);
    assert.equal(C.resolve({}, shape('cut', '', 999), false, '').cut, C.MAX_CUT);
    assert.equal(C.resolve({}, shape('cut', '', 'x'), false, '').cut, C.DEFAULT_CUT);
});

test('shader style ids are stable and unknown maps to round', () => {
    assert.equal(C.shaderStyle('round'), 0);
    assert.equal(C.shaderStyle('squircle'), 1);
    assert.equal(C.shaderStyle('cut'), 2);
    assert.equal(C.shaderStyle('whatever'), 0);
});

test('corner radii: square corners are 0, others keep their radius', () => {
    const t = C.resolve({}, shape('tab'), true, 'top');
    assert.deepEqual(plain(C.radii(t, [12, 12, 12, 12])), [0, 0, 12, 12]);
    const r = C.resolve({}, shape('cut'), false, '');
    assert.deepEqual(plain(C.radii(r, [4, 8, 0, 16])), [4, 8, 0, 16]);
    assert.deepEqual(plain(C.radii(r, [-1, NaN, undefined, 3])), [0, 0, 0, 3]);
});

test('every listed style resolves to itself', () => {
    for (const s of C.STYLES)
        assert.equal(C.resolve({}, shape(s), false, 'top').style, s);
});
