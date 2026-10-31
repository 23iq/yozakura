// Pure helpers of the active preset status (modules/settings/presets/PresetStatusModel.js).
const { test } = require('node:test');
const assert = require('node:assert/strict');
const path = require('node:path');

const qmljs = require('./lib/qmljs.cjs');
const repo = path.join(__dirname, '..');
const M = qmljs.loadLibrary(path.join(repo, 'modules/settings/presets/PresetStatusModel.js'));
const plain = v => JSON.parse(JSON.stringify(v));

test('primary action follows ownership and changes', () => {
    assert.equal(M.primaryAction(null), '');
    assert.equal(M.primaryAction({ active: '', changed: 3 }), '');
    assert.equal(M.primaryAction({ active: 'Mine', owned: true, changed: 0 }), '');
    assert.equal(M.primaryAction({ active: 'Mine', owned: true, changed: 2 }), 'save');
    assert.equal(M.primaryAction({ active: 'Night', official: true, owned: false, changed: 1 }), 'saveAs');
    assert.equal(M.primaryAction({ active: 'Mine', owned: true, changed: 2, session: 'try' }), '', 'a trial owns the live config');
});

test('a changed key finds its closest settings entry', () => {
    const index = [
        { key: 'theme.roundness', entryId: 'theme.roundness', label: 'Roundness', context: 'Look' },
        { key: 'bar', entryId: 'bar', label: 'Bar' },
        { key: 'bar.panels', entryId: 'bar.panels', label: 'Panels' },
        { label: 'A page', categoryId: 'x' },
    ];
    assert.equal(M.entryFor(index, 'theme.roundness').label, 'Roundness');
    assert.equal(M.entryFor(index, 'bar.panels.0.edge').label, 'Panels', 'the longest enclosing key wins');
    assert.equal(M.entryFor(index, 'theme.roundnessX'), null, 'a prefix must end at a dot');
    assert.equal(M.entryFor(index, 'dock.size'), null);
});

test('values and keys read well', () => {
    assert.equal(M.valueText(true, 'On', 'Off'), 'On');
    assert.equal(M.valueText(false, 'On', 'Off'), 'Off');
    assert.equal(M.valueText(7), '7');
    assert.equal(M.valueText('glass'), 'glass');
    assert.equal(M.valueText(undefined), '—');
    assert.ok(M.valueText({ a: 'x'.repeat(60) }).endsWith('…'));
    assert.equal(M.humanKey('theme.blurRadius'), 'Theme · Blur radius');
});

test('rows pair the live and preset values', () => {
    const rows = plain(M.rows({ changes: [{ key: 'theme.roundness', a: 7, b: 3 }, { key: 'dock.iconSize', a: 48, b: 40 }] },
        [{ key: 'theme.roundness', entryId: 'theme.roundness', label: 'Roundness', context: 'Look' }], 'On', 'Off'));
    assert.equal(rows.length, 2);
    assert.deepEqual([rows[0].title, rows[0].now, rows[0].preset, rows[0].context], ['Roundness', '7', '3', 'Look']);
    assert.equal(rows[1].title, 'Dock · Icon size');
    assert.equal(rows[1].entry, null);
});
