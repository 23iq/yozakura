// Music-reactive active border (modules/services/BorderPulse.js).
const { test } = require('node:test');
const assert = require('node:assert/strict');
const path = require('node:path');
const { loadLibrary } = require('./lib/qmljs.cjs');

const P = loadLibrary(path.join(__dirname, '..', 'modules/services/BorderPulse.js'));
const plain = v => JSON.parse(JSON.stringify(v));

test('energy is bass weighted and bounded', () => {
    assert.equal(P.energy([]), 0);
    assert.equal(P.energy(null), 0);
    const bass = P.energy([1, 1, 1, 0, 0, 0, 0, 0, 0, 0, 0, 0]);
    const treble = P.energy([0, 0, 0, 0, 0, 0, 0, 0, 0, 1, 1, 1]);
    assert.ok(bass > treble * 5, `${bass} vs ${treble}`);
    assert.equal(P.energy(new Array(24).fill(1)), 1);
    assert.equal(P.energy([2, -1, 'x']) <= 1, true);
});

test('follower attacks fast and releases slowly; levels are quantized', () => {
    const up = P.follow(0, 1, 0.55, 0.12);
    const down = P.follow(1, 0, 0.55, 0.12);
    assert.ok(up > 1 - down);
    assert.equal(P.quantize(0.54, 10), 5);
    assert.equal(P.quantize(2, 10), 10);
    assert.equal(P.quantize(-1, 10), 0);
});

test('silence dims, a beat restores, intensity 0 is a no-op', () => {
    assert.equal(P.factor(1, 1), 1);
    assert.equal(P.factor(0, 0), 1);
    assert.ok(Math.abs(P.factor(0, 1) - 0.15) < 1e-9);
});

test('frames scale border gradients and the shadow alpha only', () => {
    const base = { border: { colors: ['rgb(ff0000)', 'rgba(00ff0080)'], angle: 45 }, shadow: 'rgba(00000066)' };
    const full = plain(P.frame(base, 1, 0.6));
    assert.deepEqual(full, { general: { col: { active_border: { colors: ['rgb(ff0000)', 'rgba(00ff0080)'], angle: 45 } } }, decoration: { shadow: { color: 'rgba(00000066)' } } });
    const dim = plain(P.frame(base, 0, 1));
    assert.deepEqual(dim.general.col.active_border.colors, ['rgba(ff000026)', 'rgba(00ff0013)']);
    assert.equal(dim.decoration.shadow.color, 'rgba(0000000f)');
    // No shadow when shadows are off; never touches border_size.
    const noShadow = plain(P.frame({ border: 'rgb(112233)', shadow: '' }, 0.5, 0.5));
    assert.equal(noShadow.decoration, undefined);
    assert.equal(noShadow.general.border_size, undefined);
    assert.equal(P.scaleColor('nonsense', 0.5), 'nonsense');
});

test('frame Lua is a single hl.config call without semicolons', () => {
    const lua = P.frameLua({ border: 'rgb(112233)', shadow: '' }, 0.3, 0.6);
    assert.match(lua, /^hl\.config\(\{general = \{col = \{active_border = "rgba\(112233[0-9a-f]{2}\)"\}\}\}\)$/);
    assert.ok(!lua.includes(';'));
});
