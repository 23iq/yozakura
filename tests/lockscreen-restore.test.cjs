// The lock marker that survives a shell restart (LockRestore.js, used by
// LockStateMarker.qml; QML behaviour: tests/lockscreen-marker.test.py).
const { test } = require('node:test');
const assert = require('node:assert/strict');
const path = require('node:path');
const qmljs = require('./lib/qmljs.cjs');

const restore = qmljs.loadLibrary(path.join(__dirname, '../modules/lockscreen/LockRestore.js'));

test('no marker path without a real runtime dir or an instance token', () => {
    const file = '/run/user/1000/yozakura-locked-wayland-1';
    assert.equal(restore.markerPath('', '/tmp/yozakura-locked', 'hyprland:a'), '');
    assert.equal(restore.markerPath(undefined, '/tmp/yozakura-locked', 'hyprland:a'), '');
    assert.equal(restore.markerPath('/run/user/1000', file, ''), '', 'no token: sessions cannot be told apart');
    assert.equal(restore.markerPath('/run/user/1000', file, undefined), '');
    assert.equal(restore.markerPath('/run/user/1000', file, 'hyprland:a'), file);
});

test('one marker file per display', () => {
    assert.equal(restore.fileSuffix('wayland-1'), '-locked-wayland-1');
    assert.equal(restore.fileSuffix('wayland-2'), '-locked-wayland-2');
    assert.equal(restore.fileSuffix('/run/user/1000/wl 0'), '-locked-_run_user_1000_wl_0', 'a path display stays one file name');
    assert.equal(restore.fileSuffix('../x'), '-locked-.._x');
    assert.equal(restore.fileSuffix(''), '');
    assert.equal(restore.fileSuffix(undefined), '');
});

test('the instance token prefers the compositor instance over the login session', () => {
    const his = 'f1e2d3_1700000000_123';
    const niri = '/run/user/1000/niri.wayland-1.4242.sock';
    assert.equal(restore.sessionToken({ HYPRLAND_INSTANCE_SIGNATURE: his, NIRI_SOCKET: niri, XDG_SESSION_ID: '3' }), 'hyprland:' + his);
    assert.equal(restore.sessionToken({ NIRI_SOCKET: niri, XDG_SESSION_ID: '3' }), 'niri:' + niri);
    assert.equal(restore.sessionToken({ XDG_SESSION_ID: '3' }), 'logind:3');
    assert.equal(restore.sessionToken({ HYPRLAND_INSTANCE_SIGNATURE: '  ', XDG_SESSION_ID: '3' }), 'logind:3');
    assert.equal(restore.sessionToken({}), '');
    assert.equal(restore.sessionToken(undefined), '');
});

test('only a marker of this display and compositor instance locks again', () => {
    const id = restore.identity('wayland-1', 'hyprland:a');
    assert.equal(id, 'locked display=wayland-1 session=hyprland:a');
    assert.ok(restore.shouldRestore(id + '\n', id), 'marker as written (trailing newline)');
    assert.ok(!restore.shouldRestore('', id), 'no marker (clean start, after an unlock)');
    assert.ok(!restore.shouldRestore('   \n', id), 'empty marker');
    assert.ok(!restore.shouldRestore(restore.identity('wayland-2', 'hyprland:a'), id), 'another display');
    assert.ok(!restore.shouldRestore(restore.identity('wayland-1', 'hyprland:b'), id), 'a previous login on the same display');
    assert.ok(!restore.shouldRestore('locked display=wayland-1', id), 'a marker without a session');
    assert.ok(!restore.shouldRestore('garbage', 'garbage'), 'content without the marker prefix');
    assert.ok(!restore.shouldRestore(null, id));
    assert.ok(!restore.shouldRestore(id, null));
});

test('a marker of another session is stale and removed; none is not', () => {
    const id = restore.identity('wayland-1', 'logind:3');
    assert.ok(restore.isStale(restore.identity('wayland-1', 'logind:2'), id));
    assert.ok(restore.isStale('garbage\n', id));
    assert.ok(!restore.isStale(id + '\n', id));
    assert.ok(!restore.isStale('', id));
    assert.ok(!restore.isStale(' \n', id));
    assert.ok(!restore.isStale(undefined, id));
});

test('marker operations follow the lock and never skip an unknown state', () => {
    assert.equal(restore.nextOp(true, 'unknown'), 'write');
    assert.equal(restore.nextOp(true, 'absent'), 'write');
    assert.equal(restore.nextOp(true, 'present'), '');
    assert.equal(restore.nextOp(false, 'present'), 'remove');
    assert.equal(restore.nextOp(false, 'unknown'), 'remove', 'a failed write is still removed on unlock');
    assert.equal(restore.nextOp(false, 'absent'), '');
});
