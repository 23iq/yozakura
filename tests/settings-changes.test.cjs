// The Changes page model (modules/settings/ChangesModel.js).
const { test } = require('node:test');
const assert = require('node:assert/strict');
const path = require('node:path');
const { loadLibrary } = require('./lib/qmljs.cjs');

const repo = path.join(__dirname, '..');
const lib = rel => loadLibrary(path.join(repo, rel));
const Changes = lib('modules/settings/ChangesModel.js');
const SchemaUtil = lib('modules/settings/SchemaUtil.js');
const Defaults = lib('modules/settings/SettingsDefaults.js');
const Categories = lib('modules/settings/schema/Categories.js');
const en = require('../translations/en.json');
const tr = k => en[k] || k;
const plain = v => JSON.parse(JSON.stringify(v));

// Pages in sidebar order (what the page passes).
const pages = Categories.groups.flatMap(g => g.categories).map(id => Categories.byId(id)).filter(Boolean);

function ctxOf(over, compositor = 'hyprland') {
    const get = k => (k in over ? over[k] : Defaults.get(k));
    const isModified = e => SchemaUtil.entryKeys(e).some(k => !SchemaUtil.equal(get(k), Defaults.get(k)));
    return { ctx: { compositor, get }, isModified };
}

test('nothing changed: no groups', () => {
    const { ctx, isModified } = ctxOf({});
    assert.deepEqual(plain(Changes.fromDefaults(pages, ctx, isModified, Defaults.get, tr)), []);
});

test('changed settings are grouped by page with now / default values', () => {
    const { ctx, isModified } = ctxOf({ 'workspaces.shown': 4, 'dock.position': 'left', 'bar.position': 'bottom', 'theme.roundness': 4 });
    const groups = Changes.fromDefaults(pages, ctx, isModified, Defaults.get, tr);
    const ids = groups.map(g => g.categoryId);
    assert.ok(ids.indexOf('bar') < ids.indexOf('dock'), ids.join());
    const shown = groups.find(g => g.categoryId === 'bar').rows.find(r => r.entryId === 'workspaces.shown');
    assert.equal(shown.now, '4');
    assert.equal(shown.label, tr('prefs.bar.ws_shown'));
    // theme.roundness is not a window row (the Roundness macro is): listed,
    // with nothing to open
    const round = groups.flatMap(g => g.rows).find(r => r.entryId === 'theme.roundness');
    assert.ok(round, 'an out-of-window setting that differs is listed');
    assert.equal(round.jump, false);
    assert.equal(shown.jump, true);
    const dock = groups.find(g => g.categoryId === 'dock').rows[0];
    assert.equal(dock.now, tr('common.left'));
    assert.equal(Changes.count(groups), 4);
});

test('hidden or other-compositor entries are not listed', () => {
    // compositor-only key on niri is skipped (as the page reset skips it)
    const { ctx, isModified } = ctxOf({ 'compositor.smartGaps': true }, 'niri');
    assert.equal(Changes.count(Changes.fromDefaults(pages, ctx, isModified, Defaults.get, tr)), 0);
});

test('since the preset: rows by page, unknown keys under Other, raw target kept', () => {
    const t = k => en[k] || k;
    const index = SchemaUtil.buildSearchIndex(Categories.categories, t);
    const groups = Changes.fromPreset([
        { key: 'workspaces.shown', a: 4, b: 10 },
        { key: 'theme.someUnknownThing', a: true, b: false },
        { key: 'dock.position', a: 'left', b: 'bottom' },
    ], index, pages, t);
    assert.deepEqual(plain(groups.map(g => g.categoryId)), ['bar', 'dock', '']);
    const r = groups[0].rows[0];
    assert.equal(r.target, 10);
    assert.equal(r.now, '4');
    assert.equal(groups[2].title, en['prefs.changes.other']);
    assert.equal(groups[2].rows[0].label, 'Theme · Some unknown thing');
    assert.equal(groups[1].rows[0].was, en['common.bottom']);
});

test('values of a custom editor (no options) read as words, not ids', () => {
    const t = k => k;
    assert.equal(Changes.describe({ type: 'custom' }, 'islands', t), 'Islands');
    assert.equal(Changes.describe({ type: 'custom' }, '/home/me/a b.png', t), '/home/me/a b.png');
    assert.equal(Changes.describe({ type: 'slider', unit: 'px' }, 4, t), '4 px');
    // a slider's named value reads as its name, never the raw number
    assert.equal(Changes.describe({ type: 'slider', unit: 'px', specialValues: [{ value: -1, label: 'own' }] }, -1, t), t('own'));
});
