const { test } = require('node:test');
const assert = require('node:assert/strict');
const path = require('node:path');
const { loadLibrary } = require('./lib/qmljs.cjs');

const V = loadLibrary(path.join(__dirname, '../modules/widgets/dashboard/clipboard/ClipboardView.js'));
const plain = value => JSON.parse(JSON.stringify(value));

test('rows: options count and heights', () => {
    assert.equal(V.optionsCount({ preview: 'hello' }), 4);
    assert.equal(V.optionsCount({ preview: 'https://a.b/c' }), 5);
    assert.equal(V.optionsCount({ isFile: true }), 5);
    assert.equal(V.optionsCount({ isImage: true }), 5);
    assert.equal(V.rowHeight({ preview: 'x' }, false), 48);
    // every option is visible (4 for text, 5 with Open)
    assert.equal(V.rowHeight({ preview: 'x' }, true), 48 + 4 + 144 + 8);
    assert.equal(V.rowHeight({ isFile: true }, true), 48 + 4 + 180 + 8);
});

test('rows: y offsets only grow below an expandable expanded row', () => {
    const at = () => ({ preview: 'x' });
    assert.equal(V.rowY(3, 10, -1, true, at), 144);
    assert.equal(V.rowY(3, 10, 1, true, at), 144 + 156);
    assert.equal(V.rowY(3, 10, 1, false, at), 144);
    assert.equal(V.rowY(3, 10, 5, true, at), 144);
    assert.equal(V.rowY(5, 2, -1, true, at), 96); // clamped to the model
});

test('scrollToShow', () => {
    assert.equal(V.scrollToShow(50, 48, 100, 200), 50);
    assert.equal(V.scrollToShow(120, 48, 100, 200), -1);
    assert.equal(V.scrollToShow(280, 48, 100, 200), 128);
    assert.equal(V.scrollToShow(280, 48, 100, 200, 110), 110);
});

test('filterItems matches content and alias, case-insensitively', () => {
    const items = [{ id: 'a', preview: 'Hello' }, { id: 'b', preview: 'x', alias: 'World' }, { id: 'c' }];
    assert.deepEqual(plain(V.filterItems(items, '').map(i => i.id)), ['a', 'b', 'c']);
    assert.deepEqual(plain(V.filterItems(items, 'hel').map(i => i.id)), ['a']);
    assert.deepEqual(plain(V.filterItems(items, 'WORLD').map(i => i.id)), ['b']);
});

class FakeModel {
    constructor(rows) { this.rows = rows.map(r => ({ ...r })); this.ops = []; }
    get count() { return this.rows.length; }
    get(i) { return this.rows[i]; }
    set(i, v) { this.ops.push('set'); Object.assign(this.rows[i], v); }
    move(from, to, n) { this.ops.push('move'); this.rows.splice(to, 0, ...this.rows.splice(from, n)); }
    insert(i, v) { this.ops.push('insert'); this.rows.splice(i, 0, v); }
    append(v) { this.ops.push('append'); this.rows.push(v); }
    remove(i, n) { this.ops.push('remove'); this.rows.splice(i, n); }
}

test('syncModel reuses, moves, inserts and trims rows', () => {
    const a = { id: 'a' }, b = { id: 'b' }, c = { id: 'c' }, d = { id: 'd' };
    const m = new FakeModel([{ itemId: 'a', itemData: a }, { itemId: 'b', itemData: b }, { itemId: 'c', itemData: c }]);
    V.syncModel(m, [c, a, d]);
    assert.deepEqual(m.rows.map(r => r.itemId), ['c', 'a', 'd']);
    assert.ok(m.rows.every(r => r.itemData.id === r.itemId));
    assert.ok(!m.ops.includes('append') || m.ops.includes('move'));
    const same = new FakeModel([{ itemId: 'a', itemData: a }]);
    V.syncModel(same, [a]);
    assert.deepEqual(same.ops, []);
    V.syncModel(same, []);
    assert.equal(same.count, 0);
});

test('row text, times and metadata', () => {
    const t = (k, n) => n === undefined ? k : `${k}:${n}`;
    assert.equal(V.rowText({ preview: 'a\nb\r' }, false), 'a b');
    assert.equal(V.rowText({ isImage: true }, false), 'Image');
    assert.equal(V.rowText({ preview: 'x'.repeat(30) }, true), `Delete "${'x'.repeat(20)}..."?`);
    const now = new Date(2026, 9, 5, 12, 0, 0);
    assert.equal(V.relativeTime(0, now, t), '');
    assert.equal(V.relativeTime(now.getTime() - 30000, now, t), 'clipboard.just_now');
    assert.equal(V.relativeTime(now.getTime() - 5 * 60000, now, t), 'clipboard.min_ago:5');
    assert.equal(V.relativeTime(now.getTime() - 3 * 3600000, now, t), 'clipboard.hours_ago:3');
    assert.equal(V.relativeTime(now.getTime() - 2 * 86400000, now, t), 'clipboard.days_ago:2');
    assert.equal(V.relativeTime(new Date(2026, 0, 2).getTime(), now, t), 'calendar.month.january 2, 2026');
    assert.equal(V.fullDate(new Date(2026, 1, 3, 0, 5, 9).getTime(), t), 'calendar.month.february 3, 2026 12:05:09 AM');
    assert.equal(V.formatSize(0), '0 B');
    assert.equal(V.formatSize(1536), '1.5 KB');
    assert.equal(V.formatSize(3 * 1024 * 1024), '3.0 MB');
    assert.equal(V.shortHash(''), 'N/A');
    assert.equal(V.shortHash('0123456789abcdef0123'), '01234567...cdef0123');
    assert.equal(V.shortHash('abc'), 'abc');
});

test('file URIs, images and GIFs', () => {
    assert.equal(V.filePathFromUri('file:///home/u/My%20Pic.png'), '/home/u/My Pic.png');
    assert.equal(V.filePathFromUri('/x'), '');
    assert.ok(V.isImagePath('/a/b.JPG'));
    assert.ok(!V.isImagePath('/a/b.txt'));
    assert.ok(V.isGif({ mime: 'image/gif' }, ''));
    assert.ok(V.isGif({ isFile: true }, 'file:///a/b.gif'));
    assert.ok(!V.isGif({ isFile: true }, 'file:///a/b.png'));
    assert.ok(!V.isGif(null, ''));
    assert.equal(V.uriFileName('file:///a/My%20File.txt'), 'My File.txt');
    assert.equal(V.uriDirectory('file:///a/b%20c/d.txt'), '/a/b c');
    assert.equal(V.uriDirectory('nope'), '');
    // (URL parsing itself needs the QML engine's URL; the fallback is pure)
    assert.equal(V.hostLabel('not a url'), 'not a url');
    assert.equal(V.hostLabel('y'.repeat(50)), 'y'.repeat(40) + '...');
});

test('drag MIME data', () => {
    assert.deepEqual(plain(V.dragMimeData(null, 'x', '')), {});
    assert.deepEqual(plain(V.dragMimeData({ isFile: true }, 'file:///a', '')), { 'text/uri-list': 'file:///a' });
    assert.deepEqual(plain(V.dragMimeData({ isImage: true }, '', '/tmp/i.png')), { 'text/uri-list': 'file:///tmp/i.png' });
    assert.deepEqual(plain(V.dragMimeData({ isImage: true }, 'raw', '')), { 'text/plain': 'raw' });
    assert.deepEqual(plain(V.dragMimeData({}, 'hi', '')), { 'text/plain': 'hi' });
});
