// HostResolve.js + SurfaceRegistry.js: "auto" hosts, the off-notch
// fallback and the runtime-only rule (explicit "notch" with the notch off).
const { test } = require('node:test');
const assert = require('node:assert/strict');
const path = require('node:path');
const { loadLibrary } = require('./lib/qmljs.cjs');
const DIR = path.join(__dirname, '../modules/shell/hosts');
const H = loadLibrary(path.join(DIR, 'HostResolve.js'));
const S = loadLibrary(path.join(DIR, 'SurfaceRegistry.js'));
const R = loadLibrary(path.join(DIR, 'HostRouter.js'));
const D = loadLibrary(path.join(__dirname, '../config/defaults/layout.js'));

const ON = { notchEnabled: true, barEnabled: true, barEdges: ['top'] };
const OFF = { notchEnabled: false, barEnabled: true, barEdges: ['top'] };
const all = (v) => ({
    launcher: { host: v }, dashboard: { host: v }, powermenu: { style: v }, tools: { style: v },
    cheatsheet: { host: v }, aiquick: { host: v }, panels: { host: v },
});
const AUTO_OFF = { launcher: 'spotlight', dashboard: 'sheet', powermenu: 'fullscreen', tools: 'radial',
    cheatsheet: 'fullscreen', aiquick: 'spotlight', panels: 'spotlight' };

test('auto is the notch while it is on (unchanged behaviour)', () => {
    for (const s of ['launcher', 'dashboard', 'powermenu', 'tools', 'aiquick', 'panels'])
        assert.equal(H.resolve(all('auto'), s, ON), 'notch', s);
    assert.equal(H.resolve(all('auto'), 'cheatsheet', ON), 'fullscreen');
    // No ctx = notch on
    assert.equal(H.resolve(all('auto'), 'launcher'), 'notch');
});

test('auto off the notch: spotlight / sheet / fullscreen / radial / card (spotlight stand-in)', () => {
    for (const [s, host] of Object.entries(AUTO_OFF))
        assert.equal(H.resolve(all('auto'), s, OFF), host, s);
});

test('explicit notch with the notch off falls back like auto, config untouched', () => {
    const l = all('notch');
    for (const [s, host] of Object.entries(AUTO_OFF))
        assert.equal(H.resolve(l, s, OFF), host, s);
    assert.equal(l.launcher.host, 'notch');
    assert.equal(H.resolve(l, 'launcher', ON), 'notch');
});

test('explicit available hosts are kept; unknown values behave like auto', () => {
    assert.equal(H.resolve(all('sheet'), 'launcher', OFF), 'sheet');
    assert.equal(H.resolve(all('spotlight'), 'dashboard', ON), 'spotlight');
    assert.equal(H.resolve(all('radial'), 'powermenu', ON), 'radial');
    assert.equal(H.resolve(all('fullscreen'), 'tools', ON), 'notch', 'tools has no fullscreen');
    assert.equal(H.resolve(all('bogus'), 'launcher', OFF), 'spotlight');
    assert.equal(H.resolve(null, 'dashboard', OFF), 'sheet');
    assert.equal(H.resolve(all('auto'), 'nope', ON), '');
    assert.equal(H.chosen(all('bogus'), 'launcher'), 'auto');
});

test('card is not built yet: it resolves to its spotlight stand-in', () => {
    assert.equal(S.host('card').built, false);
    assert.equal(H.resolve(all('card'), 'aiquick', ON), 'spotlight');
});

test('shownInstead: only with the notch off and when the host differs', () => {
    assert.equal(H.shownInstead(all('notch'), 'launcher', ON), '');
    assert.equal(H.shownInstead(all('auto'), 'launcher', ON), '');
    assert.equal(H.shownInstead(all('notch'), 'launcher', OFF), 'spotlight');
    assert.equal(H.shownInstead(all('auto'), 'powermenu', OFF), 'fullscreen');
    assert.equal(H.shownInstead(all('radial'), 'powermenu', OFF), '');
    assert.equal(H.shownInstead(all('notch'), 'launcher'), '');
    assert.equal(H.shownInstead(H.layoutWith('tools', 'notch'), 'tools', OFF), 'radial');
    assert.equal(H.layoutWith('powermenu', 'radial').powermenu.style, 'radial');
    assert.equal(H.layoutWith('nope', 'x'), null);
});

test('every surface: allowed hosts exist, the auto chain ends off the notch', () => {
    for (const [id, s] of Object.entries(S.SURFACES)) {
        for (const h of s.allowed.concat(s.auto)) assert.ok(S.host(h), `${id}: ${h}`);
        for (const h of s.auto) assert.ok(s.allowed.includes(h), `${id}: auto ${h} is allowed`);
        assert.equal(S.HOSTS[s.auto[s.auto.length - 1]].needsNotch, undefined, id);
    }
});

test('layout defaults are auto for every surface that can use the notch', () => {
    const d = D.data;
    for (const k of ['launcher', 'dashboard', 'aiquick', 'panels']) assert.equal(d[k].host, 'auto', k);
    for (const k of ['powermenu', 'tools']) assert.equal(d[k].style, 'auto', k);
});

test('the router follows the resolver: notch off never opens the notch for menus', () => {
    const vis = { launcher: false, dashboard: false, powermenu: true, tools: true, aiquick: false, keybinds: false };
    assert.equal(R.notchOpen(vis, all('auto'), ON), true);
    assert.equal(R.notchOpen(vis, all('auto'), OFF), false);
    assert.equal(R.hostFor(all('notch'), 'powermenu', OFF), 'overlay');
    assert.equal(R.menuStyle(all('notch'), 'tools', OFF), 'radial');
    assert.equal(R.hostFor(all('notch'), 'dashboard', OFF), 'sheet');
    assert.equal(R.moduleIn(Object.assign({}, vis, { powermenu: false }), all('auto'), 'overlay', OFF), 'tools');
});
