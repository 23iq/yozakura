// HostRouter: powermenu/tools styles route off the notch, the keybind
// cheatsheet ("keybinds" flag) routes through layout.cheatsheet.host.
const { test } = require('node:test');
const assert = require('node:assert/strict');
const path = require('node:path');
const { loadLibrary } = require('./lib/qmljs.cjs');
const R = loadLibrary(path.join(__dirname, '../modules/shell/hosts/HostRouter.js'));

const vis = (o) => Object.assign({ launcher: false, dashboard: false, powermenu: false, tools: false, aiquick: false, keybinds: false }, o);
const layout = (pm, tools, cheat) => ({ powermenu: { style: pm }, tools: { style: tools }, cheatsheet: { host: cheat } });

test('menu styles: notch stays in the notch, others go to the overlay', () => {
    assert.equal(R.hostFor(layout('notch', 'notch'), 'powermenu'), 'notch');
    assert.equal(R.hostFor(layout('radial', 'radial'), 'powermenu'), 'overlay');
    assert.equal(R.hostFor(layout('fullscreen', 'radial'), 'tools'), 'overlay');
    assert.equal(R.menuStyle(layout('fullscreen'), 'powermenu'), 'fullscreen');
    // tools has no fullscreen style; unknown values fall back to notch
    assert.equal(R.menuStyle(layout('bogus', 'fullscreen'), 'tools'), 'notch');
    assert.equal(R.menuStyle(layout('bogus'), 'powermenu'), 'notch');
    assert.equal(R.menuStyle(null, 'powermenu'), 'notch');
    assert.equal(R.hostFor(layout('radial'), 'aiquick'), 'notch');
});

test('a radial powermenu leaves the notch closed and opens the overlay', () => {
    const l = layout('radial', 'notch');
    assert.equal(R.notchOpen(vis({ powermenu: true }), l), false);
    assert.equal(R.moduleIn(vis({ powermenu: true }), l, 'overlay'), 'powermenu');
    assert.equal(R.notchOpen(vis({ tools: true }), l), true);
    assert.equal(R.moduleIn(vis({ tools: true }), l, 'overlay'), '');
});

test('cheatsheet hosts: fullscreen by default, spotlight or sheet on request', () => {
    assert.equal(R.hostFor(null, 'cheatsheet'), 'fullscreen');
    assert.equal(R.hostFor(layout('notch', 'notch', 'notch'), 'cheatsheet'), 'fullscreen');
    assert.equal(R.hostFor(layout('notch', 'notch', 'sheet'), 'cheatsheet'), 'sheet');
    const l = layout('notch', 'notch', 'spotlight');
    assert.equal(R.moduleIn(vis({ keybinds: true }), l, 'spotlight'), 'cheatsheet');
    assert.equal(R.moduleIn(vis({ keybinds: true }), l, 'fullscreen'), '');
    assert.equal(R.notchOpen(vis({ keybinds: true }), l), false);
    assert.equal(R.flagOf('cheatsheet'), 'keybinds');
    assert.equal(R.flagOf('launcher'), 'launcher');
});
