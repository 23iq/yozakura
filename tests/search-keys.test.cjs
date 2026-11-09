// Key routing of the kit SearchField (modules/components/kit/SearchKeys.js).
const { test } = require('node:test');
const assert = require('node:assert/strict');
const path = require('node:path');
const { loadLibrary } = require('./lib/qmljs.cjs');

const K = loadLibrary(path.join(__dirname, '../modules/components/kit/SearchKeys.js'));
const key = K.KEY;
const mid = { empty: false, atStart: false, atEnd: false };

test('enter accepts, shift+enter is the secondary accept', () => {
    assert.equal(K.action(key.Return, 0, mid), 'accepted');
    assert.equal(K.action(key.Enter, 0, mid), 'accepted');
    assert.equal(K.action(key.Return, K.SHIFT, mid), 'shiftAccepted');
});

test('backspace navigates back only on an empty field', () => {
    assert.equal(K.action(key.Backspace, 0, { empty: true }), 'backspaceOnEmpty');
    assert.equal(K.action(key.Backspace, 0, mid), '');
});

test('tab is captured only with tab navigation', () => {
    assert.equal(K.action(key.Tab, 0, mid), '');
    assert.equal(K.action(key.Tab, 0, { tabNav: true }), 'tabPressed');
    assert.equal(K.action(key.Tab, K.SHIFT, { tabNav: true }), 'shiftTabPressed');
    assert.equal(K.action(key.Backtab, 0, { tabNav: true }), 'shiftTabPressed');
});

test('left / right leave the text only at its edges (or always with freeCursor)', () => {
    assert.equal(K.action(key.Left, 0, mid), '');
    assert.equal(K.action(key.Right, 0, mid), '');
    assert.equal(K.action(key.Left, 0, { atStart: true }), 'leftPressed');
    assert.equal(K.action(key.Right, 0, { atEnd: true }), 'rightPressed');
    assert.equal(K.action(key.Left, 0, { empty: true }), 'leftPressed');
    assert.equal(K.action(key.Right, 0, { ...mid, freeCursor: true }), 'rightPressed');
});

test('ctrl shortcuts win over the plain arrows', () => {
    assert.equal(K.action(key.R, K.CTRL, mid), 'ctrlRPressed');
    assert.equal(K.action(key.P, K.CTRL, mid), 'ctrlPPressed');
    assert.equal(K.action(key.Up, K.CTRL, mid), 'ctrlUpPressed');
    assert.equal(K.action(key.Down, K.CTRL, mid), 'ctrlDownPressed');
    assert.equal(K.action(key.R, 0, mid), '', 'plain letters are typed');
});

test('navigation keys always emit', () => {
    const plain = { Escape: 'escapePressed', Up: 'upPressed', Down: 'downPressed', PageUp: 'pageUpPressed',
                    PageDown: 'pageDownPressed' };
    for (const [name, sig] of Object.entries(plain))
        assert.equal(K.action(key[name], 0, mid), sig, name);
    assert.equal(K.action(0x41, 0, mid), '', 'letters are typed');
    assert.equal(K.action(key.Escape, 0), 'escapePressed', 'no context');
});

test('home / end move the cursor unless the field opts in (handleHomeEnd)', () => {
    assert.equal(K.action(key.Home, 0, mid), '', 'home stays in the text');
    assert.equal(K.action(key.End, 0, mid), '', 'end stays in the text');
    assert.equal(K.action(key.Home, 0), '', 'no context');
    assert.equal(K.action(key.Home, 0, { homeEnd: true }), 'homePressed');
    assert.equal(K.action(key.End, 0, { homeEnd: true }), 'endPressed');
});
