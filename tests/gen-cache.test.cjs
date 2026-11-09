const { test } = require('node:test');
const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');
const qmljs = require('./lib/qmljs.cjs');

const G = qmljs.loadLibrary(path.join(__dirname, '../modules/theme/GenCache.js'));
const plain = v => JSON.parse(JSON.stringify(v));
const NOW = 1_700_000_000_000;
const inputs = { palette: '{"primary":"#ff0000"}', oled: false, terminal: [true, 12, 'beam', true] };

test('the fingerprint is stable across key order and changes with any input', () => {
    const a = G.fingerprint(inputs);
    assert.match(a, /^[0-9a-f]{16}$/);
    assert.equal(G.fingerprint({ terminal: [true, 12, 'beam', true], oled: false, palette: '{"primary":"#ff0000"}' }), a);
    assert.notEqual(G.fingerprint({ ...inputs, oled: true }), a);
    assert.notEqual(G.fingerprint({ ...inputs, palette: '{"primary":"#ff0001"}' }), a);
    assert.notEqual(G.fingerprint({ ...inputs, terminal: [true, 13, 'beam', true] }), a);
    assert.notEqual(G.hash('ab'), G.hash('ba'));
});

test('a first run (no record) runs everything and records it', () => {
    const names = ['pywalGenerator', 'kittyGenerator'];
    const fp = G.fingerprint(inputs);
    const stored = G.parse('');
    const p = G.plan(stored, names, fp, false, NOW);
    assert.deepEqual(plain(p), { run: names, skip: [] });
    const rec = G.record(stored, p.run, fp, NOW);
    // Unchanged inputs: skipped; serialize/parse round-trips
    const again = G.parse(G.serialize(rec));
    assert.deepEqual(plain(G.plan(again, names, fp, false, NOW + 1000)), { run: [], skip: names });
});

test('changed inputs, a new generator, force, an old or future record all run', () => {
    const fp = G.fingerprint(inputs);
    const rec = G.record(G.parse(''), ['pywalGenerator', 'kittyGenerator'], fp, NOW);
    const other = G.fingerprint({ ...inputs, oled: true });
    assert.deepEqual(plain(G.plan(rec, ['pywalGenerator'], other, false, NOW)).run, ['pywalGenerator']);
    assert.deepEqual(plain(G.plan(rec, ['pywalGenerator', 'gtkGenerator'], fp, false, NOW)), { run: ['gtkGenerator'], skip: ['pywalGenerator'] });
    assert.deepEqual(plain(G.plan(rec, ['pywalGenerator'], fp, true, NOW)).run, ['pywalGenerator']);
    assert.deepEqual(plain(G.plan(rec, ['pywalGenerator'], fp, false, NOW + G.MAX_AGE_MS)).run, ['pywalGenerator']);
    assert.deepEqual(plain(G.plan(rec, ['pywalGenerator'], fp, false, NOW - 1)).run, ['pywalGenerator'], 'clock went back');
});

test('record keeps other generators and parse drops foreign or broken files', () => {
    const fp = G.fingerprint(inputs);
    const a = G.record(G.parse(''), ['pywalGenerator'], fp, NOW);
    const b = G.record(a, ['kittyGenerator'], 'other', NOW + 5);
    assert.equal(b.generators.pywalGenerator.fp, fp);
    assert.equal(b.generators.kittyGenerator.fp, 'other');
    assert.equal(a.generators.kittyGenerator, undefined, 'record does not mutate its input');
    assert.deepEqual(plain(G.parse('not json').generators), {});
    assert.deepEqual(plain(G.parse(JSON.stringify({ version: G.VERSION + 1, generators: { x: { fp, at: NOW } } })).generators), {});
    assert.deepEqual(plain(G.parse('null').generators), {});
});

test('Colors.qml routes both generator timers through the cache', () => {
    const qml = fs.readFileSync(path.join(__dirname, '../modules/theme/Colors.qml'), 'utf8');
    assert.equal((qml.match(/generatorCache\.take\(/g) || []).length, 2);
    assert.match(qml, /function regenerateApps\(\) \{\n\s*colors\._forceGeneration = true;/);
});
