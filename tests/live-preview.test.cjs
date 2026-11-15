// Live previews (modules/components/preview, modules/settings/live): the
// override lens real shell parts read, and the settings-side helpers.
const { test } = require('node:test');
const assert = require('node:assert/strict');
const path = require('node:path');

const qmljs = require('./lib/qmljs.cjs');
const lib = file => qmljs.loadLibrary(path.join(__dirname, '..', file));
const plain = v => JSON.parse(JSON.stringify(v));

const Preview = lib('modules/components/preview/Preview.js');
const Keys = lib('modules/settings/live/LiveKeys.js');
const Patch = lib('modules/settings/live/LivePatch.js');
const Modules = lib('modules/bar/BarModuleRegistry.js');

test('pick: the live value unless the preview overrides the key', () => {
    assert.equal(Preview.pick(null, 'workspaces.indicatorStyle', 'pill'), 'pill');
    assert.equal(Preview.pick(undefined, 'a', 1), 1);
    const ctx = { overrides: { 'workspaces.indicatorStyle': 'branch', 'dock.enabled': false } };
    assert.equal(Preview.pick(ctx, 'workspaces.indicatorStyle', 'pill'), 'branch');
    // a falsy override still wins
    assert.equal(Preview.pick(ctx, 'dock.enabled', true), false);
    assert.equal(Preview.pick(ctx, 'workspaces.numeralStyle', 'arabic'), 'arabic');
    assert.equal(Preview.pick({}, 'x', 3), 3);
});

test('on: a part is a preview when it has a context', () => {
    assert.equal(Preview.on(null), false);
    assert.equal(Preview.on(undefined), false);
    assert.equal(Preview.on({ overrides: {} }), true);
});

test('withValue copies the overrides with one more key', () => {
    const base = { a: 1 };
    const out = Preview.withValue(base, 'b', 2);
    assert.deepEqual(plain(out), { a: 1, b: 2 });
    assert.deepEqual(base, { a: 1 });
    assert.deepEqual(plain(Preview.withValue(null, 'k', 'v')), { k: 'v' });
});

test('every bar module has spot keys and a card (a new one needs nothing)', () => {
    for (const id of Modules.ids()) {
        const keys = Keys.moduleKeys(id);
        assert.ok(Array.isArray(keys) && keys.length > 0, id);
        assert.ok(['clock', 'workspaces', 'layout'].includes(Keys.sectionOf(id)), id);
    }
    assert.deepEqual(plain(Keys.moduleKeys('weather')), ['bar.moduleOptions.weather']);
    assert.equal(Keys.sectionOf('clock'), 'clock');
    assert.equal(Keys.sectionOf('workspaces'), 'workspaces');
    assert.equal(Keys.sectionOf('systray'), 'layout');
});

test('only: a bar holding just these modules', () => {
    const p = plain(Patch.only('workspaces'));
    assert.deepEqual(p.groups.start, ['workspaces']);
    for (const g of ['center', 'end', 'drawer', 'gapStart', 'gapEnd'])
        assert.deepEqual(p.groups[g], [], g);
    assert.deepEqual(plain(Patch.only(['launcher', 'clock'])).groups.start, ['launcher', 'clock']);
});

test('sample: a few of your modules, each in its group', () => {
    const p = plain(Patch.sample({
        start: ['launcher', '__sep__', 'workspaces', 'pin'],
        center: ['clock', 'media'],
        end: ['systray', 'battery', 'power']
    }));
    assert.deepEqual(p.groups.start, ['launcher', 'workspaces']);
    assert.deepEqual(p.groups.center, ['clock']);
    assert.deepEqual(p.groups.end, ['battery', 'power']);
    assert.deepEqual(plain(Patch.sample(null)).groups.start, []);
    assert.deepEqual(plain(Patch.style('islands')), { style: 'islands' });
});
