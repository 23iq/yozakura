// Settings navigation (modules/settings/schema/Categories.js): the home
// bento of destinations plus a row of pills, each destination with its
// tabs, every category reachable, old ids (category, moved, former sidebar
// group) still resolve.
const { test } = require('node:test');
const assert = require('node:assert/strict');
const path = require('node:path');
const { loadLibrary } = require('./lib/qmljs.cjs');

const Categories = loadLibrary(path.join(__dirname, '..', 'modules/settings/schema/Categories.js'));
const tr = lang => require(`../translations/${lang}.json`);
const plain = v => JSON.parse(JSON.stringify(v));

const TILES = ['layout', 'look', 'wallpaper', 'presets', 'notifications', 'lockscreen', 'assistant',
    'launcher', 'dashboard', 'desktop', 'keys', 'displays', 'windows'];
const PILLS = ['network', 'sound', 'power', 'apps', 'system'];

test('home is the destinations as tiles then pills, each titled (en, es, ru) and with an icon', () => {
    const home = Categories.home();
    assert.deepEqual(plain(home.map(g => g.id)), TILES);
    assert.deepEqual(plain(Categories.pills().map(g => g.id)), PILLS);
    assert.equal(home[0].size, 'big');
    for (const g of home)
        assert.ok(['big', 'wide', 'small'].includes(g.size), g.id);
    for (const g of home.concat(Categories.pills())) {
        for (const lang of ['en', 'es', 'ru'])
            assert.ok(tr(lang)[g.title], `${lang} ${g.title}`);
        assert.ok(g.icon, g.id);
        assert.ok(g.categories.length > 0, g.id);
    }
});

test('home and pills hold every destination exactly once', () => {
    const all = TILES.concat(PILLS);
    assert.deepEqual(plain(Categories.groups.map(g => g.id)).sort(), all.slice().sort());
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
    // Desktop layout: Bar, Island, Dock, Where things open
    assert.deepEqual(plain(Categories.tabsOf('layout').map(c => c.id)), ['bar', 'notch', 'dock', 'layout']);
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
