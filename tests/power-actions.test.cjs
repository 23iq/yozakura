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

test('confirm actions carry their hold hint', () => {
    assert.equal(built.find((a) => a.id === 'shutdown').hold, 'T:powermenu.hold.shutdown');
    assert.equal(built.find((a) => a.id === 'lock').hold, '');
});

test('uptime reads as days, hours or minutes', () => {
    assert.equal(P.formatUptime(42), '0m');
    assert.equal(P.formatUptime(12 * 60 + 5), '12m');
    assert.equal(P.formatUptime(2 * 3600 + 5 * 60), '2h 05m');
    assert.equal(P.formatUptime(3 * 86400 + 4 * 3600 + 59), '3d 4h');
    assert.equal(P.formatUptime('x'), '');
});

test('the caption joins uptime and user@host, leaving out what is unknown', () => {
    assert.equal(P.caption('7505.31 28000.10\narch\n', 'lazy', 'up %1'), 'up 2h 05m · lazy@arch');
    assert.equal(P.caption('7505.31 28000.10\n', 'lazy', 'up %1'), 'up 2h 05m');
    assert.equal(P.caption('', 'lazy', 'up %1'), '');
    assert.equal(P.caption('garbage\narch', '', 'up %1'), '');
});

test('heroScale: hero sizes on large screens, the large size elsewhere', () => {
    assert.deepEqual({ ...P.heroScale(1440) }, { size: 'xl', label: 'title', caption: 'body' });
    assert.deepEqual({ ...P.heroScale(1080) }, { size: 'l', label: 'body', caption: 'secondary' });
    assert.deepEqual({ ...P.heroScale(720) }, { size: 'l', label: 'secondary', caption: 'caption' });
});
