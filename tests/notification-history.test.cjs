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
