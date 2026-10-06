const { test } = require('node:test');
const assert = require('node:assert/strict');
const path = require('node:path');

const qmljs = require('./lib/qmljs.cjs');
const loadLibrary = file => qmljs.loadLibrary(path.join(__dirname, file));

const layoutLib = loadLibrary('../modules/bar/BarLayout.js');
// Re-create in this realm so deepStrictEqual compares plain arrays
const barDefaults = JSON.parse(JSON.stringify(loadLibrary('../config/defaults/bar.js').data));
const validator = loadLibrary('../config/ConfigValidator.js');
const plain = value => JSON.parse(JSON.stringify(value));
const normalize = raw => plain(layoutLib.normalize(raw, barDefaults.layout));

test('defaults in bar.js and BarLayout.js stay identical', () => {
    assert.deepEqual(plain(layoutLib.DEFAULT_LAYOUT), plain(barDefaults.layout));
    assert.equal(barDefaults.clockShowDate, false);
});

test('missing layout reproduces the historical bar', () => {
    const result = normalize(undefined);
    assert.deepEqual(result.warnings, []);
    assert.equal(result.style, 'classic');
    assert.deepEqual(result.left, ['launcher', 'workspaces', 'layoutSelector', 'pin']);
    assert.deepEqual(result.right, ['presets', 'tools', 'systray', 'keyboardLayout', 'controls', 'battery', 'clock', 'power']);
    assert.deepEqual(result.drawer, []);
});

test('unknown ids are skipped with a warning, never thrown', () => {
    const result = normalize({ style: 'islands', left: ['launcher', 'bogus', 42, null], right: ['clock'], drawer: ['nope', 'power'] });
    assert.deepEqual(result.left, ['launcher']);
    assert.deepEqual(result.right, ['clock']);
    assert.deepEqual(result.drawer, ['power']);
    assert.equal(result.warnings.length, 4);
    assert.match(result.warnings[0], /bogus/);
});

test('array-likes from JsonAdapter (QVariantList) are accepted', () => {
    const listLike = items => { const o = { length: items.length }; items.forEach((v, i) => { o[i] = v; }); return o; };
    const result = normalize({ style: 'islands', left: listLike(['launcher', 'workspaces']), right: listLike(['clock']), drawer: listLike(['systray', 'power']) });
    assert.deepEqual(result.warnings, []);
    assert.deepEqual(result.left, ['launcher', 'workspaces']);
    assert.deepEqual(result.right, ['clock']);
    assert.deepEqual(result.drawer, ['systray', 'power']);
});

test('duplicates keep the first occurrence across groups', () => {
    const result = normalize({ left: ['clock', 'clock'], right: ['clock', 'power'], drawer: ['power'] });
    assert.deepEqual(result.left, ['clock']);
    assert.deepEqual(result.right, ['power']);
    assert.deepEqual(result.drawer, []);
    assert.equal(result.warnings.length, 3);
});

test('invalid style and wrong types fall back per field', () => {
    const result = normalize({ style: 'floating', left: 'launcher', right: [] });
    assert.equal(result.style, 'classic');
    assert.deepEqual(result.left, barDefaults.layout.left);
    assert.deepEqual(result.right, []);
    assert.equal(result.warnings.length, 2);
    assert.deepEqual(normalize([1, 2]).left, barDefaults.layout.left);
    assert.deepEqual(normalize('islands').right, barDefaults.layout.right);
});

test('vertical keeps the legacy three-group arrangement only for the default layout', () => {
    const legacy = plain(layoutLib.resolveGroups(normalize(undefined), 'vertical', barDefaults.layout));
    assert.deepEqual(legacy.start, ['launcher', 'systray', 'tools', 'presets']);
    assert.deepEqual(legacy.center, ['layoutSelector', 'workspaces', 'pin']);
    assert.deepEqual(legacy.end, ['keyboardLayout', 'controls', 'battery', 'clock', 'power']);

    const custom = plain(layoutLib.resolveGroups(normalize({ left: ['workspaces'], right: ['clock'], drawer: ['power'] }), 'vertical', barDefaults.layout));
    assert.deepEqual(custom, { start: ['workspaces'], center: [], end: ['clock'], drawer: ['power'] });

    const horizontal = plain(layoutLib.resolveGroups(normalize(undefined), 'horizontal', barDefaults.layout));
    assert.deepEqual(horizontal.start, barDefaults.layout.left);
    assert.deepEqual(horizontal.center, []);
});

test('pin visibility and pill radii follow the visible items', () => {
    assert.deepEqual(plain(layoutLib.visibleIds(['launcher', 'pin'], { showPinButton: false })), ['launcher']);
    assert.deepEqual(plain(layoutLib.visibleIds(['launcher', 'pin'], {})), ['launcher', 'pin']);
    assert.deepEqual(plain(layoutLib.edgeRadii(0, 3, 16, 8, false, false)), { start: 16, end: 8 });
    assert.deepEqual(plain(layoutLib.edgeRadii(2, 3, 16, 8, false, false)), { start: 8, end: 16 });
    assert.deepEqual(plain(layoutLib.edgeRadii(2, 3, 16, 8, false, true)), { start: 8, end: 8 });
    assert.deepEqual(plain(layoutLib.edgeRadii(0, 1, 16, 8, true, false)), { start: 8, end: 16 });
});

test('config validator keeps layout arrays and rejects unknown styles', () => {
    const merged = plain(validator.validate({ position: 'top', layout: { style: 'islands', left: ['clock'] } }, barDefaults));
    assert.equal(merged.layout.style, 'islands');
    assert.deepEqual(merged.layout.left, ['clock']);
    assert.deepEqual(merged.layout.right, barDefaults.layout.right);
    assert.deepEqual(merged.layout.drawer, []);
    const bad = plain(validator.validate({ layout: { style: 'wat' } }, barDefaults));
    assert.equal(bad.layout.style, 'classic');
});
