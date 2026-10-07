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

test('an unreadable target domain keeps the raw source untouched', () => {
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

test('a transform that returns undefined drops the old key without writing', () => {
    const raws = { notch: { osd: false }, layout: { osd: { style: 'pill' } } };
    const list = [{ from: 'notch.osd', to: 'layout.osd.style', transform: v => (v ? 'island' : undefined), replaces: ['pill'] }];
    assert.deepEqual(plain(validator.migrateAliases(raws, list)), ['notch']);
    assert.deepEqual(plain(raws), { notch: {}, layout: { osd: { style: 'pill' } } });
});

test('`replaces` lets a value overwrite a target still at its default', () => {
    const list = [{ from: 'notch.osd', to: 'layout.osd.style', transform: v => (v ? 'island' : undefined), replaces: ['pill'] }];
    const raws = { notch: { osd: true }, layout: { osd: { style: 'pill' } } };
    validator.migrateAliases(raws, list);
    assert.equal(raws.layout.osd.style, 'island');
    const custom = { notch: { osd: true }, layout: { osd: { style: 'corner' } } };
    validator.migrateAliases(custom, list);
    assert.equal(custom.layout.osd.style, 'corner');
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

test('real aliases: live activities, island OSD, glass blur and shadow', () => {
    const raws = {
        bar: { activities: { enabled: false }, position: 'top' },
        notch: { osd: true },
        layout: { osd: { style: 'pill', timeout: 2500 } },
        theme: { glass: { advanced: { blurSize: 12.4, blurPasses: -1, vibrancy: 0.2, noise: -1, contrast: -1, brightness: 1.2, shadowSoftness: 0.5, opacity: 0.8 } } },
        compositor: { blurSize: 4, blurPasses: 3, blurVibrancy: 0, blurBrightness: 0.9, shadowRange: 8 }
    };
    validator.migrateAliases(raws);
    assert.deepEqual(plain(raws.notch), { liveActivities: { enabled: false } });
    assert.equal(raws.bar.activities, undefined);
    assert.equal(raws.layout.osd.style, 'island');
    assert.deepEqual(plain(raws.theme.glass.advanced), { opacity: 0.8 });
    // set overrides replace untouched defaults; a customised value wins
    assert.deepEqual(plain(raws.compositor), { blurSize: 12, blurPasses: 3, blurVibrancy: 0.2, blurBrightness: 0.9, shadowRange: 12 });
});

test('real aliases: notch.osd off leaves the OSD style alone', () => {
    const raws = { notch: { osd: false }, layout: { osd: { style: 'corner' } } };
    validator.migrateAliases(raws);
    assert.deepEqual(plain(raws), { notch: {}, layout: { osd: { style: 'corner' } } });
});

test('overlay lays migrated values over a document without touching either input', () => {
    const base = { a: { x: 1, y: 2 }, list: [1], keep: true };
    const over = { a: { y: 9 }, list: [2, 3], n: { deep: 1 } };
    assert.deepEqual(plain(validator.overlay(base, over)), { a: { x: 1, y: 9 }, list: [2, 3], keep: true, n: { deep: 1 } });
    assert.deepEqual(base, { a: { x: 1, y: 2 }, list: [1], keep: true });
    assert.deepEqual(over, { a: { y: 9 }, list: [2, 3], n: { deep: 1 } });
});
