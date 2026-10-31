// Macro sliders (modules/settings/Macros.js): derived level, Custom, writes.
const { test } = require('node:test');
const assert = require('node:assert/strict');
const path = require('node:path');
const { loadLibrary } = require('./lib/qmljs.cjs');

const repo = path.join(__dirname, '..');
const lib = rel => loadLibrary(path.join(repo, rel));
const Macros = lib('modules/settings/Macros.js');
const Defaults = lib('modules/settings/SettingsDefaults.js');
const SchemaUtil = lib('modules/settings/SchemaUtil.js');
const Categories = lib('modules/settings/schema/Categories.js');
const plain = v => JSON.parse(JSON.stringify(v));
const langs = ['en', 'es', 'ru'].map(l => require(`../translations/${l}.json`));

// A config: defaults overlaid with `over`.
const ctxOf = (over = {}, compositor = 'hyprland', effective) => ({
    compositor,
    get: k => (k in over ? over[k] : Defaults.get(k)),
    effective,
});

// Schema entry of a key (selector options / slider ranges).
const entryOf = key => SchemaUtil.flatten(Categories.categories).map(x => x.entry).find(e => e.key === key);

test('every macro key has a default, every point value is a valid setting', () => {
    for (const m of Macros.MACROS) {
        assert.ok(m.points.length >= 3, m.id);
        for (const k of Macros.allKeys(m))
            assert.notEqual(Defaults.get(k), undefined, `${m.id}: ${k}`);
        for (const p of m.points) {
            for (const [k, v] of Object.entries(p.values)) {
                assert.ok(Macros.allKeys(m).includes(k), `${m.id}: ${k} not in keys`);
                assert.equal(typeof v, typeof Defaults.get(k), `${m.id}: ${k} type`);
                const e = entryOf(k);
                if (e && e.options)
                    assert.ok(e.options.some(o => o.value === v), `${m.id}: ${k}=${v} is not an option`);
                if (e && typeof e.min === 'number')
                    assert.ok(v >= e.min && v <= e.max, `${m.id}: ${k}=${v} out of range`);
            }
        }
    }
});

test('the defaults sit on a macro point (never Custom out of the box)', () => {
    for (const m of Macros.MACROS)
        assert.ok(Macros.level(m, ctxOf({}, 'hyprland', () => 0.5)) >= 0, m.id);
});

test('a key off every point reads Custom; the handle rests on the closest point', () => {
    const r = Macros.byId('roundness');
    assert.equal(Macros.level(r, ctxOf({ 'theme.roundness': 15 })), -1);
    assert.equal(Macros.nearest(r, ctxOf({ 'theme.roundness': 15 })), 3);
    assert.equal(Macros.nearest(r, ctxOf({ 'theme.roundness': 1, 'theme.enableCorners': false })), 0);
    assert.equal(Macros.level(r, ctxOf({ 'theme.roundness': 24 })), 4);
});

test('moving writes only the differing keys of the point', () => {
    const d = Macros.byId('depth');
    assert.deepEqual(plain(Macros.writes(d, 3, ctxOf())), [
        { key: 'theme.shadowOpacity', value: 0.7 },
        { key: 'theme.lighting.strength', value: 'dramatic' },
    ]);
    assert.deepEqual(plain(Macros.writes(d, 2, ctxOf())), []);
    assert.deepEqual(plain(Macros.writes(d, 99, ctxOf())), []);
});

test('a point that leaves a key out matches any value of it', () => {
    const g = Macros.byId('glass');
    const off = ctxOf({ 'theme.glass.enabled': false, 'theme.glass.amount': 0.9 });
    assert.equal(Macros.level(g, off), 0);
    assert.deepEqual(plain(Macros.writes(g, 0, ctxOf())), [{ key: 'theme.glass.enabled', value: false }]);
    const still = ctxOf({ 'compositor.motionProfile': 'off', 'compositor.motionDurationScale': 2 });
    assert.equal(Macros.level(Macros.byId('motion'), still), 0);
});

test('glass "follow the preset" reads the preset amount and is pinned on move', () => {
    const g = Macros.byId('glass');
    assert.equal(Macros.level(g, ctxOf({}, 'hyprland', () => 0.74)), 3);
    assert.equal(Macros.level(g, ctxOf({}, 'hyprland', () => 0.3)), 1);
    // already near the point, but -1 is written as a pinned value
    assert.deepEqual(plain(Macros.writes(g, 3, ctxOf({}, 'hyprland', () => 0.74))), [{ key: 'theme.glass.amount', value: 0.75 }]);
});

test('compositor-only keys are neither read nor written elsewhere', () => {
    const dn = Macros.byId('density');
    const niri = ctxOf({ 'compositor.gapsOut': 33 }, 'niri');
    assert.equal(Macros.level(dn, niri), 2);
    assert.deepEqual(plain(Macros.writes(dn, 0, niri)).map(w => w.key), ['theme.density', 'compositor.gapsIn']);
    assert.equal(Macros.level(dn, ctxOf({ 'compositor.gapsOut': 33 }, 'hyprland')), -1);
});

test('macro strings are translated and the Look page shows every macro', () => {
    const page = Categories.byId('appearance');
    const entries = SchemaUtil.flatten([page]).map(x => x.entry).filter(e => e.type === 'macro');
    assert.deepEqual(plain(entries.map(e => e.macro)), plain(Macros.MACROS.map(m => m.id)));
    for (const m of Macros.MACROS) {
        const e = entries.find(x => x.macro === m.id);
        const keys = [e.label, e.description, m.low, m.high, ...m.points.map(p => p.label)];
        for (const l of langs)
            for (const k of keys.concat('prefs.macro.custom'))
                assert.ok(l[k], `${m.id}: ${k}`);
    }
});
