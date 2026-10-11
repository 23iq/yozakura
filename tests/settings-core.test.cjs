// Settings core: deep equality, step/snap rules, reset visibility, search
// filtering and the wallpaper default source.
const { test } = require('node:test');
const assert = require('node:assert/strict');
const path = require('node:path');

const qmljs = require('./lib/qmljs.cjs');
const repo = path.join(__dirname, '..');
const lib = rel => qmljs.loadLibrary(path.join(repo, rel));
const plain = v => JSON.parse(JSON.stringify(v));

const SchemaUtil = lib('modules/settings/SchemaUtil.js');
const ResetModel = lib('modules/settings/ResetModel.js');
const Defaults = lib('modules/settings/SettingsDefaults.js');
const WallpaperDefaults = lib('modules/widgets/dashboard/wallpapers/WallpaperDefaults.js');
const Ui = lib('modules/settings/Ui.js');

test('equal is a deep, key-order independent comparison', () => {
    assert.equal(SchemaUtil.equal({ a: 1, b: { c: [1, 2], d: 'x' } }, { b: { d: 'x', c: [1, 2] }, a: 1 }), true);
    assert.equal(SchemaUtil.equal([{ a: 1, b: 2 }], [{ b: 2, a: 1 }]), true);
    assert.equal(SchemaUtil.equal({ a: 1 }, { a: 2 }), false);
    assert.equal(SchemaUtil.equal({ a: 1 }, { a: 1, b: 1 }), false);
    assert.equal(SchemaUtil.equal([1, 2], [2, 1]), false);
    assert.equal(SchemaUtil.equal({ a: 1, b: undefined }, { a: 1 }), true);
    assert.equal(SchemaUtil.equal(NaN, NaN), true);
    assert.equal(SchemaUtil.equal(null, undefined), false);
    assert.equal(SchemaUtil.equal({ a: [] }, { a: {} }), false);
    assert.equal(SchemaUtil.equal({ x: 0.1 + 0.2 }, { x: 0.3 }), true);
});

test('snap rounds float noise to the decimals of the step', () => {
    assert.equal(Ui.snap(0.30000000000000004, 0, 1, 0.1), 0.3);
    assert.equal(Ui.snap(0.1 + 0.2, 0, 1, 0.05), 0.3);
    assert.equal(Ui.snap(7.4, 0, 10, 1), 7);
    assert.equal(Ui.snap(99, 0, 10, 1), 10);
    assert.equal(Ui.snap(0.35, 0.1, 1, 0.05), 0.35);
});

test('special values below min are reachable by stepping', () => {
    const sp = [{ value: -1, label: 'auto' }];
    assert.equal(Ui.stepValue(5, -1, 5, 100, 1, sp), -1);
    assert.equal(Ui.stepValue(-1, 1, 5, 100, 1, sp), 5);
    assert.equal(Ui.stepValue(-1, -1, 5, 100, 1, sp), -1);
    assert.equal(Ui.stepValue(5, -1, 5, 100, 1, []), 5);
    assert.equal(Ui.stepValue(10, 1, 5, 100, 1, sp), 11);
    assert.equal(Ui.stepValue(0.2, 1, 0, 1, 0.1, []), 0.3);
    assert.equal(Ui.finite('abc', 3), 3);
    assert.equal(Ui.finite(undefined, 3), 3);
    assert.equal(Ui.finite('4', 3), 4);
});

const cat = {
    sections: [
        {
            id: 'a', entries: [
                { key: 'bar.compact', type: 'toggle' },
                { key: 'dock.height', type: 'slider', visibleWhen: { key: 'dock.enabled', equals: true } },
                { key: 'compositor.gapsIn', type: 'slider' },
                { id: 'win', type: 'custom', keys: ['compositor.rounding', 'compositor.syncRoundness'] },
                { key: 'system.focus', type: 'toggle', compositor: 'niri' },
            ],
        },
        { id: 'b', compositor: 'hyprland', entries: [{ key: 'system.idle', type: 'list' }] },
    ],
};

test('reset only touches visible entries of the running compositor', () => {
    const ids = (compositor, vals) => ResetModel.activeItems(cat, { compositor, get: k => vals[k] })
        .map(i => i.entry.key || i.entry.id);
    assert.deepEqual(plain(ids('hyprland', { 'dock.enabled': true })), ['bar.compact', 'dock.height', 'compositor.gapsIn', 'win', 'system.idle']);
    assert.deepEqual(plain(ids('hyprland', { 'dock.enabled': false })), ['bar.compact', 'compositor.gapsIn', 'win', 'system.idle']);
    // niri: Hyprland-domain entries and Hyprland-only sections are skipped
    assert.deepEqual(plain(ids('niri', { 'dock.enabled': true })), ['bar.compact', 'dock.height', 'system.focus']);
    // unknown compositor (probe pending): never apply compositor defaults
    assert.deepEqual(plain(ids('', { 'dock.enabled': true })), ['bar.compact', 'dock.height']);
});

test('unstagedKeys lists modified keys of domains without a snapshot', () => {
    const items = SchemaUtil.flatten([{ sections: [{ id: 's', entries: [
        { key: 'bar.compact' }, { key: 'general.x' }, { key: 'wallpaper.matugenScheme' }, { key: 'weather.unit' },
    ] }] }]);
    const staged = d => d === 'bar';
    const modified = e => e.key !== 'weather.unit';
    assert.deepEqual(plain(ResetModel.unstagedKeys(items, modified, staged)), ['general.x']);
});

test('search skips hidden and other-compositor entries and tells duplicates apart', () => {
    const cats = [{
        id: 'c', title: 't', icon: 'x', sections: [
            { id: 's', title: 'S', entries: [
                { key: 'bar.position', type: 'selector', label: 'Position' },
                { key: 'notch.position', type: 'selector', label: 'Position' },
                { key: 'dock.height', type: 'slider', label: 'Height', visibleWhen: { key: 'dock.enabled', equals: true } },
                { key: 'system.focus', type: 'toggle', label: 'Focus', compositor: 'niri' },
            ] },
        ],
    }];
    const index = SchemaUtil.buildSearchIndex(cats, k => k);
    const pos = index.filter(i => i.label === 'Position');
    assert.equal(new Set(pos.map(i => i.context)).size, 2);
    const ctx = (compositor, vals) => ({ compositor, get: k => vals[k] });
    const found = (q, c) => SchemaUtil.search(index, q, 10, c).map(i => i.entryId);
    assert.deepEqual(plain(found('height', ctx('hyprland', { 'dock.enabled': false }))), []);
    assert.deepEqual(plain(found('height', ctx('hyprland', { 'dock.enabled': true }))), ['dock.height']);
    assert.deepEqual(plain(found('focus', ctx('hyprland', {}))), []);
    assert.deepEqual(plain(found('focus', ctx('niri', {}))), ['system.focus']);
    assert.ok(found('height').length === 1, 'no context = no filtering');
});

test('wallpaper defaults come from one source', () => {
    assert.equal(Defaults.get('wallpaper.matugenScheme'), WallpaperDefaults.MATUGEN_SCHEME);
    assert.equal(Defaults.get('wallpaper.activeColorPreset'), WallpaperDefaults.ACTIVE_COLOR_PRESET);
    assert.equal(Defaults.get('wallpaper.wallPath'), undefined);
});
