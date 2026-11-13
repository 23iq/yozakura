// Settings navigation (modules/settings/schema/Categories.js): nine
// destinations as nine equal home tiles, each with its tabs, every category
// reachable, old ids (category, moved, former destination or sidebar group)
// still resolve.
const { test } = require('node:test');
const assert = require('node:assert/strict');
const path = require('node:path');
const { loadLibrary } = require('./lib/qmljs.cjs');

const Categories = loadLibrary(path.join(__dirname, '..', 'modules/settings/schema/Categories.js'));
const tr = lang => require(`../translations/${lang}.json`);
const plain = v => JSON.parse(JSON.stringify(v));

const TILES = ['look', 'screen', 'windows', 'panels', 'notifications', 'assistant', 'keys', 'devices', 'system'];
const TABS = {
    look: ['appearance', 'wallpapers', 'icons-type', 'presets', 'changes'],
    screen: ['bar', 'notch', 'dock', 'desktop', 'lockscreen'],
    windows: ['windows', 'overview', 'specials'],
    panels: ['launcher', 'dashboard', 'menus'],
    notifications: ['notifications', 'timers'],
    assistant: ['ai', 'ai-providers', 'ai-code', 'voice'],
    keys: ['keyboard', 'input'],
    devices: ['displays', 'network', 'bluetooth', 'sound', 'effects', 'power'],
    system: ['system', 'updates', 'terminal', 'extras', 'mods', 'routines', 'about'],
};

test('home is the nine destinations, sized by weight, titled (en, es, ru) and with an icon', () => {
    const home = Categories.home();
    assert.deepEqual(plain(home.map(g => g.id)).sort(), [...TILES].sort(), 'one tile per destination');
    assert.equal(Categories.pills, undefined, 'no status-tile row');
    const area = g => g.w * g.h;
    for (const g of home) {
        assert.ok(g.w >= 1 && g.h >= 1, `${g.id}: a size in six-column cells`);
        for (const lang of ['en', 'es', 'ru'])
            assert.ok(tr(lang)[g.title], `${lang} ${g.title}`);
        assert.ok(g.icon, g.id);
        assert.ok(g.categories.length > 0, g.id);
    }
    // reading order is weight order: no tile is bigger than one before it
    home.forEach((g, i) => i > 0 && assert.ok(area(g) <= area(home[i - 1]), `${g.id} after a smaller tile`));
    assert.equal(home[0].id, 'screen', 'Screen is the biggest tile');
    assert.equal(home[1].id, 'look', 'Look comes next');
});

test('the destinations and their tabs', () => {
    assert.deepEqual(plain(Categories.groups.map(g => g.id)), TILES);
    for (const g of Categories.groups)
        assert.deepEqual(plain(g.categories), TABS[g.id], g.id);
});

test('every category is one tab of exactly one destination', () => {
    for (const c of Categories.categories) {
        assert.ok(Categories.groupOf(c.id), `${c.id} is in no destination`);
        assert.equal(Categories.groups.filter(x => x.categories.includes(c.id)).length, 1, c.id);
    }
});

test('tab titles are short and unique within a destination', () => {
    for (const g of Categories.groups) {
        const titles = Categories.tabsOf(g.categories[0]).map(c => tr('en')[c.title]);
        assert.equal(new Set(titles).size, titles.length, g.id);
        for (const t of titles)
            assert.ok(t.split(/\s+/).length <= 3, `${g.id}: tab ${t}`);
    }
});

test('old category ids still resolve to their own page', () => {
    for (const id of ['appearance', 'wallpapers', 'notch', 'overview', 'specials', 'network', 'sound', 'ai', 'mods', 'about', 'input', 'keyboard', 'voice', 'timers', 'terminal'])
        assert.equal(Categories.resolve(id).id, id);
});

test('moved ids, former destinations and sidebar groups open a page', () => {
    const want = {
        island: 'notch', look: 'appearance', popups: 'notifications', wallpaper: 'wallpapers',
        assistant: 'ai', apps: 'terminal', power: 'power', system: 'system', layout: 'bar',
        osd: 'menus', screen: 'bar', panels: 'launcher', devices: 'displays', keys: 'keyboard',
        presets: 'presets', lockscreen: 'lockscreen', desktop: 'desktop', effects: 'effects',
    };
    for (const [id, cat] of Object.entries(want))
        assert.equal(Categories.resolve(id).id, cat, id);
    assert.equal(Categories.resolve('nope'), null);
});
