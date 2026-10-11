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

test('hiddenBy counts entries and sections the gate hides, not visibleWhen', () => {
    const sections = [
        { id: 'a', entries: [
            { key: 'x', compositor: ['hyprland', 'mango'] },
            { key: 'y' },
            { key: 'z', compositor: 'hyprland', visibleWhen: { key: 'k', equals: true } },
            { key: 'v', visibleWhen: { key: 'k', equals: true } }
        ] },
        { id: 'b', compositor: 'hyprland', entries: [{ key: 'p' }, { key: 'q' }] },
        { id: 'c', entries: [{ key: 'n', compositor: 'niri' }] }
    ];
    const r = JSON.parse(JSON.stringify(G.hiddenBy(sections, 'niri')));
    assert.deepEqual(r, { count: 4, compositors: ['hyprland', 'mango'] });
    assert.deepEqual(JSON.parse(JSON.stringify(G.hiddenBy(sections, 'hyprland'))), { count: 1, compositors: ['niri'] });
    assert.equal(G.hiddenBy(sections, 'mango').count, 3);
});

test('hiddenBy is silent when nothing is gated or the compositor is unknown', () => {
    const plain = [{ id: 'a', entries: [{ key: 'x' }, { key: 'y', compositor: ['hyprland', 'mango'] }] }];
    assert.equal(G.hiddenBy(plain, 'hyprland').count, 0);
    assert.equal(G.hiddenBy(plain, 'mango').count, 0);
    assert.equal(G.hiddenBy(plain, '').count, 0);
    assert.equal(G.hiddenBy(undefined, 'niri').count, 0);
});

test('describe names compositors', () => {
    assert.equal(G.describe(['hyprland', 'mango']), 'Hyprland, MangoWC');
    assert.equal(G.describe(['niri', 'other']), 'niri, other');
});
