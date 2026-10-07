// Settings sidebar tree (modules/settings/schema/Categories.js): 12
// element pages, every category reachable, old and new ids resolve.
const { test } = require('node:test');
const assert = require('node:assert/strict');
const path = require('node:path');
const { loadLibrary } = require('./lib/qmljs.cjs');

const Categories = loadLibrary(path.join(__dirname, '..', 'modules/settings/schema/Categories.js'));
const en = require('../translations/en.json');
const plain = v => JSON.parse(JSON.stringify(v));

const TREE = ['layout', 'bar', 'island', 'dock', 'launcher', 'dashboard', 'popups', 'lockscreen', 'desktop', 'look', 'presets', 'system'];

test('the sidebar is the 12 element pages, in order, each titled and with an icon', () => {
    const side = Categories.sidebar();
    assert.deepEqual(plain(side.map(g => g.id)), TREE);
    for (const g of side) {
        assert.ok(en[g.title], g.title);
        assert.ok(g.icon, g.id);
        assert.ok(g.categories.length > 0, g.id);
    }
});

test('every category sits in exactly one group', () => {
    for (const c of Categories.categories) {
        const g = Categories.groupOf(c.id);
        assert.ok(g, `${c.id} is in no group`);
        assert.equal(Categories.groups.filter(x => x.categories.includes(c.id)).length, 1, c.id);
    }
});

test('old category ids still resolve to their own page', () => {
    for (const id of ['appearance', 'wallpapers', 'notch', 'overview', 'specials', 'network', 'sound', 'ai', 'mods', 'about'])
        assert.equal(Categories.resolve(id).id, id);
});

test('group ids resolve to their first page', () => {
    assert.equal(Categories.resolve('island').id, 'notch');
    assert.equal(Categories.resolve('look').id, 'appearance');
    assert.equal(Categories.resolve('popups').id, 'notifications');
    assert.equal(Categories.resolve('dashboard').id, 'dashboard');
    assert.equal(Categories.resolve('layout').id, 'layout');
    assert.equal(Categories.resolve('system').id, 'system');
    assert.equal(Categories.resolve('nope'), null);
});

test('the presets page is promoted out of "More"', () => {
    assert.equal(Categories.groupOf('presets').id, 'presets');
});

test('the sidebar blocks hold every element page once, in order, each titled', () => {
    const secs = Categories.sidebarSections();
    assert.deepEqual(plain(secs.flatMap(s => s.groups.map(g => g.id))), TREE);
    for (const s of secs) {
        assert.ok(en[s.title], s.title);
        assert.ok(s.groups.length > 0, s.id);
    }
});
