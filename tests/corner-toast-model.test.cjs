const { test } = require('node:test');
const assert = require('node:assert/strict');
const path = require('node:path');
const { loadLibrary } = require('./lib/qmljs.cjs');
const M = loadLibrary(path.join(__dirname, '../modules/notifications/ToastModel.js'));

test('latest skips empty notifications and picks the newest', () => {
    const list = [{ summary: 'a', time: 1 }, { summary: '', body: '', time: 9 }, { body: 'b', time: 5 }, null];
    assert.equal(M.latest(list).body, 'b');
    assert.equal(M.latest([]), null);
    assert.equal(M.visible(list).length, 2);
});
test('the stack behind a group is at most two sheets deep', () => {
    assert.equal(M.stackDepth(1), 0);
    assert.equal(M.stackDepth(2), 1);
    assert.equal(M.stackDepth(3), 2);
    assert.equal(M.stackDepth(9), 2);
    assert.equal(M.stackDepth(0), 0);
});
test('critical urgency in enum and string forms', () => {
    assert.equal(M.isCritical(2), true);
    assert.equal(M.isCritical('2'), true);
    assert.equal(M.isCritical('critical'), true);
    assert.equal(M.isCritical(1), false);
    assert.equal(M.isCritical('normal'), false);
});
test('progress comes from the value hint of the live notification', () => {
    assert.equal(M.progressOf({ notification: { hints: { value: 35 } } }), 0.35);
    assert.equal(M.progressOf({ hints: { value: '100' } }), 1);
    assert.equal(M.progressOf({ notification: { hints: {} } }), -1);
    assert.equal(M.progressOf(null), -1);
});
test('caption joins app, group count and time', () => {
    assert.equal(M.caption('Firefox', '2m', 0), 'Firefox · 2m');
    assert.equal(M.caption('Firefox', '2m', 2), 'Firefox +2 · 2m');
    assert.equal(M.caption('', 'Now', 0), 'Now');
    assert.equal(M.caption('Mail', '', 1), 'Mail +1');
});
test('actions: none for cached notifications, empty labels dropped', () => {
    const n = { actions: [{ identifier: 'open', text: 'Open' }, { identifier: 'x', text: '' }] };
    assert.deepEqual([...M.actionsOf(n).map(a => a.identifier)], ['open']);
    assert.equal(M.actionsOf({ ...n, isCached: true }).length, 0);
    assert.equal(M.actionsOf(null).length, 0);
});
test('art: the image (round) before the app icon (square)', () => {
    assert.deepEqual({ ...M.artOf({ image: '/tmp/a.png', appIcon: 'firefox' }) }, { source: 'file:///tmp/a.png', round: true });
    assert.deepEqual({ ...M.artOf({ appIcon: 'firefox' }) }, { source: 'image://icon/firefox', round: false });
    assert.equal(M.artOf({ appIcon: '/usr/share/icons/x.png' }).source, 'file:///usr/share/icons/x.png');
    assert.equal(M.artOf({ cachedImage: 'data:image/png;base64,AA' }).source, 'data:image/png;base64,AA');
    assert.equal(M.artOf({}).source, '');
});
