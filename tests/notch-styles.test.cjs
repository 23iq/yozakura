const { test } = require('node:test');
const assert = require('node:assert/strict');
const path = require('node:path');
const { loadLibrary } = require('./lib/qmljs.cjs');
const S = loadLibrary(path.join(__dirname, '../modules/notch/styles/NotchStyles.js'));

test('every notch.style option has a spec; unknown falls back to attached', () => {
    const meta = loadLibrary(path.join(__dirname, '../config/meta/Enums.js'));
    for (const id of meta.NOTCH_STYLES) assert.equal(S.spec(id).id, id);
    assert.equal(S.spec('nope').id, 'attached');
    assert.equal(S.spec(undefined).id, 'attached');
});
test('only attached has screen corners and no gap; legacy theme names', () => {
    assert.equal(S.spec('attached').corners, true);
    assert.equal(S.spec('island').corners, false);
    assert.equal(S.spec('pill').corners, false);
    assert.equal(S.spec('attached').gap, 0);
    assert.ok(S.spec('pill').gap > 0);
    assert.equal(S.legacyTheme('attached'), 'default');
    assert.equal(S.legacyTheme('island'), 'island');
    assert.equal(S.legacyTheme('pill'), 'island');
});
test('pill collapses only when idle; other styles never do', () => {
    const pill = S.spec('pill');
    assert.equal(S.collapsed(pill, {}), true);
    for (const k of ['hovered', 'open', 'expanded', 'notifications', 'activities'])
        assert.equal(S.collapsed(pill, { [k]: true }), false, k);
    assert.equal(S.collapsed(S.spec('island'), {}), false);
    assert.equal(S.collapsed(S.spec('attached'), {}), false);
    assert.equal(S.collapsed(null, {}), false);
});
test('the capsule is one unit high and four wide, never degenerate', () => {
    assert.deepEqual(JSON.parse(JSON.stringify(S.capsule(8))), { w: 32, h: 8 });
    assert.deepEqual(JSON.parse(JSON.stringify(S.capsule(0))), { w: 16, h: 4 });
});

test('the capsule lies along a side edge', () => {
    const h = S.capsule(8), v = S.capsule(8, true);
    assert.deepEqual(JSON.parse(JSON.stringify(v)), { w: h.h, h: h.w });
});
