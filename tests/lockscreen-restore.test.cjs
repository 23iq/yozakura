// The lock marker that survives a shell restart (LockRestore.js, used by
// LockStateMarker.qml; QML behaviour: tests/lockscreen-marker.test.py).
const { test } = require('node:test');
const assert = require('node:assert/strict');
const path = require('node:path');
const qmljs = require('./lib/qmljs.cjs');

const restore = qmljs.loadLibrary(path.join(__dirname, '../modules/lockscreen/LockRestore.js'));

test('no marker path without a real runtime dir', () => {
    assert.equal(restore.markerPath('', '/tmp/yozakura-locked'), '');
    assert.equal(restore.markerPath(undefined, '/tmp/yozakura-locked'), '');
    assert.equal(restore.markerPath('/run/user/1000', '/run/user/1000/yozakura-locked'), '/run/user/1000/yozakura-locked');
});

test('only a marker for this display locks again', () => {
    const id = restore.identity('wayland-1');
    assert.equal(id, 'locked display=wayland-1');
    assert.ok(restore.shouldRestore(id + '\n', id), 'marker as written (trailing newline)');
    assert.ok(!restore.shouldRestore('', id), 'no marker (clean start, after an unlock)');
    assert.ok(!restore.shouldRestore('   \n', id), 'empty marker');
    assert.ok(!restore.shouldRestore(restore.identity('wayland-2'), id), 'another session in the same runtime dir');
    assert.ok(!restore.shouldRestore('garbage', 'garbage'), 'content without the marker prefix');
    assert.ok(!restore.shouldRestore(null, id));
    assert.ok(!restore.shouldRestore(id, null));
});

test('marker operations follow the lock and never skip an unknown state', () => {
    assert.equal(restore.nextOp(true, 'unknown'), 'write');
    assert.equal(restore.nextOp(true, 'absent'), 'write');
    assert.equal(restore.nextOp(true, 'present'), '');
    assert.equal(restore.nextOp(false, 'present'), 'remove');
    assert.equal(restore.nextOp(false, 'unknown'), 'remove', 'a failed write is still removed on unlock');
    assert.equal(restore.nextOp(false, 'absent'), '');
});
