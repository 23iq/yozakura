const { test } = require('node:test');
const assert = require('node:assert/strict');
const path = require('node:path');
const { loadLibrary } = require('./lib/qmljs.cjs');
const W = loadLibrary(path.join(__dirname, '../modules/services/WorkspaceDismiss.js'));

// The library runs in its own realm: compare plain copies.
const plain = (o) => JSON.parse(JSON.stringify(o));
const mon = (id) => ({ name: 'A', activeWorkspace: { id: id, name: String(id) } });

test('place reads the active workspace of the monitor', () => {
    assert.deepEqual(plain(W.place('A', mon(2))), { screen: 'A', workspace: '2' });
    assert.deepEqual(plain(W.place('A', null)), { screen: 'A', workspace: '' });
    assert.deepEqual(plain(W.place('A', { activeWorkspace: { id: 0, name: '' } })), { screen: 'A', workspace: '' });
    assert.deepEqual(plain(W.place('', mon(1))), { screen: '', workspace: '1' });
    // niri named workspaces without a numeric id
    assert.deepEqual(plain(W.place('A', { activeWorkspace: { id: 0, name: 'dev' } })), { screen: 'A', workspace: 'dev' });
});

test('a workspace switch on the same screen dismisses the open module', () => {
    assert.equal(W.shouldDismiss(W.place('A', mon(1)), W.place('A', mon(2)), 'launcher'), true);
    assert.equal(W.shouldDismiss(W.place('A', mon(1)), W.place('A', mon(2)), 'dashboard'), true);
});

test('no dismiss without a module, for overview, or for the same workspace', () => {
    assert.equal(W.shouldDismiss(W.place('A', mon(1)), W.place('A', mon(2)), ''), false);
    assert.equal(W.shouldDismiss(W.place('A', mon(1)), W.place('A', mon(2)), 'overview'), false);
    assert.equal(W.shouldDismiss(W.place('A', mon(1)), W.place('A', mon(1)), 'launcher'), false);
});

test('a screen change or unknown workspace never dismisses', () => {
    assert.equal(W.shouldDismiss(W.place('A', mon(1)), W.place('B', mon(2)), 'launcher'), false);
    assert.equal(W.shouldDismiss(W.place('A', null), W.place('A', mon(2)), 'launcher'), false);
    assert.equal(W.shouldDismiss(W.place('A', mon(1)), W.place('A', null), 'launcher'), false);
    assert.equal(W.shouldDismiss(null, W.place('A', mon(2)), 'launcher'), false);
});
