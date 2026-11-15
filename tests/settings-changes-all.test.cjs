// The Changes page lists every setting that differs from its default, the
// rows of the tabs' More cards included (ResetModel.changedItems), each with
// a jump to its row; Reset page and the modified counters cover the More
// card too (ResetModel.activeItems).
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

// An advanced entry (a row of the More card) with a plain key, and its page.
function advancedEntry() {
    for (const cat of pages)
        for (const sec of cat.sections)
            for (const e of sec.entries || [])
                if (SchemaUtil.isAdvanced(e, sec) && e.key && !e.keys && !e.visibleWhen && !e.compositor && !sec.compositor
                    && typeof Defaults.get(e.key) === 'boolean')
                    return { cat, sec, e };
    return null;
}

test('a More card setting that differs is listed, with reset and a jump', () => {
    const found = advancedEntry();
    assert.ok(found, 'the schema has advanced entries');
    const { ctx, isModified } = ctxOf({ [found.e.key]: !Defaults.get(found.e.key) });
    const rows = Changes.fromDefaults(pages, ctx, isModified, Defaults.get, tr).flatMap(g => g.rows);
    const row = rows.find(r => r.entryId === SchemaUtil.entryId(found.e));
    assert.ok(row, `${found.e.key} is listed`);
    assert.equal(row.jump, true, 'its row opens (the More card unfolds)');
    assert.equal(row.entry, found.e, 'the entry its reset uses');
    assert.equal(row.categoryId, found.cat.id, 'grouped under its page');
});

test('card rows jump; Reset page and the counters cover the More card', () => {
    const found = advancedEntry();
    const { ctx, isModified } = ctxOf({ [found.e.key]: !Defaults.get(found.e.key), 'workspaces.shown': 4 });
    const rows = Changes.fromDefaults(pages, ctx, isModified, Defaults.get, tr).flatMap(g => g.rows);
    assert.equal(rows.find(r => r.entryId === 'workspaces.shown').jump, true);
    const active = Reset.activeItems(found.cat, ctx).map(it => it.entry);
    assert.ok(active.includes(found.e), 'a page reset resets it too (it is on the page)');
    assert.ok(Reset.changedItems(found.cat, ctx).some(it => it.entry === found.e && it.inWindow === true));
});

test('a More card entry whose keys a card row holds is listed once, by that row', () => {
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
