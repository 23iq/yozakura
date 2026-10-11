// Which surface-role fields the visual language / Glass override
// (modules/settings/editors/surfaces/RoleLocks.js).
const { test } = require('node:test');
const assert = require('node:assert/strict');
const path = require('node:path');
const { loadLibrary } = require('./lib/qmljs.cjs');

const L = loadLibrary(path.join(__dirname, '..', 'modules/settings/editors/surfaces/RoleLocks.js'));
const plain = v => JSON.parse(JSON.stringify(v));

test('ink forces containers: invisible, no border width', () => {
    const m = plain(L.locks('ink', true, 'srPane'));
    assert.equal(m.opacity.kind, 'forced');
    assert.equal(m.opacity.value, 0);
    assert.equal(m.borderWidth.value, 0);
    assert.equal(m.gradient, undefined);
    assert.equal(L.summary(m).language, 'ink');
});

test('ink rewrites the fill and content color of accent roles', () => {
    const m = plain(L.locks('ink', true, 'srPrimary'));
    assert.equal(m.gradient.kind, 'forced');
    assert.equal(m.itemColor.kind, 'forced');
    assert.equal(m.opacity.kind, 'forced');
});

test('ink caps the hover role instead of forcing it', () => {
    const m = plain(L.locks('ink', true, 'srFocus'));
    assert.equal(m.opacity.kind, 'capped');
    assert.equal(m.opacity.value, 0.55);
});

test('glass caps inner cards and forces a one pixel edge', () => {
    const m = plain(L.locks('glass', true, 'srInternalBg'));
    assert.equal(m.opacity.kind, 'capped');
    assert.equal(m.opacity.value, 0.35);
    assert.equal(m.borderWidth.value, 1);
});

test('classic and the surfaces themselves are never rewritten', () => {
    assert.deepEqual(plain(L.locks('classic', true, 'srPane')), {});
    assert.deepEqual(plain(L.locks('ink', true, 'srBg')), {});
});

test('glass off ignores the opacity of glass surfaces only', () => {
    assert.equal(L.locks('classic', false, 'srBg').opacity.kind, 'glass');
    assert.equal(L.summary(plain(L.locks('classic', false, 'srBg'))).glass, true);
    assert.equal(L.locks('classic', false, 'srFocus').opacity, undefined);
    // the language wins: an ink container is already invisible
    assert.equal(L.locks('ink', false, 'srPane').opacity.kind, 'forced');
});
