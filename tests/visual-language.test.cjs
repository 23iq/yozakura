const { test } = require('node:test');
const assert = require('node:assert/strict');
const path = require('node:path');
const { loadLibrary } = require('./lib/qmljs.cjs');

const V = loadLibrary(path.join(__dirname, '../modules/theme/VisualLanguage.js'));
const plain = v => JSON.parse(JSON.stringify(v));
const pane = { gradient: [['surface', 0]], border: ['surfaceBright', 2], itemColor: 'overBackground', opacity: 1 };
const primary = { gradient: [['primary', 0]], border: ['primary', 0], itemColor: 'overPrimary', opacity: 1 };

test('unknown languages fall back to ink', () => {
    assert.equal(V.normalize('chrome'), 'ink');
    assert.equal(V.normalize('tiles'), 'tiles');
});

test('ink hides inner boxes and ghost buttons', () => {
    for (const v of ['pane', 'internalbg', 'common']) {
        const out = plain(V.apply('ink', v, pane));
        assert.equal(out.opacity, 0, v);
        assert.equal(out.border[1], 0, v);
    }
});

test('ink turns accent fills into a soft tint with an accent glyph', () => {
    const out = plain(V.apply('ink', 'primary', primary));
    assert.ok(out.opacity > 0 && out.opacity < 0.3);
    assert.equal(out.itemColor, 'primary');
    assert.ok(plain(V.apply('ink', 'primaryfocus', primary)).opacity > out.opacity);
});

test('surfaces themselves are never changed', () => {
    for (const lang of V.LANGUAGES)
        for (const v of ['bg', 'popup', 'barbg', 'frame'])
            assert.equal(V.apply(lang, v, pane), pane, `${lang}/${v}`);
});

test('classic keeps every variant as configured', () => {
    for (const v of ['pane', 'common', 'primary'])
        assert.equal(V.apply('classic', v, pane), pane);
});

test('kit: ink has no group box, glass a translucent card, tiles a solid tile', () => {
    const ink = plain(V.kit('ink')), glass = plain(V.kit('glass')), tiles = plain(V.kit('tiles'));
    assert.equal(ink.group.fillOpacity, 0);
    assert.equal(ink.group.radius, 'none');
    assert.ok(ink.group.divider && ink.dividers);
    assert.ok(glass.group.fillOpacity >= 0.35 && glass.group.fillOpacity <= 0.45);
    assert.ok(glass.group.outline > 0 && glass.group.highlight > 0);
    assert.equal(glass.group.radius, 'card');
    assert.equal(tiles.group.fill, 'surfaceContainer');
    assert.equal(tiles.group.fillOpacity, 1);
    assert.equal(tiles.group.outline, 0);
    assert.equal(tiles.dividers, false);
    assert.equal(tiles.group.radius, 'small');
});

test('kit: controls are ghosts in ink, translucent in glass, solid in tiles', () => {
    const ink = V.kit('ink').control, glass = V.kit('glass').control, tiles = V.kit('tiles').control;
    assert.equal(ink.rest, 0);
    assert.equal(ink.edge, 0);
    assert.ok(glass.rest > 0 && glass.rest < 0.2 && glass.edge > 0);
    assert.equal(tiles.fill, 'surfaceContainerHigh');
    assert.equal(tiles.rest, 1);
    assert.equal(tiles.shape, 'square');
    assert.ok(tiles.weight > ink.weight);
    assert.ok(tiles.solidActive && !ink.solidActive && !glass.solidActive);
    assert.equal(V.kit('classic').control, null);
    assert.equal(V.kit('chrome'), V.kit('ink'));
});

test('apply never mutates the theme config', () => {
    const before = plain(pane);
    V.apply('ink', 'pane', pane);
    V.apply('glass', 'common', pane);
    V.apply('tiles', 'internalbg', pane);
    assert.deepEqual(plain(pane), before);
});
