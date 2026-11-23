// CompositorSupport: what the compositor can do with binds, native bind
// mapping and the notes for binds the generator left out.
const test = require('node:test');
const assert = require('node:assert');
const path = require('node:path');
const { loadLibrary } = require('./lib/qmljs.cjs');

const repo = path.resolve(__dirname, '..');
const S = loadLibrary(path.join(repo, 'modules/keybinds/CompositorSupport.js'));
const Model = loadLibrary(path.join(repo, 'modules/keybinds/BindModel.js'));
const plain = v => JSON.parse(JSON.stringify(v));

test('native bind source per compositor', () => {
    assert.strictEqual(S.nativeSource('hyprland'), 'hyprctl');
    assert.strictEqual(S.nativeSource('niri'), 'yozd');
    assert.strictEqual(S.nativeSource('mango'), 'yozd');
    assert.strictEqual(S.nativeSource(''), '');
});

test('skipped binds: parsed by combo, duplicates left to the conflict markers', () => {
    const text = JSON.stringify([
        { name: 'a', modifiers: ['SUPER'], key: 'V', reason: 'no release binds' },
        { name: 'b', modifiers: ['SUPER'], key: 'T', reason: 'same key combo as "x"' },
        { name: 'c', modifiers: [], key: '', reason: 'broken' }
    ]);
    const skipped = S.parseSkipped(text);
    assert.deepStrictEqual(Object.keys(plain(skipped)), ['SUPER|v']);
    assert.strictEqual(S.noteFor([{ modifiers: ['super'], key: 'v' }], skipped), 'no release binds');
    assert.strictEqual(S.noteFor([{ modifiers: ['SUPER'], key: 'B' }], skipped), '');
    assert.deepStrictEqual(plain(S.parseSkipped('not json')), {});
});

test('yozd binds feed the native conflict list', () => {
    const native = Model.nativeBinds(S.fromListBinds([
        { modifiers: ['SUPER'], key: 'Q', dispatcher: 'close-window' },
        { modifiers: ['SUPER'], key: 'H', description: 'Hide', mouse: false }
    ]), []);
    assert.strictEqual(native.length, 2);
    assert.strictEqual(native[0].text, 'close-window');
    assert.strictEqual(native[1].text, 'Hide');
});
