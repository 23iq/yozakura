// The kit's muted ink (Type.muted, theme/InkContrast.js) keeps WCAG AA
// (>= 4.5:1) on every ground it is drawn on, in every visual language, in
// light and dark schemes, with the test env's default palette (the one the
// renders use) and a few palettes the shell ships (assets/colors).
const test = require('node:test');
const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');
const { loadLibrary } = require('./lib/qmljs.cjs');

const ROOT = path.resolve(__dirname, '..');
const Ink = loadLibrary(path.join(ROOT, 'modules/theme/InkContrast.js'));
const VL = loadLibrary(path.join(ROOT, 'modules/theme/VisualLanguage.js'));

function rgb(hex) {
    const h = hex.replace('#', '');
    return { r: parseInt(h.slice(0, 2), 16) / 255, g: parseInt(h.slice(2, 4), 16) / 255, b: parseInt(h.slice(4, 6), 16) / 255 };
}

function toPalette(obj) {
    const out = {};
    for (const [k, v] of Object.entries(obj)) {
        if (typeof v === 'string' && /^#[0-9a-fA-F]{6}$/.test(v))
            out[k] = rgb(v);
    }
    return out;
}

// A `NAME = { "role": "#hex", ... }` dict of a Python test helper.
function pyPalette(file, name) {
    const src = fs.readFileSync(path.join(ROOT, file), 'utf8');
    const start = src.indexOf(name + ' = {');
    assert.ok(start >= 0, `${name} in ${file}`);
    const body = src.slice(start, src.indexOf('}', start));
    const out = {};
    for (const m of body.matchAll(/"(\w+)":\s*"(#[0-9a-fA-F]{6})"/g))
        out[m[1]] = m[2];
    return toPalette(out);
}

const PALETTES = [
    ['default dark', pyPalette('tests/lib/settings_env.py', 'DEFAULT_PALETTE'), false],
    ['default light', pyPalette('tools/render/settings_render.py', 'LIGHT_PALETTE'), true],
];
for (const name of ['Paper', 'Blossom', 'Nord', 'Gruvbox', 'Ice']) {
    for (const mode of ['light', 'dark']) {
        const file = path.join(ROOT, 'assets/colors', name, mode + '.json');
        PALETTES.push([`${name} ${mode}`, toPalette(JSON.parse(fs.readFileSync(file, 'utf8'))), mode === 'light']);
    }
}

function inputs(pal, card) {
    return Object.assign({}, pal, { card: pal[card.fill] || pal.surface });
}

test('muted ink keeps AA on every ground, language, scheme and palette', () => {
    for (const lang of VL.LANGUAGES) {
        for (const glassOn of [true, false]) {
            const card = VL.kit(lang, glassOn).card;
            for (const [name, pal, light] of PALETTES) {
                const p = inputs(pal, card);
                const ink = Ink.mutedInk(p, card, light);
                for (const g of Ink.grounds(p, card, light)) {
                    const c = Ink.contrast(ink, g);
                    assert.ok(c >= Ink.AA, `${lang}${glassOn ? '' : ' (glass off)'} ${name}: muted ${c.toFixed(2)}:1`);
                }
            }
        }
    }
});

test('the plain mix used to fail on the translucent light cards (the case this fixes)', () => {
    const [, pal] = PALETTES.find(p => p[0] === 'default light');
    for (const lang of ['ink', 'glass']) {
        const card = VL.kit(lang, true).card;
        const p = inputs(pal, card);
        const plain = Ink.inkAt(p, Ink.START);
        assert.ok(Ink.contrast(plain, Ink.cardGround(p, card, true)) < Ink.AA, `${lang}: plain mix below AA on its card`);
        assert.ok(Ink.mutedPull(p, card, true) > Ink.START, `${lang}: the ink is pulled further`);
    }
});

test('the ink moves only as far as needed: the solid languages keep the quiet caption tone in the dark', () => {
    const [, pal] = PALETTES.find(p => p[0] === 'default dark');
    for (const lang of ['tiles', 'device', 'classic']) {
        const card = VL.kit(lang, true).card;
        assert.equal(Ink.mutedPull(inputs(pal, card), card, false), Ink.START, lang);
    }
    // and it stays quieter than the text wherever the secondary ink suffices
    for (const lang of VL.LANGUAGES) {
        const card = VL.kit(lang, true).card;
        for (const [name, p0, light] of PALETTES) {
            const p = inputs(p0, card);
            const sec = Ink.worst(p.overSurfaceVariant, Ink.grounds(p, card, light));
            if (sec >= Ink.AA)
                assert.ok(Ink.mutedPull(p, card, light) <= 1 + 1e-9, `${lang} ${name}: muted not past the secondary ink`);
        }
    }
});

test('ambient wash: stronger in a light scheme, weaker as more wallpaper shows', () => {
    assert.ok(Ink.ambientWash(true, 1) > Ink.ambientWash(false, 1));
    assert.ok(Ink.ambientWash(true, 1) < Ink.ambientWash(true, 0.5));
    assert.equal(Ink.ambientWash(true, 1).toFixed(2), '0.54');
    assert.equal(Ink.ambientWash(false, 1).toFixed(2), '0.22');
});
