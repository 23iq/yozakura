const { test } = require('node:test');
const assert = require('node:assert/strict');
const fs = require('node:fs');
const os = require('node:os');
const path = require('node:path');
const { execFileSync } = require('node:child_process');
const qmljs = require('./lib/qmljs.cjs');

const loadLibrary = file => qmljs.loadLibrary(path.join(__dirname, file));
const A = loadLibrary('../modules/theme/AppThemes.js');
const defaults = JSON.parse(JSON.stringify(loadLibrary('../config/defaults/apps.js').data));
const plain = v => JSON.parse(JSON.stringify(v));
const colorsQml = fs.readFileSync(path.join(__dirname, '../modules/theme/Colors.qml'), 'utf8');
const configQml = fs.readFileSync(path.join(__dirname, '../config/adapters/AppsAdapter.qml'), 'utf8');

test('every generator in Colors.qml belongs to exactly one app (or always runs)', () => {
    const generators = [...colorsQml.matchAll(/property (\w+Generator) (\w+): \1/g)].map(m => m[2]);
    assert.ok(generators.length >= 13, `found ${generators.length} generators`);
    for (const g of generators) {
        const owners = A.APPS.filter(a => a.generators.includes(g)).length + (A.ALWAYS.includes(g) ? 1 : 0);
        assert.equal(owners, 1, `${g} has ${owners} owners`);
    }
    for (const a of A.APPS)
        for (const g of a.generators) assert.ok(generators.includes(g), `${a.id}: unknown generator ${g}`);
});

test('every app has a default toggle, an adapter property and a label/icon', () => {
    assert.deepEqual(Object.keys(defaults.theming).sort(), plain(A.ids()).sort());
    for (const a of A.APPS) {
        assert.equal(defaults.theming[a.id], true, `${a.id} is themed by default`);
        assert.match(configQml, new RegExp(`property bool ${a.id}: true`), `${a.id} in the apps adapter`);
        assert.ok(a.label && a.icon && a.detect && a.outputs.length, a.id);
    }
});

test('generatorsFor honours the toggles', () => {
    const all = plain(A.generatorsFor(defaults.theming));
    assert.ok(all.includes('pywalGenerator') && all.includes('kittyGenerator') && all.includes('nvimGenerator'));
    const off = plain(A.generatorsFor({ ...defaults.theming, nvim: false, kitty: false }));
    assert.ok(!off.includes('nvimGenerator') && !off.includes('nvChadGenerator') && !off.includes('kittyGenerator'));
    assert.ok(off.includes('pywalGenerator'), 'shared palettes always run');
    assert.equal(A.enabled(null, 'gtk'), true, 'missing config = enabled');
    assert.equal(A.appOfGenerator('pywalZenGenerator'), 'firefox');
});

test('status script reports installed apps and last written outputs', () => {
    const home = fs.mkdtempSync(path.join(os.tmpdir(), 'app-themes-'));
    const cache = path.join(home, 'cache');
    fs.mkdirSync(path.join(home, '.config/gtk-3.0'), { recursive: true });
    fs.mkdirSync(cache, { recursive: true });
    fs.writeFileSync(path.join(home, '.config/gtk-3.0/gtk.css'), '/* x */');
    fs.writeFileSync(path.join(cache, 'kitty.conf'), 'x');
    const t = new Date('2026-10-05T10:00:00Z');
    fs.utimesSync(path.join(cache, 'kitty.conf'), t, t);
    const bin = path.join(home, 'bin');
    fs.mkdirSync(bin);
    fs.writeFileSync(path.join(bin, 'kitty'), '#!/bin/sh\n', { mode: 0o755 });
    const out = execFileSync('sh', ['-c', A.statusScript(), 'status', cache, 'yozakura'], {
        env: { HOME: home, PATH: `${bin}:/usr/bin:/bin`, XDG_CONFIG_HOME: path.join(home, '.config'), XDG_DATA_HOME: path.join(home, '.local/share') },
        encoding: 'utf8'
    });
    const st = plain(A.parseStatus(out));
    assert.deepEqual(Object.keys(st).sort(), plain(A.ids()).sort(), out);
    assert.equal(st.kitty.installed, true);
    assert.equal(st.kitty.written, t.getTime());
    assert.equal(st.gtk.written > 0, true, 'gtk.css found');
    assert.equal(st.telegram.installed, false);
    assert.equal(st.telegram.written, 0);
    assert.deepEqual(plain(A.parseStatus('junk\nnope|1|2\n')), {});
    fs.rmSync(home, { recursive: true, force: true });
});
