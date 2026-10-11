const assert = require('node:assert/strict');
const { test } = require('node:test');
const { loadLibrary } = require('./lib/qmljs.cjs');
const M = loadLibrary('modules/aicenter/composer/Mentions.js');

test('a mention is the @token ending at the cursor', () => {
    assert.deepEqual(JSON.parse(JSON.stringify(M.activeMention('look at @src/ma', 15))), { start: 8, end: 15, query: 'src/ma' });
    assert.deepEqual(JSON.parse(JSON.stringify(M.activeMention('@', 1))), { start: 0, end: 1, query: '' });
    assert.equal(M.activeMention('mail me@example.com', 19), null, 'an @ inside a word is not a mention');
    assert.equal(M.activeMention('see @file and more', 18), null, 'a closed token is not active');
    assert.equal(M.activeMention('see @file and more', 9).query, 'file', 'only text before the cursor counts');
});

test('accepting replaces the token and moves the cursor behind it', () => {
    const m = M.activeMention('check @ma please', 9);
    assert.deepEqual({ ...M.accept('check @ma please', m, 'src/main.go') }, { text: 'check @src/main.go please', cursor: 19 });
    const end = M.activeMention('check @ma', 9);
    assert.deepEqual({ ...M.accept('check @ma', end, 'a.go') }, { text: 'check @a.go ', cursor: 12 });
});

test('paths are shown relative to the project', () => {
    assert.equal(M.relative('/home/u/p/src/a.go', '/home/u/p'), 'src/a.go');
    assert.equal(M.relative('/etc/hosts', '/home/u/p'), '/etc/hosts');
});

test('paste: text wins, copied files attach, a bare image attaches', () => {
    assert.equal(M.pasteKind(['text/html', 'text/plain;charset=utf-8', 'image/png']), 'text');
    assert.equal(M.pasteKind(['text/uri-list', 'x-special/gnome-copied-files']), 'files');
    assert.equal(M.pasteKind(['image/png']), 'image');
    assert.equal(M.pasteKind([]), 'none');
});

test('file URIs decode into paths', () => {
    assert.deepEqual(JSON.parse(JSON.stringify(M.uriPaths('file:///home/u/a%20b.png\nhttps://x\n'))), ['/home/u/a b.png']);
});
