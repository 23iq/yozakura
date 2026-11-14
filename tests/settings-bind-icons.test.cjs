// The icon of a bind in the shortcuts list (modules/settings/editors/keybinds/BindIcons.js).
const test = require('node:test');
const assert = require('node:assert');
const path = require('node:path');
const fs = require('node:fs');
const { loadLibrary } = require('./lib/qmljs.cjs');

const repo = path.join(__dirname, '..');
const BindIcons = loadLibrary(path.join(repo, 'modules/settings/editors/keybinds/BindIcons.js'));
const Brand = loadLibrary(path.join(repo, 'modules/globals/BrandActions.js'));
const bind = (id, args) => ({ actions: [{ id, args: args || {} }] });

test('the shell actions get their own icons, not the group one', () => {
    assert.strictEqual(BindIcons.forBind(bind(Brand.action('launcher')), 'apps'), 'magnifyingGlass');
    assert.strictEqual(BindIcons.forBind(bind(Brand.action('screenshot')), 'apps'), 'camera');
    assert.strictEqual(BindIcons.forBind(bind(Brand.action('clipboard')), 'apps'), 'clipboard');
    // legacy ids of old binds.json files
    assert.strictEqual(BindIcons.forBind(bind(Brand.legacyAppId + '.notes'), 'apps'), 'notepad');
});

test('catalog actions, dispatchers and fallbacks', () => {
    assert.strictEqual(BindIcons.forBind(bind('window.close')), 'xCircle');
    assert.strictEqual(BindIcons.forBind(bind('system.lock')), 'lock');
    assert.strictEqual(BindIcons.forBind(bind('command.run', { command: 'kitty' })), 'terminal');
    assert.strictEqual(BindIcons.forBind(bind('command.run', { command: 'firefox --new-window' })), 'globe');
    assert.strictEqual(BindIcons.forBind(bind('command.run', { command: 'niri msg action maximize-window-to-edges' })), 'cornersOut');
    assert.strictEqual(BindIcons.forBind(bind('command.run', { command: 'my-script' })), 'terminalWindow');
    assert.strictEqual(BindIcons.forBind(bind('legacy.dispatcher', { dispatcher: 'exec', argument: 'nautilus' })), 'folder');
    assert.strictEqual(BindIcons.forBind(bind('legacy.dispatcher', { dispatcher: 'fullscreen' })), 'arrowsOut');
    assert.strictEqual(BindIcons.forBind(bind('window.someday')), 'appWindow');
    assert.strictEqual(BindIcons.forBind(bind('nothing.known'), 'code'), 'code');
    assert.strictEqual(BindIcons.forBind({ actions: [] }), 'command');
});

test('every icon named exists in Icons.qml', () => {
    const icons = fs.readFileSync(path.join(repo, 'modules/theme/Icons.qml'), 'utf8');
    const names = new Set([...icons.matchAll(/readonly property string (\w+)/g)].map(m => m[1]));
    for (const table of [BindIcons.APP, BindIcons.CATALOG, BindIcons.DISPATCHER]) {
        for (const v of Object.values(table))
            assert.ok(names.has(v), v);
    }
    for (const [, v] of BindIcons.PREFIX.concat(BindIcons.COMMANDS))
        assert.ok(names.has(v), v);
});
