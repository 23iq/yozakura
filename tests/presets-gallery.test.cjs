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

const parts = {
    layouts: [{ kind: 'layout', name: 'Classic', official: true, look: { b: 2 } }, { kind: 'layout', name: 'Ma', official: true, active: true }],
    styles: [{ kind: 'style', name: 'Kaze', description: 'Wind', tags: ['calm'], official: true }],
    palettes: [],
    current: { layout: 'Ma', style: 'Kaze', palette: '' },
};

test('tabs are Sets | Layout | Style | Palette', () => {
    assert.deepEqual(plain(G.ids()), ['sets', 'layout', 'style', 'palette']);
    for (const t of G.TABS)
        assert.ok(t.labelKey.startsWith('presets.tab.'), t.id);
});

test('part cards apply and preview only their part', () => {
    const c = plain(G.cards('layout', { presets, parts }, ''));
    assert.deepEqual(c.map((x) => x.key), ['layout:Classic', 'layout:Ma']);
    assert.deepEqual(c[0].apply, ['apply', '--part', 'layout', 'Classic']);
    assert.deepEqual(c[0].preview, ['apply', '--part', 'layout', '--preview', 'Classic']);
    assert.equal(c[0].look.b, 2);
    assert.equal(c[0].editable, false, 'parts are never renamed or deleted here');
    assert.equal(G.startIndex(c), 1, 'starts on the current part');
    const s = plain(G.cards('style', { parts }, 'calm'));
    assert.equal(s.length, 1);
    assert.equal(s[0].active, true, 'the current part is active');
    assert.deepEqual(s[0].preview, ['apply', '--part', 'style', '--preview', 'Kaze']);
    assert.deepEqual(plain(G.cards('palette', { parts }, '')), []);
    assert.deepEqual(plain(G.cards('style', { presets }, '')), [], 'no parts loaded yet');
});

test('only user sets are editable', () => {
    const c = plain(G.cards('sets', { presets }, ''));
    assert.deepEqual(c.map((x) => x.editable), [false, false, true]);
    assert.equal(c[2].name, 'Mine');
});

test('current row text', () => {
    assert.equal(G.currentText(parts, 'Custom'), 'Ma · Kaze · Custom');
    assert.equal(G.currentText(null, 'Custom'), 'Custom · Custom · Custom');
    assert.equal(G.currentText({ current: { layout: 'Yozakura', style: 'Sakura', palette: 'Plum' } }), 'Yozakura · Sakura · Plum');
});

test('save, rename and delete argv', () => {
    assert.deepEqual(plain(G.saveArgs('My look')), ['save', 'My look']);
    assert.deepEqual(plain(G.renameArgs('Mine', 'Ours')), ['rename', 'Mine', 'Ours']);
    assert.deepEqual(plain(G.deleteArgs('Mine')), ['delete', 'Mine']);
});
