'use strict';
const test = require('node:test');
const assert = require('node:assert');
const path = require('node:path');
const { loadLibrary } = require('./lib/qmljs.cjs');

const M = loadLibrary(path.join(__dirname, '..', 'modules/settings/mods/ModsModel.js'));

const mods = [
    { id: 'b-mod', name: 'Beta', order: 0, enabled: false, valid: true, compatible: true, description: 'second' },
    { id: 'a-mod', name: 'Alpha', order: 2, enabled: true, valid: true, compatible: true, description: 'clock tweaks' },
    { id: 'c-mod', name: 'Gamma', order: 1, enabled: true, valid: true, compatible: false },
];
const ids = list => list.map(m => m.id);
const plain = v => JSON.parse(JSON.stringify(v));

test('dependenciesReady', () => {
    assert.strictEqual(M.dependenciesReady(null), true);
    assert.strictEqual(M.dependenciesReady({ dependencyState: [{ enabled: true }] }), true);
    assert.strictEqual(M.dependenciesReady({ dependencyState: [{ enabled: true }, { enabled: false }] }), false);
});

test('stateKey / stateTone', () => {
    assert.strictEqual(M.stateKey(null), '');
    assert.strictEqual(M.stateKey({ valid: false }), 'mods.package_error');
    assert.strictEqual(M.stateKey({ valid: true, compatible: false }), 'mods.incompatible');
    assert.strictEqual(M.stateKey({ valid: true, compatible: true, enabled: true }), 'mods.enabled');
    assert.strictEqual(M.stateKey({ valid: true, compatible: true }), 'mods.disabled');
    assert.strictEqual(M.stateTone(null), 'error');
    assert.strictEqual(M.stateTone({ valid: true, compatible: true, enabled: true, untested: true }), 'warning');
    assert.strictEqual(M.stateTone({ valid: true, compatible: true, enabled: true }), 'success');
    assert.strictEqual(M.stateTone({ valid: true, compatible: true, enabled: false }), 'error');
});

test('canToggle', () => {
    assert.strictEqual(M.canToggle(null, false), false);
    assert.strictEqual(M.canToggle({ enabled: true, valid: false }, false), true);
    assert.strictEqual(M.canToggle({ valid: true, compatible: false }, false), false);
    assert.strictEqual(M.canToggle({ valid: true, compatible: false }, true), true);
    assert.strictEqual(M.canToggle({ valid: false, compatible: true }, true), false);
    assert.strictEqual(M.canToggle({ valid: true, compatible: true, dependencyState: [{ enabled: false }] }, false), false);
});

test('filterMods sorts and filters', () => {
    assert.deepStrictEqual(ids(M.filterMods(mods, '', 'name')), ['a-mod', 'b-mod', 'c-mod']);
    assert.deepStrictEqual(ids(M.filterMods(mods, '', 'loadOrder')), ['b-mod', 'c-mod', 'a-mod']);
    assert.deepStrictEqual(ids(M.filterMods(mods, '', 'state')), ['a-mod', 'c-mod', 'b-mod']);
    assert.deepStrictEqual(ids(M.filterMods(mods, ' CLOCK ', 'name')), ['a-mod']);
    assert.deepStrictEqual(ids(M.filterMods(mods, 'c-mod', 'name')), ['c-mod']);
    assert.deepStrictEqual(plain(M.filterMods(undefined, 'x', 'name')), []);
    // the input is not mutated
    assert.deepStrictEqual(ids(mods), ['b-mod', 'a-mod', 'c-mod']);
});

test('selectMod falls back to the first mod', () => {
    assert.strictEqual(M.selectMod(mods, 'c-mod').id, 'c-mod');
    assert.strictEqual(M.selectMod(mods, 'nope').id, 'b-mod');
    assert.strictEqual(M.selectMod([], 'x'), null);
});

