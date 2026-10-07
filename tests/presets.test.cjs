// Built-in presets (assets/presets/{layouts,styles,palettes,sets}): every key
// is a real config key with a valid value, each part only carries the keys
// its kind owns, composition order and the legacy single-folder fallback,
// and the 10 sets stay distinct (>= 4 of the six axes, one signature each).
const { test } = require('node:test');
const assert = require('node:assert/strict');
const fs = require('node:fs');
const os = require('node:os');
const path = require('node:path');
const { loadLibrary } = require('./lib/qmljs.cjs');
const P = require('./lib/presetsets.cjs');

const ROOT = path.join(__dirname, '..');
const DEFAULTS = loadLibrary(path.join(ROOT, 'modules/settings/SettingsDefaults.js')).DOMAINS;
const isObj = v => v !== null && typeof v === 'object' && !Array.isArray(v);
const schema = dom => {
    const f = path.join(ROOT, 'assets/schema', `${dom}.schema.json`);
    return fs.existsSync(f) ? JSON.parse(fs.readFileSync(f, 'utf8')) : {};
};

const SETS = ['CRT', 'Glacier', 'Kaze', 'Kōyō', 'Metro', 'Neon Tokyo', 'Shōji', 'Sumi-e', 'Yozakura', 'Yozakura Night'];

// Every folder that carries domain files: [label, folder].
function folders() {
    const out = [];
    for (const kind of P.KINDS)
        for (const n of P.listParts(kind))
            out.push([`${kind} ${n}`, path.join(P.OFFICIAL, P.KIND_DIRS[kind], n), kind]);
    for (const n of P.listSets())
        out.push([`set ${n}`, path.join(P.OFFICIAL, 'sets', n), 'set']);
    return out;
}

// Unknown keys (against the defaults) and out-of-enum values (against the schema).
function check(where, value, defaults, sch, problems) {
    for (const [k, v] of Object.entries(value)) {
        const at = `${where}.${k}`;
        if (!(k in defaults)) {
            problems.push(`${at}: unknown key`);
            continue;
        }
        const s = (sch && sch.properties && sch.properties[k]) || {};
        if (s.enum && !Array.isArray(v) && !s.enum.includes(v))
            problems.push(`${at}: ${JSON.stringify(v)} not in ${JSON.stringify(s.enum)}`);
        const d = defaults[k];
        if (isObj(v) && isObj(d) && Object.keys(d).length > 0)
            check(at, v, d, s, problems);
    }
}

test('the built-in sets are the 10 concepts, each with its parts and an info.json', () => {
    assert.deepEqual(P.listSets(), SETS);
    assert.equal(P.listParts('layout').length, 5);
    assert.deepEqual(P.listParts('layout'), ['Classic', 'Engawa', 'Ma', 'Tatami', 'Yozakura']);
    assert.ok(P.listParts('style').length >= 10);
    assert.equal(P.listParts('palette').length, 10);
    for (const [label, folder] of folders()) {
        const info = P.info(folder);
        assert.equal(typeof info.author, 'string', `${label}: info.author`);
        assert.ok(info.description && info.description.length > 20, `${label}: info.description`);
    }
    const used = { layout: new Set(), style: new Set(), palette: new Set() };
    for (const n of SETS) {
        const refs = P.setRefs(path.join(P.OFFICIAL, 'sets', n));
        assert.ok(refs, `${n}: set.json`);
        for (const kind of P.KINDS) {
            assert.ok(P.partDir(kind, refs[kind]), `${n}: ${kind} "${refs[kind]}" exists`);
            used[kind].add(refs[kind]);
        }
    }
    for (const kind of P.KINDS)
        assert.deepEqual([...used[kind]].sort(), P.listParts(kind), `every ${kind} is used by a set`);
});

test('every key of every part and set is a config key with a valid value', () => {
    const problems = [];
    for (const [label, folder] of folders()) {
        for (const [dom, obj] of Object.entries(P.domains(folder))) {
            if (!DEFAULTS[dom]) {
                problems.push(`${label}: unknown domain ${dom}`);
                continue;
            }
            check(`${label} ${dom}`, obj, DEFAULTS[dom], schema(dom), problems);
        }
    }
    assert.deepEqual(problems, []);
});

