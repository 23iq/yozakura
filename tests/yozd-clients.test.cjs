// Identity-preserving client diff (modules/services/YozdClients.js).
const { test } = require('node:test');
const assert = require('node:assert/strict');
const path = require('node:path');
const { loadLibrary } = require('./lib/qmljs.cjs');

const C = loadLibrary(path.join(__dirname, '..', 'modules/services/YozdClients.js'));

function win(id, over = {}) {
    return {
        id, app_id: 'kitty', title: `t${id}`, workspace_id: '2', is_focused: false,
        is_floating: false, is_fullscreen: false, is_hidden: false,
        metadata: { monitor_id: '1', x: 10, y: 20, width: 300, height: 200 },
        ...over,
    };
}

test('maps yozd windows to client objects', () => {
    const r = C.merge([], [win('0xa', { is_focused: true, metadata: { is_urgent: true, xwayland: true } })], 0);
    const c = r.values[0];
    assert.equal(r.changed, true);
    assert.equal(c.address, '0xa');
    assert.equal(c.class, 'kitty');
    assert.deepEqual(JSON.parse(JSON.stringify(c.workspace)), { id: 2, name: '2' });
    assert.equal(c.urgent, true);
    assert.equal(c.xwayland, true);
    assert.equal(c.is_focused, true);
    assert.equal(c.focusHistoryID, -1);
    assert.equal(r.counter, -1);
});

test('identical snapshot returns the previous list untouched', () => {
    const first = C.merge([], [win('0xa', { is_focused: true }), win('0xb')], 0);
    const again = C.merge(first.values, [win('0xa', { is_focused: true }), win('0xb')], first.counter);
    assert.equal(again.changed, false);
    assert.equal(again.values, first.values);
    assert.equal(again.counter, first.counter);
});

test('only the changed client gets a new object', () => {
    const first = C.merge([], [win('0xa'), win('0xb'), win('0xc')], 0);
    const next = C.merge(first.values, [win('0xa'), win('0xb', { title: 'new' }), win('0xc')], first.counter);
    assert.equal(next.changed, true);
    assert.equal(next.values[0], first.values[0]);
    assert.notEqual(next.values[1], first.values[1]);
    assert.equal(next.values[1].title, 'new');
    assert.equal(next.values[2], first.values[2]);
});

test('geometry changes are detected', () => {
    const first = C.merge([], [win('0xa')], 0);
    const moved = C.merge(first.values, [win('0xa', { metadata: { monitor_id: '1', x: 11, y: 20, width: 300, height: 200 } })], 0);
    assert.equal(moved.changed, true);
    assert.equal(moved.values[0].at[0], 11);
});

test('reorder, removal and addition mark the list changed but keep objects', () => {
    const first = C.merge([], [win('0xa'), win('0xb')], 0);
    const swapped = C.merge(first.values, [win('0xb'), win('0xa')], 0);
    assert.equal(swapped.changed, true);
    assert.equal(swapped.values[0], first.values[1]);
    assert.equal(swapped.values[1], first.values[0]);
    const removed = C.merge(first.values, [win('0xa')], 0);
    assert.equal(removed.changed, true);
    assert.equal(removed.values[0], first.values[0]);
    const added = C.merge(first.values, [win('0xa'), win('0xb'), win('0xc')], 0);
    assert.equal(added.changed, true);
    assert.equal(added.values.length, 3);
});

test('focus history: a newly focused client gets the next lower id, staying focused keeps it', () => {
    let r = C.merge([], [win('0xa', { is_focused: true }), win('0xb')], 0);
    assert.equal(r.values[0].focusHistoryID, -1);
    assert.equal(r.values[1].focusHistoryID, 999999);
    r = C.merge(r.values, [win('0xa'), win('0xb', { is_focused: true })], r.counter);
    assert.equal(r.values[0].focusHistoryID, -1);
    assert.equal(r.values[1].focusHistoryID, -2);
    const kept = C.merge(r.values, [win('0xa'), win('0xb', { is_focused: true })], r.counter);
    assert.equal(kept.changed, false);
    assert.equal(kept.counter, -2);
});
