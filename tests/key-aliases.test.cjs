// Key-alias migration (config/meta/KeyAliases.js through
// ConfigValidator.migrateAliases): a renamed or moved config key keeps the
// user's value.
const { test } = require('node:test');
const assert = require('node:assert/strict');
const path = require('node:path');
const { loadLibrary } = require('./lib/qmljs.cjs');

const repo = path.join(__dirname, '..');
const validator = loadLibrary(path.join(repo, 'config/ConfigValidator.js'));
const KeyAliases = loadLibrary(path.join(repo, 'config/meta/KeyAliases.js'));
const plain = v => JSON.parse(JSON.stringify(v));

const ALIASES = [
    { from: 'theme.terminalOpacity', to: 'glass.surfaces.terminal.amount', transform: v => 1 - v },
    { from: 'bar.activities', to: 'notch.activities' },
    { from: 'theme.oldName', to: 'theme.newName' },
];

test('copies a value across domains and removes the old key', () => {
    const raws = { bar: { activities: { maxVisible: 3 }, position: 'top' }, notch: { theme: 'default' } };
    const changed = validator.migrateAliases(raws, ALIASES);
    assert.deepEqual(plain(raws.notch.activities), { maxVisible: 3 });
    assert.equal(raws.bar.activities, undefined);
    assert.equal(raws.bar.position, 'top');
    assert.deepEqual(plain(changed).sort(), ['bar', 'notch']);
});

test('applies the transform and creates nested targets', () => {
    const raws = { theme: { terminalOpacity: 0.25 }, glass: {} };
    validator.migrateAliases(raws, ALIASES);
    assert.equal(raws.glass.surfaces.terminal.amount, 0.75);
    assert.equal(raws.theme.terminalOpacity, undefined);
});

test('renames within one domain', () => {
    const raws = { theme: { oldName: 'x' } };
    assert.deepEqual(plain(validator.migrateAliases(raws, ALIASES)), ['theme']);
    assert.deepEqual(plain(raws.theme), { newName: 'x' });
});

test('a missing source changes nothing', () => {
    const raws = { bar: { position: 'top' }, notch: {} };
    assert.deepEqual(plain(validator.migrateAliases(raws, ALIASES)), []);
    assert.deepEqual(plain(raws), { bar: { position: 'top' }, notch: {} });
});

test('never overwrites an existing target; the old key still goes', () => {
    const raws = { bar: { activities: { maxVisible: 3 } }, notch: { activities: { maxVisible: 5 } } };
    assert.deepEqual(plain(validator.migrateAliases(raws, ALIASES)), ['bar']);
    assert.deepEqual(plain(raws.notch.activities), { maxVisible: 5 });
    assert.equal(raws.bar.activities, undefined);
});

test('a target domain that has no file keeps the source for a later run', () => {
    const raws = { bar: { activities: { maxVisible: 3 } }, notch: null };
    assert.deepEqual(plain(validator.migrateAliases(raws, ALIASES)), []);
    assert.deepEqual(plain(raws.bar.activities), { maxVisible: 3 });
});

test('a throwing transform keeps the target untouched', () => {
    const raws = { theme: { oldName: 'x' } };
    const bad = [{ from: 'theme.oldName', to: 'theme.newName', transform: () => { throw new Error('no'); } }];
    assert.deepEqual(plain(validator.migrateAliases(raws, bad)), ['theme']);
    assert.deepEqual(plain(raws.theme), {});
});

test('domains lists every domain an alias reads or writes', () => {
    assert.deepEqual(plain(KeyAliases.domains(ALIASES)).sort(), ['bar', 'glass', 'notch', 'theme']);
});

test('the real alias table is well formed', () => {
    const seen = new Set();
    for (const a of KeyAliases.aliases) {
        assert.match(a.from, /^\w+(\.\w+)+$/, a.from);
        assert.match(a.to, /^\w+(\.\w+)+$/, a.to);
        assert.notEqual(a.from, a.to);
        assert.ok(!seen.has(a.from), `${a.from} aliased twice`);
        seen.add(a.from);
        if (a.transform !== undefined)
            assert.equal(typeof a.transform, 'function', a.from);
    }
});
