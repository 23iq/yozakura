// The Changes page lists every setting that differs from its default,
// settings kept out of the window included (ResetModel.changedItems), while
// Reset page and the modified counters keep to window rows
// (ResetModel.activeItems).
const { test } = require('node:test');
const assert = require('node:assert/strict');
const path = require('node:path');
const { loadLibrary } = require('./lib/qmljs.cjs');

const repo = path.join(__dirname, '..');
const lib = rel => loadLibrary(path.join(repo, rel));
const Changes = lib('modules/settings/ChangesModel.js');
const Reset = lib('modules/settings/ResetModel.js');
const SchemaUtil = lib('modules/settings/SchemaUtil.js');
const Defaults = lib('modules/settings/SettingsDefaults.js');
const Categories = lib('modules/settings/schema/Categories.js');
const en = require('../translations/en.json');
const tr = k => en[k] || k;

const pages = Categories.groups.flatMap(g => g.categories).map(id => Categories.byId(id)).filter(c => c && c.sections);

function ctxOf(over, compositor = 'hyprland') {
    const get = k => (k in over ? over[k] : Defaults.get(k));
    const isModified = e => SchemaUtil.entryKeys(e).some(k => !SchemaUtil.equal(get(k), Defaults.get(k)));
    return { ctx: { compositor, get }, isModified };
}

// An out-of-window entry with a plain key, and its page.
function outOfWindowEntry() {
    for (const cat of pages)
        for (const sec of cat.sections)
            for (const e of sec.entries || [])
                if (!SchemaUtil.inWindow(e, sec) && e.key && !e.keys && !e.visibleWhen && !e.compositor && !sec.compositor
                    && typeof Defaults.get(e.key) === 'boolean')
                    return { cat, sec, e };
    return null;
}

test('an out-of-window setting that differs is listed, with reset and no jump', () => {
    const found = outOfWindowEntry();
    assert.ok(found, 'the schema has out-of-window entries');
    const { ctx, isModified } = ctxOf({ [found.e.key]: !Defaults.get(found.e.key) });
    const rows = Changes.fromDefaults(pages, ctx, isModified, Defaults.get, tr).flatMap(g => g.rows);
    const row = rows.find(r => r.entryId === SchemaUtil.entryId(found.e));
    assert.ok(row, `${found.e.key} is listed`);
    assert.equal(row.jump, false, 'no row to open');
    assert.equal(row.entry, found.e, 'the entry its reset uses');
    assert.equal(row.categoryId, found.cat.id, 'grouped under its page');
});

test('window rows still jump; Reset page and the counters keep to window rows', () => {
    const found = outOfWindowEntry();
    const { ctx, isModified } = ctxOf({ [found.e.key]: !Defaults.get(found.e.key), 'workspaces.shown': 4 });
    const rows = Changes.fromDefaults(pages, ctx, isModified, Defaults.get, tr).flatMap(g => g.rows);
    assert.equal(rows.find(r => r.entryId === 'workspaces.shown').jump, true);
    const active = Reset.activeItems(found.cat, ctx).map(it => it.entry);
    assert.ok(!active.includes(found.e), 'a page reset never touches it');
    assert.ok(Reset.changedItems(found.cat, ctx).some(it => it.entry === found.e && it.inWindow === false));
});

test('an out-of-window entry whose keys a window row holds is listed once, by that row', () => {
    const cat = {
        id: 'demo', sections: [
            { id: 's', entries: [{ id: 'row', keys: ['bar.compact', 'bar.clockShowDate'], label: 'x' }] },
            { id: 'adv', advanced: true, entries: [{ key: 'bar.compact', label: 'y' }, { key: 'bar.position', label: 'z' }] },
        ],
    };
    const { ctx } = ctxOf({});
    const ids = Reset.changedItems(cat, ctx).map(it => SchemaUtil.entryId(it.entry));
    assert.deepEqual([...ids], ['row', 'bar.position']);
});