test('each part only carries the keys its kind owns', () => {
    for (const kind of P.KINDS) {
        for (const n of P.listParts(kind)) {
            for (const [dom, obj] of Object.entries(P.domains(P.partDir(kind, n)))) {
                for (const key of Object.keys(obj))
                    assert.equal(P.ownerOf(dom, key), kind, `${kind} ${n}: ${dom}.${key} belongs to ${P.ownerOf(dom, key)}`);
            }
        }
    }
    for (const n of P.listParts('palette')) {
        const d = P.domains(P.partDir('palette', n));
        assert.deepEqual(Object.keys(d.wallpaper).sort(), ['activeColorPreset', 'matugenScheme'], n);
        assert.equal(d.wallpaper.activeColorPreset, n, `${n}: its own color preset`);
        assert.deepEqual(Object.keys(d.theme).sort(), ['lightMode', 'oledMode'], n);
    }
});

test('each palette ships a static color preset with all the keys', () => {
    const want = Object.keys(JSON.parse(fs.readFileSync(path.join(ROOT, 'assets/colors/Nord/dark.json'), 'utf8'))).sort();
    assert.equal(want.length, 98);
    for (const n of P.listParts('palette')) {
        for (const mode of ['dark', 'light']) {
            const f = path.join(ROOT, 'assets/colors', n, `${mode}.json`);
            const colors = JSON.parse(fs.readFileSync(f, 'utf8'));
            assert.deepEqual(Object.keys(colors).sort(), want, `${n} ${mode}`);
            for (const [k, v] of Object.entries(colors))
                assert.match(v, /^#[0-9a-fA-F]{6}$/, `${n} ${mode} ${k}`);
            const lines = fs.readFileSync(path.join(ROOT, 'assets/colors', n, mode), 'utf8').trim().split('\n');
            assert.equal(lines.length, 8, `${n} ${mode}: 8 base colors`);
        }
    }
});

test('composition: layout -> style -> palette -> set overrides, objects merge and the rest replaces', () => {
    const tmp = fs.mkdtempSync(path.join(os.tmpdir(), 'presetsets-'));
    const put = (rel, obj) => {
        fs.mkdirSync(path.dirname(path.join(tmp, rel)), { recursive: true });
        fs.writeFileSync(path.join(tmp, rel), JSON.stringify(obj));
    };
    put('layouts/Lay/bar.json', { panels: [{ id: 'a' }, { id: 'b' }], frame: { on: true, size: 4 } });
    put('styles/Sty/theme.json', { font: 'A', glass: { enabled: true, amount: 0.5 } });
    put('palettes/Pal/theme.json', { lightMode: true });
    put('palettes/Pal/wallpaper.json', { activeColorPreset: 'Pal' });
    put('sets/Mix/set.json', { layout: 'lay', style: 'STY', palette: 'Pal' });
    put('sets/Mix/info.json', { author: 'me' });
    put('sets/Mix/bar.json', { panels: [{ id: 'c' }], frame: { size: 9 } });
    put('sets/Mix/theme.json', { glass: { amount: 1 }, lightMode: false });
    put('sets/Plain/theme.json', { font: 'Legacy' });
    try {
        assert.deepEqual(P.listSets(tmp), ['Mix', 'Plain']);
        const mix = P.composeSet('Mix', tmp);
        assert.deepEqual(Object.keys(mix).sort(), ['bar', 'theme', 'wallpaper'], 'info/set are not domains');
        assert.deepEqual(mix.bar, { panels: [{ id: 'c' }], frame: { on: true, size: 9 } });
        assert.deepEqual(mix.theme, { font: 'A', glass: { enabled: true, amount: 1 }, lightMode: false });
        assert.deepEqual(mix.wallpaper, { activeColorPreset: 'Pal' });
        assert.deepEqual(P.composeSet('Plain', tmp), { theme: { font: 'Legacy' } }, 'no set.json: used as is');
        fs.rmSync(path.join(tmp, 'styles/Sty'), { recursive: true });
        assert.throws(() => P.composeSet('Mix', tmp), /style "STY" not found/);
    } finally {
        fs.rmSync(tmp, { recursive: true, force: true });
    }
});

test('legacy single-folder presets: without sets/ every folder is a set', () => {
    const tmp = fs.mkdtempSync(path.join(os.tmpdir(), 'presetsets-legacy-'));
    try {
        fs.mkdirSync(path.join(tmp, 'Old Look'));
        fs.writeFileSync(path.join(tmp, 'Old Look/theme.json'), JSON.stringify({ roundness: 4 }));
        fs.writeFileSync(path.join(tmp, 'Old Look/info.json'), JSON.stringify({ author: 'x' }));
        assert.deepEqual(P.listSets(tmp), ['Old Look']);
        assert.deepEqual(P.composeSet('Old Look', tmp), { theme: { roundness: 4 } });
    } finally {
        fs.rmSync(tmp, { recursive: true, force: true });
    }
});

// --- the six axes of Addendum 4 ------------------------------------------
function radiusClass(r) {
    return r <= 2 ? 'square' : r <= 8 ? 'small' : r <= 16 ? 'medium' : 'large';
}

function layoutPrint(c) {
    const bar = c.bar || {};
    const panels = (bar.panels || []).length ? bar.panels.map(p => `${p.edge}:${p.style}`).join('+') : `${bar.position}:${(bar.layout || {}).style}`;
    const n = c.notch || {}, l = c.layout || {}, launcher = l.launcher || {}, dash = l.dashboard || {};
    return [panels, `${n.position}/${n.align}/${n.style}`, (c.dock || {}).enabled !== false,
        `${launcher.host}/${launcher.resultStyle}`, `${dash.host}/${dash.home}`].join(' ');
}

function axes(name) {
    const c = P.composeSet(name);
    const t = c.theme, shape = t.shape || {};
    return {
        language: t.language,
        shape: `${shape.corners}/${shape.popupCorners || shape.corners}/${radiusClass(t.roundness)}`,
        layout: layoutPrint(c),
        motion: c.compositor.motionProfile,
        density: t.density,
        palette: P.setRefs(path.join(P.OFFICIAL, 'sets', name)).palette
    };
}

test('every set sets each axis explicitly', () => {
    for (const n of SETS) {
        for (const [axis, v] of Object.entries(axes(n)))
            assert.ok(v !== undefined && !String(v).includes('undefined'), `${n}: ${axis} = ${v}`);
    }
});

test('every two sets differ in at least 4 of language, shape, layout, motion, density, palette', () => {
    const all = Object.fromEntries(SETS.map(n => [n, axes(n)]));
    for (let i = 0; i < SETS.length; i++) {
        for (let j = i + 1; j < SETS.length; j++) {
            const a = all[SETS[i]], b = all[SETS[j]];
            const diff = Object.keys(a).filter(k => a[k] !== b[k]);
            assert.ok(diff.length >= 4, `${SETS[i]} vs ${SETS[j]} differ only in ${diff.join(', ')}`);
        }
    }
});

// One feature per set that no other set has.
const SIGNATURES = {
    'Yozakura': c => c.theme.signatures.petals && c.theme.signatures.petalShape === 'petal',
    'Yozakura Night': c => c.notch.mediaStyle === 'artwork',
    'CRT': c => c.theme.surfaceEffect === 'crt' && c.layout.osd.style === 'edge' && c.lockscreen.style === 'terminal',
    'Glacier': c => (((c.theme.glass || {}).advanced || {}).borderHighlight || -1) > 0,
    'Kaze': c => c.theme.popup.entry === 'slide-from-anchor' && c.compositor.motionWorkspaceStyle === 'slide',
    'Kōyō': c => c.theme.signatures.petals && c.theme.signatures.petalShape === 'leaf' && c.theme.icons.weight === 'fill',
    'Metro': c => c.theme.type.headingCase === 'lower' && c.theme.icons.weight === 'regular' && c.layout.launcher.resultStyle === 'grid' && c.layout.dashboard.home === 'bento',
    'Neon Tokyo': c => c.theme.popup.tail === true && c.theme.type.headingCase === 'upper',
    'Shōji': c => c.theme.lightMode === true && c.bar.frameEnabled === true && c.theme.srFrame.inheritBg === false,
    'Sumi-e': c => c.theme.surfaceEffect === 'ink' && c.theme.signatures.brushHighlight && c.desktop.depthClock && c.desktop.depthClockStyle === 'yozakura'
};

test('each set has its own signature', () => {
    const composed = Object.fromEntries(SETS.map(n => [n, P.composeSet(n)]));
    for (const [owner, has] of Object.entries(SIGNATURES)) {
        const holders = SETS.filter(n => {
            try {
                return Boolean(has(composed[n]));
            } catch (e) {
                return false;
            }
        });
        assert.deepEqual(holders, [owner], `signature of ${owner}`);
    }
});

test('motion stays within the budget', () => {
    const profiles = schema('compositor').properties.motionProfile.enum;
    for (const n of P.listParts('style')) {
        const d = P.domains(P.partDir('style', n));
        assert.ok(d.theme.animDuration >= 160 && d.theme.animDuration <= 300, `${n}: animDuration ${d.theme.animDuration}`);
        assert.ok(profiles.includes(d.compositor.motionProfile) && d.compositor.motionProfile !== 'off', `${n}: motion`);
        assert.ok((d.compositor.motionDurationScale ?? 1) <= 1, `${n}: motionDurationScale`);
    }
});

test('only the Shōji set is light', () => {
    assert.deepEqual(SETS.filter(n => P.composeSet(n).theme.lightMode), ['Shōji']);
});
