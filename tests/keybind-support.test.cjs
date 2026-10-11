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

test('only Hyprland can hold binds off while recording', () => {
    assert.strictEqual(S.canSuppress('hyprland'), true);
    assert.strictEqual(S.canSuppress('niri'), false);
    assert.strictEqual(S.canSuppress('mango'), false);
    assert.strictEqual(S.canSuppress(''), false);
});

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

test('manual key entry is normalized and validated', () => {
    const Keys = loadLibrary(path.join(repo, 'modules/keybinds/KeyNames.js'));
    const parse = (t, m) => plain(Keys.parseKeyText(t, m));
    assert.deepStrictEqual(parse('e', ['SUPER']), { mods: ['SUPER'], key: 'E' });
    assert.deepStrictEqual(parse('enter'), { mods: [], key: 'Return' });
    assert.deepStrictEqual(parse('f5'), { mods: [], key: 'F5' });
    assert.deepStrictEqual(parse('Super+Shift+e'), { mods: ['SUPER', 'SHIFT'], key: 'E' });
    assert.deepStrictEqual(parse('.'), { mods: [], key: 'PERIOD' });
    assert.deepStrictEqual(parse('xf86audioplay'), { mods: [], key: 'XF86AudioPlay' });
    assert.deepStrictEqual(parse('super'), { mods: [], key: 'Super_L' });
    assert.strictEqual(parse('').error, 'empty');
    assert.strictEqual(parse('ctrl e x').error, 'key');
    assert.strictEqual(parse('foo+e').error, 'mod');
    assert.strictEqual(parse('é').error, 'key');
});
