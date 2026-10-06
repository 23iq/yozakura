// `advanced: true` schema entries gather in one collapsed "Advanced" block
// per page (modules/settings/schema/Advanced.js); search still finds them.
const { test } = require('node:test');
const assert = require('node:assert/strict');
const path = require('node:path');
const { loadLibrary } = require('./lib/qmljs.cjs');

const repo = path.join(__dirname, '..');
const Advanced = loadLibrary(path.join(repo, 'modules/settings/schema/Advanced.js'));
const SchemaUtil = loadLibrary(path.join(repo, 'modules/settings/SchemaUtil.js'));
const Categories = loadLibrary(path.join(repo, 'modules/settings/schema/Categories.js'));
const en = require('../translations/en.json');
const plain = v => JSON.parse(JSON.stringify(v));

const cat = () => ({
    id: 'demo', icon: 'gear', title: 'prefs.cat.bar',
    sections: [
        { id: 'main', title: 't', entries: [{ key: 'bar.a', label: 'A' }, { key: 'bar.b', label: 'B', advanced: true }] },
        { id: 'hypr', compositor: 'hyprland', entries: [{ key: 'bar.c', label: 'C', advanced: true }] },
    ],
});

test('advanced entries move to one collapsed block at the end', () => {
    const out = Advanced.apply(cat());
    assert.deepEqual(plain(out.sections.map(s => s.id)), ['main', Advanced.SECTION_ID]);
    const block = out.sections[1];
    assert.equal(block.collapsible, true);
    assert.equal(block.collapsed, true);
    assert.equal(block.title, 'prefs.common.advanced');
    assert.deepEqual(plain(block.entries.map(e => e.key)), ['bar.b', 'bar.c']);
    assert.deepEqual(plain(out.sections[0].entries.map(e => e.key)), ['bar.a']);
});

test('an advanced entry keeps the compositor of its section', () => {
    const block = Advanced.apply(cat()).sections[1];
    assert.equal(block.entries[1].compositor, 'hyprland');
    assert.equal(block.entries[0].compositor, undefined);
});

test('the source category is not mutated, pages without advanced entries are unchanged', () => {
    const src = cat();
    const before = plain(src);
    Advanced.apply(src);
    assert.deepEqual(plain(src), before);
    const simple = { id: 'x', sections: [{ id: 'a', entries: [{ key: 'bar.a' }] }] };
    assert.deepEqual(plain(Advanced.apply(simple)), plain(simple));
    const page = { id: 'p', page: 'About' };
    assert.equal(Advanced.apply(page), page);
});

test('search points an advanced entry at the Advanced block', () => {
    const index = SchemaUtil.buildSearchIndex([Advanced.apply(cat())], k => k);
    const hit = SchemaUtil.search(index, 'B', 5).find(r => r.entryId === 'bar.b');
    assert.ok(hit);
    assert.equal(hit.sectionId, Advanced.SECTION_ID);
});

test('the block title is translated and no real section uses its id', () => {
    assert.ok(en['prefs.common.advanced']);
    for (const c of Categories.categories)
        for (const s of c.sections || [])
            if (s.id === Advanced.SECTION_ID)
                assert.equal(s.title, 'prefs.common.advanced', c.id);
});
