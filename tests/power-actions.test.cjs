// PowerActions.js: destructive actions need a hold; commands are argv.
const { test } = require('node:test');
const assert = require('node:assert/strict');
const path = require('node:path');
const { loadLibrary } = require('./lib/qmljs.cjs');
const P = loadLibrary(path.join(__dirname, '../modules/widgets/powermenu/PowerActions.js'));

const built = JSON.parse(JSON.stringify(P.build(['yozakura', 'system', 'exit'], (k) => 'T:' + k, { lock: 'L', shutdown: 'S' })));

test('exactly logout, reboot and shutdown need a hold', () => {
    assert.deepEqual(built.filter((a) => a.confirm).map((a) => a.id), ['logout', 'reboot', 'shutdown']);
});

test('commands are argv arrays, logout goes through the daemon', () => {
    for (const a of built) {
        assert.ok(Array.isArray(a.argv) && a.argv.length > 0, a.id);
        assert.ok(!a.argv.some((x) => x === 'sh' || x === 'bash' || x === '-c'), a.id);
    }
    assert.deepEqual(built.find((a) => a.id === 'logout').argv, ['yozakura', 'system', 'exit']);
    assert.deepEqual(built.find((a) => a.id === 'shutdown').argv, ['systemctl', 'poweroff']);
});

test('labels and icons are resolved', () => {
    assert.equal(built[0].label, 'T:powermenu.lock_session');
    assert.equal(built[0].icon, 'L');
    assert.equal(built.find((a) => a.id === 'hibernate').icon, '');
});
