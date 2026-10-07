const { test } = require('node:test');
const assert = require('node:assert/strict');
const path = require('node:path');
const { loadLibrary } = require('./lib/qmljs.cjs');

const K = loadLibrary(path.join(__dirname, '../modules/components/kit/KitStates.js'));

test('primary wins over active, active over hover', () => {
    assert.equal(K.look(true, true, true), 'primary');
    assert.equal(K.look(false, true, true), 'active');
    assert.equal(K.look(false, false, true), 'hover');
    assert.equal(K.look(false, false, false), 'normal');
});

test('variants: accent looks share the primary variant, rest is per control', () => {
    assert.equal(K.variant('primary', 'common'), 'primary');
    assert.equal(K.variant('active', 'transparent'), 'primary');
    assert.equal(K.variant('hover', 'transparent'), 'focus');
    assert.equal(K.variant('normal', 'transparent'), 'transparent');
    assert.equal(K.variant('normal'), 'common');
});

test('active is a tint, primary a fill, the rest keep the variant opacity', () => {
    assert.equal(K.opacity('active', false), K.TINT);
    assert.ok(K.opacity('active', true) > K.TINT);
    assert.equal(K.opacity('primary', false), 1);
    assert.ok(K.opacity('primary', true) < 1);
    assert.equal(K.opacity('hover', true), -1);
    assert.equal(K.opacity('normal', false), -1);
});

test('glyph ink follows the look', () => {
    assert.equal(K.ink('primary'), 'accentInk');
    assert.equal(K.ink('active'), 'accent');
    assert.equal(K.ink('hover'), 'text');
});
