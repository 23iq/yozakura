// Settings search synonyms (modules/settings/Synonyms.js via SchemaUtil.search).
const { test } = require('node:test');
const assert = require('node:assert/strict');
const path = require('node:path');
const { loadLibrary } = require('./lib/qmljs.cjs');

const repo = path.join(__dirname, '..');
const lib = rel => loadLibrary(path.join(repo, rel));
const Synonyms = lib('modules/settings/Synonyms.js');
const SchemaUtil = lib('modules/settings/SchemaUtil.js');
const Categories = lib('modules/settings/schema/Categories.js');
const plain = v => JSON.parse(JSON.stringify(v));

const indexFor = lang => {
    const t = require(`../translations/${lang}.json`);
    return SchemaUtil.buildSearchIndex(Categories.categories, k => t[k] || k);
};
const en = indexFor('en');
const ru = indexFor('ru');
const ids = (index, q) => plain(SchemaUtil.search(index, q, 15).map(r => r.entryId || r.categoryId));

test('alternatives replace a word, a stem or a phrase', () => {
    assert.deepEqual(plain(Synonyms.alternatives('transparency')), ['opacity', 'glass']);
    assert.ok(Synonyms.alternatives('rounded corners').includes('roundness'));
    assert.ok(Synonyms.alternatives('прозрачность').includes('glass'));
    assert.ok(Synonyms.alternatives('dock size').includes('dock scale'));
    assert.deepEqual(plain(Synonyms.alternatives('')), []);
});

test('short words only match whole words', () => {
    assert.ok(Synonyms.alternatives('ai').includes('assistant'));
    assert.equal(Synonyms.alternatives('airy').includes('assistant'), false);
});

test('synonyms find the setting the schema names differently', () => {
    assert.ok(ids(en, 'transparency').includes('macro.glass'));
    assert.ok(ids(en, 'rounded corners').includes('theme.roundness'));
    assert.ok(ids(en, 'island').includes('notch'));
    assert.ok(ids(en, 'taskbar').includes('bar'));
});

test('Russian words find settings in the translated UI', () => {
    assert.ok(ids(ru, 'прозрачность').includes('macro.glass'));
    assert.ok(ids(ru, 'обои').includes('wallpapers'));
    assert.ok(ids(ru, 'скругление').includes('theme.roundness'));
    assert.ok(ids(ru, 'остров').includes('notch'));
});

test('a direct match still ranks first', () => {
    assert.equal(ids(en, 'wallpaper folder')[0], 'desktop.wallpaperFolders');
    assert.deepEqual(ids(en, 'zzzzqqq'), []);
});
