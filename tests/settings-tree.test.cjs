// Settings navigation (modules/settings/schema/Categories.js): one flat
// sidebar of destinations in four labelled blocks, each destination with its
// tabs, every category reachable, old ids (category, moved, former sidebar
// group) still resolve.
const { test } = require('node:test');
const assert = require('node:assert/strict');
const path = require('node:path');
const { loadLibrary } = require('./lib/qmljs.cjs');

const Categories = loadLibrary(path.join(__dirname, '..', 'modules/settings/schema/Categories.js'));
const tr = lang => require(`../translations/${lang}.json`);
const plain = v => JSON.parse(JSON.stringify(v));

const TREE = ['bar', 'island', 'dock', 'launcher', 'dashboard', 'notifications', 'lockscreen', 'desktop',
    'look', 'wallpaper', 'presets', 'assistant',
    'displays', 'input', 'windows', 'network', 'sound', 'power', 'apps', 'system'];

test('the sidebar is the destinations, in order, each titled (en, es, ru) and with an icon', () => {
    const side = Categories.sidebar();
    assert.deepEqual(plain(side.map(g => g.id)), TREE);
    for (const g of side) {
        for (const lang of ['en', 'es', 'ru'])
            assert.ok(tr(lang)[g.title], `${lang} ${g.title}`);
        assert.ok(g.icon, g.id);
        assert.ok(g.categories.length > 0, g.id);
    }
});

test('every category is one tab of exactly one destination', () => {
    for (const c of Categories.categories) {
        assert.ok(Categories.groupOf(c.id), `${c.id} is in no destination`);
        assert.equal(Categories.groups.filter(x => x.categories.includes(c.id)).length, 1, c.id);
    }
});

test('a destination has a few tabs at most, each with a short title', () => {
    for (const g of Categories.groups) {
        assert.ok(g.categories.length <= 6, g.id);
        for (const c of Categories.tabsOf(g.categories[0]))
            assert.ok(tr('en')[c.title].split(/\s+/).length <= 3, `${g.id}: tab ${tr('en')[c.title]}`);
    }
    assert.deepEqual(plain(Categories.tabsOf('layout').map(c => c.id)), ['bar', 'layout']);
    assert.deepEqual(plain(Categories.tabsOf('icons-type').map(c => c.id)), ['appearance', 'icons-type']);
});

test('old category ids still resolve to their own page', () => {
    for (const id of ['appearance', 'wallpapers', 'notch', 'overview', 'specials', 'network', 'sound', 'ai', 'mods', 'about', 'layout', 'input', 'keyboard'])
        assert.equal(Categories.resolve(id).id, id);
});

test('destination ids and former sidebar groups open a page', () => {
    assert.equal(Categories.resolve('island').id, 'notch');
    assert.equal(Categories.resolve('look').id, 'appearance');
    assert.equal(Categories.resolve('popups').id, 'notifications');
    assert.equal(Categories.resolve('wallpaper').id, 'wallpapers');
    assert.equal(Categories.resolve('assistant').id, 'ai');
    assert.equal(Categories.resolve('apps').id, 'terminal');
    assert.equal(Categories.resolve('power').id, 'power');
    assert.equal(Categories.resolve('system').id, 'system');
    assert.equal(Categories.resolve('nope'), null);
});

test('the sidebar blocks hold every destination once, in order, each titled', () => {
    const secs = Categories.sidebarSections();
    assert.deepEqual(plain(secs.map(s => s.id)), ['shell', 'style', 'assistant', 'computer']);
    assert.deepEqual(plain(secs.flatMap(s => s.groups.map(g => g.id))), TREE);
    for (const s of secs) {
        assert.ok(tr('en')[s.title], s.title);
        assert.ok(s.groups.length > 0, s.id);
    }
});
