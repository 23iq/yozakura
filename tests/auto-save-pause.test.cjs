// config/AutoSavePause.js: a staged settings change pauses only the domains
// it stages; a service hold pauses every domain.
const { test } = require('node:test');
const assert = require('node:assert/strict');
const path = require('node:path');
const { loadLibrary } = require('./lib/qmljs.cjs');

const P = loadLibrary(path.join(__dirname, '../config/AutoSavePause.js'));
const shellDomains = { bar: [], notch: [], desktop: [] };
const state = over => Object.assign({ holds: 0, theme: false, compositor: false, shell: false, shellDomains }, over);

test('nothing staged or held: nothing paused', () => {
    for (const d of ['theme', 'compositor', 'bar', 'ai', 'general'])
        assert.equal(P.paused(d, state({})), false, d);
});

test('a hold pauses every domain', () => {
    for (const d of ['theme', 'compositor', 'bar', 'ai'])
        assert.equal(P.paused(d, state({ holds: 1 })), true, d);
});

test('staged theme pauses theme only', () => {
    const s = state({ theme: true });
    assert.equal(P.paused('theme', s), true);
    for (const d of ['compositor', 'bar', 'ai', 'desktop'])
        assert.equal(P.paused(d, s), false, d);
});

test('staged compositor pauses compositor only', () => {
    const s = state({ compositor: true });
    assert.equal(P.paused('compositor', s), true);
    assert.equal(P.paused('theme', s), false);
    assert.equal(P.paused('bar', s), false);
});

test('staged shell pauses the shell snapshot domains only', () => {
    const s = state({ shell: true });
    for (const d of ['bar', 'notch', 'desktop'])
        assert.equal(P.paused(d, s), true, d);
    for (const d of ['ai', 'general', 'apps', 'theme', 'compositor', 'toString', 'constructor'])
        assert.equal(P.paused(d, s), false, d);
});

test('missing state never pauses', () => {
    assert.equal(P.paused('bar', undefined), false);
    assert.equal(P.paused('bar', { shell: true }), false);
});
