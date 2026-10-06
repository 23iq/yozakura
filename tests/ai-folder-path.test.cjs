// Code folder picker helpers (FolderPath.js): path field, crumbs, rows, keys.
const { test } = require('node:test');
const assert = require('node:assert/strict');
const path = require('node:path');
const { loadLibrary } = require('./lib/qmljs.cjs');

const F = loadLibrary(path.join(__dirname, '../modules/aicenter/code/FolderPath.js'));
const HOME = '/home/u';
const plain = (v) => JSON.parse(JSON.stringify(v));

test('tilde, expand and split the path field', () => {
    assert.equal(F.tilde('/home/u/src/', HOME), '~/src');
    assert.equal(F.tilde('/home/user2', HOME), '/home/user2');
    assert.equal(F.expand('~/src/', HOME), '/home/u/src');
    assert.equal(F.expand('src', HOME), '');
    assert.deepEqual(plain(F.split('~/src/yo', HOME)), { dir: '/home/u/src', partial: 'yo' });
    assert.deepEqual(plain(F.split('~/src/', HOME)), { dir: '/home/u/src', partial: '' });
    assert.deepEqual(plain(F.split('~', HOME)), { dir: '/home/u', partial: '' });
    assert.deepEqual(plain(F.split('/et', HOME)), { dir: '/', partial: 'et' });
    assert.deepEqual(plain(F.split('yoza', HOME)), { dir: '', partial: 'yoza' });
    assert.equal(F.browseText('/home/u/src', HOME), '~/src/');
    assert.equal(F.browseText('/', HOME), '/');
    assert.equal(F.parent('/home/u'), '/home');
    assert.equal(F.parent('/home'), '/');
    assert.equal(F.baseName('/home/u/src/'), 'src');
});

test('crumbs start at ~ inside home, at / elsewhere', () => {
    assert.deepEqual(plain(F.crumbs('/home/u/src/x', HOME)).map((c) => c.label), ['~', 'src', 'x']);
    assert.equal(F.crumbs('/home/u/src/x', HOME)[2].path, '/home/u/src/x');
    assert.deepEqual(plain(F.crumbs('/etc/x', HOME)).map((c) => c.path), ['/', '/etc', '/etc/x']);
});

const entries = [
    { name: 'Documents', path: '/home/u/Documents' },
    { name: 'src', path: '/home/u/src' },
    { name: 'yozakura', path: '/home/u/yozakura', git: true },
    { name: 'my-yoz', path: '/home/u/my-yoz' },
    { name: '.config', path: '/home/u/.config', hidden: true },
];
const repos = [
    { name: 'yozakura', path: '/home/u/src/yozakura' },
    { name: 'notes', path: '/home/u/notes' },
    { name: 'tool', path: '/home/u/work/yoz-tools/tool' },
];

test('browse rows: subfolders filtered by the typed name, prefix first, hidden on demand', () => {
    let rows = F.rows({ text: '~/', home: HOME, entries });
    assert.deepEqual(plain(rows.map((r) => r.type)), ['header', 'dir', 'dir', 'dir', 'dir']);
    rows = F.rows({ text: '~/', home: HOME, entries, hidden: true });
    assert.equal(rows.length, 6);
    rows = F.rows({ text: '~/yo', home: HOME, entries });
    assert.deepEqual(plain(rows.filter((r) => r.type === 'dir').map((r) => r.name)), ['yozakura', 'my-yoz']);
    assert.equal(rows[1].git, true);
    rows = F.rows({ text: '~/.co', home: HOME, entries });
    assert.deepEqual(plain(rows.filter((r) => r.type === 'dir').map((r) => r.name)), ['.config']);
    assert.equal(F.rows({ text: '~/zzz', home: HOME, entries }).length, 0);
});

test('search rows: recent folders then repositories, deduplicated', () => {
    const recents = ['/home/u/src/yozakura', '/home/u/other'];
    let rows = F.rows({ text: '', home: HOME, recents, repos });
    assert.deepEqual(plain(rows.map((r) => r.type + ':' + (r.name || r.label))),
        ['header:recent', 'recent:yozakura', 'recent:other', 'header:repos', 'repo:notes', 'repo:tool']);
    assert.equal(rows[1].detail, '~/src');
    rows = F.rows({ text: 'yoz', home: HOME, recents, repos });
    // name matches first, the path-only match (work/yoz-tools) last
    assert.deepEqual(plain(rows.map((r) => r.name || r.label)), ['recent', 'yozakura', 'repos', 'tool']);
});

test('keyboard steps skip headers; the target is the row, else the typed folder', () => {
    const rows = F.rows({ text: '', home: HOME, recents: ['/a'], repos: [{ name: 'b', path: '/b' }] });
    assert.equal(F.first(rows), 1);
    assert.equal(F.step(rows, 1, 1), 3);
    assert.equal(F.step(rows, 3, 1), 3);
    assert.equal(F.step(rows, 3, -1), 1);
    assert.equal(F.step(rows, 1, -1), -1);
    assert.equal(F.target(rows, 3, '', HOME), '/b');
    assert.equal(F.target([], -1, '~/src/', HOME), '/home/u/src');
    assert.equal(F.target([], -1, '~/src/new', HOME), '/home/u/src/new');
    assert.equal(F.target([], -1, '/', HOME), '/');
    assert.equal(F.target([], -1, 'search', HOME), '');
});
