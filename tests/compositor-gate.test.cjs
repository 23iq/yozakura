// Which compositors a settings entry / section is shown on
// (modules/settings/CompositorGate.js).
const { test } = require('node:test');
const assert = require('node:assert/strict');
const path = require('node:path');
const { loadLibrary } = require('./lib/qmljs.cjs');

const G = loadLibrary(path.join(__dirname, '..', 'modules/settings/CompositorGate.js'));

test('no spec: every compositor', () => {
    assert.equal(G.allows(undefined, 'niri'), true);
    assert.equal(G.allows([], 'niri'), true);
});

test('single name is strict', () => {
    assert.equal(G.allows('hyprland', 'hyprland'), true);
    assert.equal(G.allows('hyprland', 'niri'), false);
    assert.equal(G.allows('hyprland', ''), false);
});

test('list matches any member and shows while the name is unknown', () => {
    assert.equal(G.allows(['hyprland', 'mango'], 'mango'), true);
    assert.equal(G.allows(['hyprland', 'mango'], 'niri'), false);
    assert.equal(G.allows(['hyprland', 'mango'], ''), true);
});