test('sort cycle and labels', () => {
    assert.strictEqual(M.nextSort('name'), 'state');
    assert.strictEqual(M.nextSort('state'), 'loadOrder');
    assert.strictEqual(M.nextSort('loadOrder'), 'name');
    assert.strictEqual(M.nextSort('bogus'), 'name');
    assert.strictEqual(M.sortLabelKey('loadOrder'), 'mods.sort_load_order');
    assert.strictEqual(M.sortLabelKey('bogus'), 'mods.sort_name');
    assert.strictEqual(M.canReorder('loadOrder', ''), true);
    assert.strictEqual(M.canReorder('loadOrder', 'a'), false);
    assert.strictEqual(M.canReorder('name', ''), false);
});

test('dropSlot clamps', () => {
    assert.strictEqual(M.dropSlot(0, 58, 3), 0);
    assert.strictEqual(M.dropSlot(60, 58, 3), 1);
    assert.strictEqual(M.dropSlot(-100, 58, 3), 0);
    assert.strictEqual(M.dropSlot(1000, 58, 3), 2);
    assert.strictEqual(M.dropSlot(10, 58, 0), -1);
});

test('dependencyKey', () => {
    assert.strictEqual(M.dependencyKey({ enabled: true }), 'mods.dependency_ready');
    assert.strictEqual(M.dependencyKey({ installed: true }), 'mods.dependency_disabled');
    assert.strictEqual(M.dependencyKey({}), 'mods.dependency_missing');
});

test('parseSettingValue', () => {
    assert.deepStrictEqual(plain(M.parseSettingValue('string', 'abc')), { ok: true, value: 'abc' });
    assert.deepStrictEqual(plain(M.parseSettingValue('integer', '42')), { ok: true, value: 42 });
    assert.deepStrictEqual(plain(M.parseSettingValue('number', '1.5')), { ok: true, value: 1.5 });
    assert.strictEqual(M.parseSettingValue('integer', 'x').ok, false);
    assert.strictEqual(M.parseSettingValue('number', '').ok, false);
    assert.strictEqual(M.isTextSetting('number'), true);
    assert.strictEqual(M.isTextSetting('boolean'), false);
});

test('enum helpers', () => {
    const opts = [{ value: 'a', label: 'A' }, { value: 2 }];
    assert.strictEqual(M.enumLabel(opts, 'a'), 'A');
    assert.strictEqual(M.enumLabel(opts, 'z'), null);
    assert.deepStrictEqual(plain(M.enumChoices(opts)), [{ value: 'a', label: 'A' }, { value: 2, label: '2' }]);
});

test('bannerState priority', () => {
    const base = { generationCurrent: true, modsEnabled: true };
    assert.strictEqual(M.bannerState(null).kind, '');
    assert.strictEqual(M.bannerState(base).kind, '');
    assert.deepStrictEqual(plain(M.bannerState({ ...base, errorMessage: 'boom', generationCurrent: false })), { kind: 'error', text: 'boom' });
    assert.deepStrictEqual(plain(M.bannerState({ ...base, generationCurrent: false, generationError: 'x' })), { kind: 'rebuild', text: 'x' });
    assert.strictEqual(M.bannerState({ ...base, restartRequired: true }).kind, 'restart');
    assert.strictEqual(M.bannerState({ ...base, modsEnabled: false, restartRequired: true }).kind, 'restartBase');
    assert.deepStrictEqual(plain(M.bannerState({ ...base, statusMessageKey: 'mods.status_enabled', statusMessage: 'x' })), { kind: 'key', text: 'mods.status_enabled' });
    assert.strictEqual(M.bannerState({ ...base, statusMessage: 'done' }).kind, 'message');
});

test('shortRevision / joinList', () => {
    assert.strictEqual(M.shortRevision('0123456789abcdef'), '0123456789ab');
    assert.strictEqual(M.shortRevision(undefined), '');
    assert.strictEqual(M.joinList(['a', 'b']), 'a, b');
    assert.strictEqual(M.joinList(null), '');
});
