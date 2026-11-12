// The PAM stack the lock screen authenticates against (LockPam.js, used by
// LockPamTarget.qml; QML behaviour: tests/lockscreen.test.py).
const { test } = require('node:test');
const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');
const qmljs = require('./lib/qmljs.cjs');

const loadLibrary = file => qmljs.loadLibrary(path.join(__dirname, file));
const plain = value => JSON.parse(JSON.stringify(value));

const pam = loadLibrary('../modules/lockscreen/LockPam.js');
const defaults = plain(loadLibrary('../config/defaults/lockscreen.js').data);
const schema = loadLibrary('../modules/settings/schema/lockscreen.js');

const BUNDLED = '/usr/share/yozakura/config/pam';

test('the default is the bundled config, exactly as before', () => {
    assert.equal(defaults.pamService, '');
    const t = plain(pam.target(defaults.pamService, '', false, BUNDLED));
    assert.deepEqual(t, { configDirectory: BUNDLED, config: 'password.conf', system: false });
    assert.ok(fs.existsSync(path.join(__dirname, '../config/pam/password.conf')));
});

test('only plain PAM service names are accepted', () => {
    for (const ok of ['login', 'system-auth', 'sddm', 'common_auth', 'my.lock', 'a', 'x'.repeat(64), ' login ', 'login\n'])
        assert.notEqual(pam.serviceName(ok), '', JSON.stringify(ok));
    assert.equal(pam.serviceName(' login '), 'login', 'surrounding spaces are trimmed');
    for (const bad of ['', '   ', '../shadow', '/etc/pam.d/login', 'pam.d/login', '..', '.', '.hidden',
        '-login', 'log in', 'lo\u0000gin', 'lo;gin', '$(id)', 'x'.repeat(65), 'ñu', null, undefined, 42, {}])
        assert.equal(pam.serviceName(bad), '', JSON.stringify(bad));
    assert.equal(pam.servicePath('login'), '/etc/pam.d/login');
    assert.equal(pam.servicePath('../shadow'), '');
});

test('a named service is used only when its file was found for that name', () => {
    const sys = { configDirectory: '/etc/pam.d', config: 'system-auth', system: true };
    assert.deepEqual(plain(pam.target('system-auth', '/etc/pam.d/system-auth', true, BUNDLED)), sys);
    assert.deepEqual(plain(pam.target(' system-auth ', '/etc/pam.d/system-auth', true, BUNDLED)), sys);
    const bundled = { configDirectory: BUNDLED, config: 'password.conf', system: false };
    // missing file, not checked yet, result for another name, invalid name
    assert.deepEqual(plain(pam.target('system-auth', '/etc/pam.d/system-auth', false, BUNDLED)), bundled);
    assert.deepEqual(plain(pam.target('system-auth', '', false, BUNDLED)), bundled);
    assert.deepEqual(plain(pam.target('system-auth', '', true, BUNDLED)), bundled);
    assert.deepEqual(plain(pam.target('system-auth', '/etc/pam.d/login', true, BUNDLED)), bundled);
    assert.deepEqual(plain(pam.target('../x', '/etc/pam.d/../x', true, BUNDLED)), bundled);
    assert.deepEqual(plain(pam.target('', '', true, BUNDLED)), bundled);
});

test('the settings field pattern accepts the same names as the lock screen', () => {
    const entry = schema.category.sections.flatMap(s => s.entries).find(e => e.key === 'lockscreen.pamService');
    assert.ok(entry, 'lockscreen.pamService is declared in the settings schema');
    assert.equal(entry.type, 'text');
    assert.equal(entry.advanced, true);
    const re = new RegExp(entry.pattern);
    assert.ok(re.test(''), 'empty (default) is valid');
    for (const v of ['login', 'system-auth', 'my.lock', '_x', 'x'.repeat(64), '../shadow', '/etc/pam.d/login',
        '.hidden', '-login', 'log in', 'x'.repeat(65)])
        assert.equal(re.test(v), pam.serviceName(v) !== '', JSON.stringify(v));
});
