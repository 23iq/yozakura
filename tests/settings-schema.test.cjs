const { test } = require('node:test');
const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');

const qmljs = require('./lib/qmljs.cjs');
const repo = path.join(__dirname, '..');
const lib = rel => qmljs.loadLibrary(path.join(repo, rel));
const plain = v => JSON.parse(JSON.stringify(v));

const Categories = lib('modules/settings/schema/Categories.js');
const SchemaUtil = lib('modules/settings/SchemaUtil.js');
const Defaults = lib('modules/settings/SettingsDefaults.js');
const Registry = lib('modules/settings/Registry.js');
const BarModules = lib('modules/settings/BarModules.js');
const BarLayout = lib('modules/bar/BarLayout.js');
const en = require('../translations/en.json');
const tr = k => (k in en ? en[k] : null);

test('every category validates against defaults, translations and the registry', () => {
    for (const cat of Categories.categories)
        assert.deepEqual(plain(SchemaUtil.validateCategory(cat, Defaults.get, tr, Registry)), [], cat.id);
});

test('validation catches drift', () => {
    const broken = {
        id: 'x', icon: 'gear', title: 'prefs.cat.bar',
        sections: [{
            id: 's', entries: [
                { key: 'bar.noSuchKey', type: 'toggle', label: 'prefs.bar.compact' },
                { key: 'bar.position', type: 'selector', label: 'prefs.bar.position', options: [{ value: 'left' }, { value: 'right' }] },
                { key: 'theme.roundness', type: 'slider', label: 'missing.label.key', min: 30, max: 40 },
                { key: 'bar.compact', type: 'toggle', label: 'prefs.bar.compact', visibleWhen: { key: 'bar.nope', equals: true } },
                { id: 'c', type: 'custom', component: 'NotRegistered', label: 'prefs.bar.layout' },
                { key: 'bar.compact', type: 'wat', label: 'prefs.bar.compact' },
            ],
        }],
    };
    const problems = SchemaUtil.validateCategory(broken, Defaults.get, tr, Registry).join('\n');
    assert.match(problems, /bar\.noSuchKey' has no default/);
    assert.match(problems, /default 'top' is not an option/);
    assert.match(problems, /missing translation 'missing\.label\.key'/);
    assert.match(problems, /default 16 outside \[30, 40\]/);
    assert.match(problems, /key 'bar\.nope' has no default/);
    assert.match(problems, /'NotRegistered' is not in Registry\.js/);
    assert.match(problems, /unknown type 'wat'/);
    assert.match(problems, /duplicate entry id 'bar\.compact'/);
});

test('sidebar groups reference existing categories, each listed once', () => {
    const seen = new Set();
    for (const g of Categories.groups) {
        assert.ok(tr(g.title), g.title);
        for (const id of g.categories) {
            assert.ok(Categories.byId(id), id);
            assert.ok(!seen.has(id), `${id} listed twice`);
            seen.add(id);
        }
    }
    assert.equal(Categories.ordered()[0].id, 'layout');
});

test('registry files, legacy panels and links exist', () => {
    for (const rel of Object.values(Registry.EDITORS).concat(Object.values(Registry.PREVIEWS)))
        assert.ok(fs.existsSync(path.join(repo, 'modules/settings', rel)), rel);
    for (const cat of Categories.categories) {
        if (cat.legacy)
            assert.ok(fs.existsSync(path.join(repo, 'modules/widgets', cat.legacy.source)), cat.legacy.source);
        for (const { entry } of SchemaUtil.flatten([cat]))
            if (entry.target)
                assert.ok(Categories.byId(entry.target), entry.target);
    }
});

test('bar module presentation covers exactly the bar registry', () => {
    assert.deepEqual(Object.keys(BarModules.INFO).sort(), plain(BarLayout.MODULE_IDS).sort());
});

test('defaults resolve nested and wallpaper keys', () => {
    assert.equal(Defaults.get('theme.roundness'), 16);
    assert.deepEqual(plain(Defaults.get('bar.layout.left')), ['launcher', 'workspaces', 'layoutSelector', 'pin']);
    assert.equal(Defaults.get('bar.layout.style'), 'classic');
    assert.equal(Defaults.get('wallpaper.matugenScheme'), 'scheme-tonal-spot');
    assert.deepEqual(plain(Defaults.get('desktop.wallpaperFolders')), []);
    assert.equal(Defaults.get('nope.key'), undefined);
});

test('withPath copies, never mutates', () => {
    const layout = { style: 'classic', left: ['a'] };
    const next = SchemaUtil.withPath(layout, ['style'], 'islands');
    assert.equal(layout.style, 'classic');
    assert.deepEqual(plain(next), { style: 'islands', left: ['a'] });
    assert.deepEqual(plain(SchemaUtil.withPath(undefined, ['a', 'b'], 1)), { a: { b: 1 } });
});

test('conditions', () => {
    const values = { 'a.on': true, 'a.mode': 'grow', 'a.n': 3 };
    const get = k => values[k];
    assert.equal(SchemaUtil.evalCondition(undefined, get), true);
    assert.equal(SchemaUtil.evalCondition({ key: 'a.on', equals: true }, get), true);
    assert.equal(SchemaUtil.evalCondition({ key: 'a.mode', notEquals: 'none' }, get), true);
    assert.equal(SchemaUtil.evalCondition({ key: 'a.mode', in: ['wipe', 'fade'] }, get), false);
    assert.equal(SchemaUtil.evalCondition({ all: [{ key: 'a.on', equals: true }, { not: { key: 'a.n', equals: 3 } }] }, get), false);
    assert.equal(SchemaUtil.evalCondition({ any: [{ key: 'a.on', equals: false }, { key: 'a.n', truthy: true }] }, get), true);
    assert.deepEqual(plain(SchemaUtil.conditionKeys({ all: [{ key: 'x' }, { not: { key: 'y' } }] })), ['x', 'y']);
});

test('equal treats list wrappers like arrays', () => {
    const wrapper = { length: 2, 0: 'a', 1: 'b' };
    assert.equal(SchemaUtil.equal(['a', 'b'], ['a', 'b']), true);
    assert.equal(SchemaUtil.equal(0.1 + 0.2, 0.3), true);
    assert.equal(SchemaUtil.equal(['a'], ['b']), false);
    assert.equal(SchemaUtil.equal(plain(Array.from(wrapper)), ['a', 'b']), true);
});

test('search is generated from the schema', () => {
    const index = SchemaUtil.buildSearchIndex(Categories.categories, k => tr(k) || k);
    const ids = q => SchemaUtil.search(index, q).map(r => r.entryId || r.categoryId);
    assert.ok(ids('kanji').includes('workspaces.numeralStyle'));
    assert.equal(ids('wallpaper folder')[0], 'desktop.wallpaperFolders');
    assert.equal(ids('roundness')[0], 'theme.roundness');
    assert.ok(ids('matugen').includes('wallpaper.matugenScheme'));
    assert.ok(ids('blur').includes('windows'), 'legacy topics are searchable');
    assert.deepEqual(plain(ids('zzzzqqq')), []);
    // Every schema entry with a label is indexed.
    const labelled = SchemaUtil.flatten(Categories.categories).filter(x => x.entry.label).length;
    assert.equal(index.filter(i => i.entryId).length, labelled);
});

test('bar layout moves', () => {
    const layout = BarModules.layoutOf({ style: 'islands', left: ['launcher', 'bogus'], right: ['clock'], drawer: [] });
    assert.deepEqual(plain(layout.left), ['launcher']);
    assert.ok(plain(BarModules.unused(layout)).includes('power'));
    let next = BarModules.move(layout, 'clock', 'left', 0);
    assert.deepEqual(plain(next.left), ['clock', 'launcher']);
    assert.deepEqual(plain(next.right), []);
    next = BarModules.move(next, 'power', 'drawer', 99);
    assert.deepEqual(plain(next.drawer), ['power']);
    next = BarModules.move(next, 'launcher', 'available', -1);
    assert.deepEqual(plain(next.left), ['clock']);
    assert.equal(BarModules.locate(next, 'launcher').group, 'available');
    assert.deepEqual(plain(BarModules.locate(next, 'power')), { group: 'drawer', index: 0 });
    assert.equal(next.style, 'islands');
});

test('list helpers return new arrays and keep the original intact', () => {
    const orig = [{ timeout: 1 }, { timeout: 2 }, { timeout: 3 }];
    assert.deepEqual(plain(SchemaUtil.listMove(orig, 0, 2)).map(i => i.timeout), [2, 3, 1]);
    assert.deepEqual(plain(SchemaUtil.listMove(orig, 0, 9)).map(i => i.timeout), [1, 2, 3], 'out of range is a no-op');
    assert.deepEqual(plain(SchemaUtil.listRemove(orig, 1)).map(i => i.timeout), [1, 3]);
    assert.deepEqual(plain(SchemaUtil.listInsert(orig, { timeout: 9 })).map(i => i.timeout), [1, 2, 3, 9]);
    assert.deepEqual(plain(SchemaUtil.listSet(orig, 2, 'timeout', 30))[2], { timeout: 30 });
    assert.deepEqual(plain(SchemaUtil.listSet(['/'], 0, '', '/home')), ['/home'], 'string items');
    assert.deepEqual(orig.map(i => i.timeout), [1, 2, 3]);
    const entry = { fields: [{ key: 'app', type: 'text' }, { key: 'n', type: 'number', min: 5 }, { key: 'a', type: 'selector', options: [{ value: 'x' }, { value: 'y' }] }, { key: 'on', type: 'toggle' }] };
    assert.deepEqual(plain(SchemaUtil.newListItem(entry)), { app: '', n: 5, a: 'x', on: false });
    assert.deepEqual(plain(SchemaUtil.newListItem({ itemType: 'path', newItem: '/' })), '/');
});

test('multi-select toggling keeps the option order', () => {
    const opts = [1, 2, 3, 4, 5, 6, 0].map(v => ({ value: v }));
    assert.deepEqual(plain(SchemaUtil.toggleValue([0, 1], 3, opts)), [1, 3, 0]);
    assert.deepEqual(plain(SchemaUtil.toggleValue([0, 1, 3], 1, opts)), [3, 0]);
    assert.deepEqual(plain(SchemaUtil.toggleValue([], 'DP-1')), ['DP-1']);
});

test('text patterns', () => {
    const e = { pattern: '^([01]?\\d|2[0-3]):[0-5]\\d$' };
    assert.equal(SchemaUtil.matchesPattern(e, '22:00'), true);
    assert.equal(SchemaUtil.matchesPattern(e, '25:00'), false);
    assert.equal(SchemaUtil.matchesPattern({}, 'anything'), true);
});

test('validation of list / multiselect / path entries', () => {
    const cat = {
        id: 'x', icon: 'gear', title: 'prefs.cat.bar',
        sections: [{
            id: 's', entries: [
                { key: 'notifications.rules', type: 'list', label: 'prefs.notif.rules' },
                { key: 'system.idle.listeners', type: 'list', label: 'idle.listeners', fields: [{ key: 't', type: 'slider' }, { key: 'n', type: 'number', label: 'idle.timeout' }] },
                { key: 'notifications.dnd.schedule.days', type: 'multiselect', label: 'prefs.notif.schedule_days', options: [{ value: 1, label: 'weather.day.mon' }, { value: 2, label: 'weather.day.tue' }] },
                { key: 'notifications.sound.enabled', type: 'path', label: 'prefs.notif.sound_file' },
                { key: 'notifications.dnd.schedule.from', type: 'text', label: 'prefs.notif.schedule_from', pattern: '^\\d$' }
            ]
        }]
    };
    const problems = plain(SchemaUtil.validateCategory(cat, Defaults.get, tr, Registry)).join('\n');
    assert.match(problems, /list needs `fields` or `itemType`/);
    assert.match(problems, /list field needs a key and a type/);
    assert.match(problems, /list field 'n' needs numeric min < max/);
    assert.match(problems, /default item '0' is not an option/);
    assert.match(problems, /path default is not a string/);
    assert.match(problems, /does not match pattern/);
});

test('migrated system categories replace their legacy panels', () => {
    for (const id of ['system', 'terminal', 'voice', 'updates', 'notifications']) {
        const c = Categories.byId(id);
        assert.ok(c && c.sections && !c.legacy && !c.page, id);
    }
    for (const c of Categories.categories)
        assert.notEqual(c.legacy && c.legacy.source, 'dashboard/controls/SystemPanel.qml', c.id);
    assert.equal(fs.existsSync(path.join(repo, 'modules/widgets/dashboard/controls/SystemPanel.qml')), false);
});
