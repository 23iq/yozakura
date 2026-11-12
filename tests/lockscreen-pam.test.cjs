// The PAM stack the lock screen authenticates against (LockPam.js, used by
// LockPamTarget.qml; QML behaviour: tests/lockscreen.test.py).
const { test } = require('node:test');
const assert = require('node:assert/strict');
const fs = require('node:fs');
const os = require('node:os');
const { spawnSync } = require('node:child_process');
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
    const t = plain(pam.target(defaults.pamService, '', '', BUNDLED));
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

test('a named service is used only when its file was found usable for that name', () => {
    const sys = { configDirectory: '/etc/pam.d', config: 'system-auth', system: true };
    assert.deepEqual(plain(pam.target('system-auth', '/etc/pam.d/system-auth', 'usable', BUNDLED)), sys);
    assert.deepEqual(plain(pam.target(' system-auth ', '/etc/pam.d/system-auth', 'usable', BUNDLED)), sys);
    const bundled = { configDirectory: BUNDLED, config: 'password.conf', system: false };
    // missing/unreadable file, pam_permit stack, not checked yet, result for
    // another name, invalid name, old boolean result
    assert.deepEqual(plain(pam.target('system-auth', '/etc/pam.d/system-auth', 'unreadable', BUNDLED)), bundled);
    assert.deepEqual(plain(pam.target('system-auth', '/etc/pam.d/system-auth', 'permit', BUNDLED)), bundled);
    assert.deepEqual(plain(pam.target('system-auth', '/etc/pam.d/system-auth', true, BUNDLED)), bundled);
    assert.deepEqual(plain(pam.target('system-auth', '', '', BUNDLED)), bundled);
    assert.deepEqual(plain(pam.target('system-auth', '', 'usable', BUNDLED)), bundled);
    assert.deepEqual(plain(pam.target('system-auth', '/etc/pam.d/login', 'usable', BUNDLED)), bundled);
    assert.deepEqual(plain(pam.target('../x', '/etc/pam.d/../x', 'usable', BUNDLED)), bundled);
    assert.deepEqual(plain(pam.target('', '', 'usable', BUNDLED)), bundled);
});

test('autologin stacks are refused by name, before any file is read', () => {
    for (const name of ['gdm-autologin', 'sddm-autologin', 'lightdm-autologin', 'X-AutoLogin', ' gdm-autologin ']) {
        assert.equal(pam.refusal(name), 'autologin', name);
        assert.equal(pam.servicePath(name), '', name);
        const path = '/etc/pam.d/' + name.trim();
        assert.equal(plain(pam.target(name, path, 'usable', BUNDLED)).system, false, name);
        assert.match(pam.warning(name, '', ''), /autologin/, name);
    }
    for (const name of ['login', 'system-auth', 'autologin-helper', 'gdm-password', 'sddm'])
        assert.equal(pam.refusal(name), '', name);
});

// The real check command on real files: grep is what the lock screen runs.
test('the service file check refuses pam_permit stacks and unreadable files', () => {
    const dir = fs.mkdtempSync(path.join(os.tmpdir(), 'lockpam-'));
    try {
        const files = {
            // the stock display-manager autologin shape
            'gdm-autologin': '#%PAM-1.0\nauth       requisite    pam_nologin.so\nauth       required     pam_permit.so\naccount    include      system-local-login\n',
            'indented': '  -auth\t[success=1 default=ignore]  /usr/lib/security/pam_permit.so\n',
            'upper': 'AUTH sufficient pam_permit.so\n',
            'system-auth': '#%PAM-1.0\nauth required pam_unix.so try_first_pass nullok\n# auth sufficient pam_permit.so\naccount required pam_permit.so\nsession optional pam_permit.so\n',
            'sssd': 'auth sufficient pam_sss.so\nauth required pam_unix.so\npassword required pam_permit.so\n',
            'empty': ''
        };
        for (const [name, body] of Object.entries(files))
            fs.writeFileSync(path.join(dir, name), body);
        fs.mkdirSync(path.join(dir, 'a-directory'));
        const verdict = name => {
            const argv = pam.checkCommand(path.join(dir, name));
            const r = spawnSync(argv[0], argv.slice(1), { encoding: 'utf8' });
            assert.equal(r.stdout + r.stderr, '', 'the check prints nothing');
            return pam.checkResult(r.status);
        };
        assert.equal(verdict('gdm-autologin'), 'permit');
        assert.equal(verdict('indented'), 'permit');
        assert.equal(verdict('upper'), 'permit');
        assert.equal(verdict('system-auth'), 'usable', 'pam_permit outside auth lines (and comments) is fine');
        assert.equal(verdict('sssd'), 'usable');
        assert.equal(verdict('empty'), 'usable');
        assert.equal(verdict('missing'), 'unreadable');
        assert.equal(verdict('a-directory'), 'unreadable');
        if (process.getuid && process.getuid() !== 0) {
            fs.chmodSync(path.join(dir, 'sssd'), 0o000);
            assert.equal(verdict('sssd'), 'unreadable', 'an unreadable file is not used');
        }
        // a name argument that looks like an option is still a path
        assert.deepEqual(plain(pam.checkCommand('-x')).slice(-2), ['--', '-x']);
    } finally {
        fs.rmSync(dir, { recursive: true, force: true });
    }
    assert.equal(pam.checkResult(2), 'unreadable');
    assert.equal(pam.checkResult(-1), 'unreadable', 'a check that could not run');
    assert.equal(pam.checkResult(null), 'unreadable');
});

test('every refusal explains itself in the log', () => {
    const p = '/etc/pam.d/x';
    assert.equal(pam.warning('', '', ''), '');
    assert.equal(pam.warning('x', p, 'usable'), '');
    assert.match(pam.warning('x', p, 'permit'), /pam_permit\.so.*bundled/);
    assert.match(pam.warning('x', p, 'unreadable'), /cannot be read.*bundled/);
    assert.match(pam.warning('x', '', ''), /not checked yet.*bundled/);
    assert.match(pam.warning('../x', '', ''), /not a plain PAM service name/);
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
