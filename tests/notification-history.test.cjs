// Saved notification history (modules/services/NotificationHistory.js):
// compact JSON with the fields the loader reads, at most 5 per app + summary.
const { test } = require('node:test');
const assert = require('node:assert/strict');
const path = require('node:path');
const { loadLibrary } = require('./lib/qmljs.cjs');

const H = loadLibrary(path.join(__dirname, '../modules/services/NotificationHistory.js'));

function notif(id, appName, summary, time) {
    return {
        id, appName, summary, time, actions: [], appIcon: 'icon', desktopEntry: '', body: 'b' + id,
        image: '', urgency: 'normal', historyPriority: 0, replaceKey: '', actionData: {},
        cachedAppIcon: '', cachedImage: '', isCached: false, popup: true, timer: {}
    };
}

test('compact JSON with the saved fields only', () => {
    const text = H.serialize([notif(1, 'App', 'Hi', 10)]);
    assert.ok(!text.includes('\n'), 'no indentation');
    const [saved] = JSON.parse(text);
    assert.deepEqual(Object.keys(saved).sort(), ['actionData', 'actions', 'appIcon', 'appName', 'body',
        'cachedAppIcon', 'cachedImage', 'desktopEntry', 'historyPriority', 'id', 'image', 'isCached',
        'replaceKey', 'summary', 'time', 'urgency']);
    assert.equal(saved.id, 1);
    assert.equal(saved.body, 'b1');
});

test('keeps the newest 5 per app + summary', () => {
    const list = [];
    for (let i = 0; i < 8; i++) list.push(notif(i, 'Chat', 'Msg', i));
    list.push(notif(100, 'Chat', 'Other', 1), notif(101, 'Mail', 'Msg', 1));
    const saved = JSON.parse(H.serialize(list));
    assert.deepEqual(saved.filter(n => n.summary === 'Msg' && n.appName === 'Chat').map(n => n.id), [7, 6, 5, 4, 3]);
    assert.deepEqual(saved.filter(n => n.id >= 100).map(n => n.id).sort(), [100, 101]);
});

test('the input list is not reordered', () => {
    const list = [notif(1, 'A', 's', 1), notif(2, 'A', 's', 2)];
    H.serialize(list);
    assert.deepEqual(list.map(n => n.id), [1, 2]);
});

// merge(): the saved history goes under the live notifications, never over.
const plain = v => JSON.parse(JSON.stringify(v));
const saved = (id, summary, time) => ({ id, summary, time: time ?? id, appName: 'Mail' });
const ids = m => plain(m.entries.map(e => e.id));

test('merge without live notifications keeps the saved ids and moves the offset above them', () => {
    const m = H.merge([saved(5, 'a'), saved(9, 'b'), saved(-1000003, 'own')], [], 0, 1, false);
    assert.deepEqual(ids(m), [5, 9, -1000003]);
    assert.equal(m.idOffset, 10);
    assert.equal(m.internalIdCounter, 4, 'the next internal id is past the saved ones');
});

test('merge skips a live notification read back and keeps colliding history apart', () => {
    const live = [{ id: -1000001, summary: 'startup', time: 50 }];
    const m = H.merge([saved(-1000001, 'startup', 50), saved(-1000001, 'old own', 3), saved(4, 'a')], live, 0, 2, false);
    assert.deepEqual(plain(m.entries.map(e => e.json.summary)), ['old own', 'a'], 'the live one is not loaded twice');
    assert.deepEqual(ids(m), [-1000002, 4], 'an old internal id taken by a live one gets a new one');
    assert.equal(m.internalIdCounter, 3);
    assert.equal(m.idOffset, 5);
});

test('merge under live server notifications never moves the offset', () => {
    const live = [{ id: 1, summary: 'chat', time: 100 }, { id: 2, summary: 'mail', time: 101 }];
    const m = H.merge([saved(1, 'old 1'), saved(2, 'mail', 101), saved(9, 'old 9'), saved(-1, 'moved before')], live, 0, 1, true);
    assert.equal(m.idOffset, 0, 'server notification ids stay server id + idOffset');
    assert.deepEqual(plain(m.entries.map(e => e.json.summary)), ['old 1', 'old 9', 'moved before']);
    const got = ids(m);
    assert.ok(got.every(id => id < 0 && id > -1000000), `saved ids move below every server id: ${got}`);
    assert.equal(new Set(got.concat([1, 2])).size, 5, 'all ids distinct');
    assert.equal(got[2], -1, 'an id no server id can reach is kept');
});

test('merge ignores entries that are not notifications and duplicate ids', () => {
    const m = H.merge([null, 3, 'x', saved(7, 'a'), saved(7, 'b'), { summary: 'no id' }], [], 0, 1, false);
    const got = ids(m);
    assert.equal(got.length, 3);
    assert.equal(got[0], 7);
    assert.equal(new Set(got).size, 3, `distinct ids: ${got}`);
    assert.equal(m.idOffset, 8);
    assert.deepEqual(ids(H.merge('not a list', [], 0, 1, false)), []);
});
