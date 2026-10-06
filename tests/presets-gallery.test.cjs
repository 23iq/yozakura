// GalleryTabs.js: one model per tab, cards carry apply/preview argv.
const { test } = require('node:test');
const assert = require('node:assert/strict');
const path = require('node:path');
const { loadLibrary } = require('./lib/qmljs.cjs');
const G = loadLibrary(path.join(__dirname, '../modules/widgets/presets/GalleryTabs.js'));

const presets = [
    { name: 'Neon Tokyo', description: 'Pink neon', tags: ['dark', 'neon'], active: false, official: true, look: { a: 1 } },
    { name: 'Glacier', description: '', tags: ['light'], active: true, official: true },
    { name: 'Mine', active: false, official: false },
];
const plain = (v) => JSON.parse(JSON.stringify(v));

test('every tab has a model builder', () => {
    for (const id of G.ids())
        assert.equal(typeof G.MODELS[id], 'function', id);
    assert.deepEqual(plain(G.cards('bogus', { presets }, '')), []);
});

test('set cards preview and apply by name', () => {
    const c = plain(G.cards('sets', { presets }, ''));
    assert.equal(c.length, 3);
    assert.deepEqual(c[0].preview, ['apply', '--preview', 'Neon Tokyo']);
    assert.deepEqual(c[0].apply, ['apply', 'Neon Tokyo']);
    assert.equal(c[0].look.a, 1);
    assert.equal(c[2].look, null);
    assert.equal(G.startIndex(c), 1, 'starts on the active preset');
    assert.equal(G.startIndex([]), 0);
});

test('search matches name, description and tags, every word', () => {
    assert.deepEqual(plain(G.cards('sets', { presets }, 'neon')).map((c) => c.title), ['Neon Tokyo']);
    assert.deepEqual(plain(G.cards('sets', { presets }, 'LIGHT')).map((c) => c.title), ['Glacier']);
    assert.deepEqual(plain(G.cards('sets', { presets }, 'pink dark')).map((c) => c.title), ['Neon Tokyo']);
    assert.deepEqual(plain(G.cards('sets', { presets }, 'pink light')), []);
    assert.deepEqual(plain(G.cards('sets', null, '')), []);
});
