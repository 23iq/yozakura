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
    const { ctx, isModified } = ctxOf({ 'theme.roundness': 4, 'dock.position': 'left', 'bar.position': 'bottom' });
    const groups = Changes.fromDefaults(pages, ctx, isModified, Defaults.get, tr);
    const ids = groups.map(g => g.categoryId);
    assert.ok(ids.indexOf('bar') < ids.indexOf('dock') && ids.indexOf('dock') < ids.indexOf('appearance'), ids.join());
    const round = groups.find(g => g.categoryId === 'appearance').rows.find(r => r.entryId === 'theme.roundness');
    assert.equal(round.now, '4 px');
    assert.equal(round.was, '16 px');
    assert.equal(round.label, tr('settings.theme.roundness'));
    const dock = groups.find(g => g.categoryId === 'dock').rows[0];
    assert.equal(dock.now, tr('common.left'));
    assert.equal(Changes.count(groups), 3);
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
        { key: 'theme.roundness', a: 4, b: 12 },
        { key: 'theme.someUnknownThing', a: true, b: false },
        { key: 'dock.position', a: 'left', b: 'bottom' },
    ], index, pages, t);
    assert.deepEqual(plain(groups.map(g => g.categoryId)), ['dock', 'appearance', '']);
    const r = groups[1].rows[0];
    assert.equal(r.target, 12);
    assert.equal(r.now, '4 px');
    assert.equal(groups[2].title, en['prefs.changes.other']);
    assert.equal(groups[2].rows[0].label, 'Theme · Some unknown thing');
    assert.equal(groups[0].rows[0].was, en['common.bottom']);
});

test('values of a custom editor (no options) read as words, not ids', () => {
    const t = k => k;
    assert.equal(Changes.describe({ type: 'custom' }, 'islands', t), 'Islands');
    assert.equal(Changes.describe({ type: 'custom' }, '/home/me/a b.png', t), '/home/me/a b.png');
    assert.equal(Changes.describe({ type: 'slider', unit: 'px' }, 4, t), '4 px');
});
