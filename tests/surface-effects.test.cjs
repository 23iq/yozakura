const { test } = require('node:test');
const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');
const { loadLibrary } = require('./lib/qmljs.cjs');

const ROOT = path.join(__dirname, '..');
const FX_DIR = path.join(ROOT, 'modules/components/surfaceeffects');
const IND_DIR = path.join(ROOT, 'modules/bar/workspaces/indicators');
const E = loadLibrary(path.join(FX_DIR, 'SurfaceEffects.js'));
const I = loadLibrary(path.join(IND_DIR, 'IndicatorStyles.js'));
const C = loadLibrary(path.join(ROOT, 'modules/theme/GlassContrast.js'));
const validator = loadLibrary(path.join(ROOT, 'config/ConfigValidator.js'));
const enums = loadLibrary(path.join(ROOT, 'config/meta/Enums.js'));
const themeDefaults = loadLibrary(path.join(ROOT, 'config/defaults/theme.js')).data;
const wsDefaults = loadLibrary(path.join(ROOT, 'config/defaults/workspaces.js')).data;

function hex(h) {
    const n = parseInt(h.slice(1), 16);
    return { r: ((n >> 16) & 255) / 255, g: ((n >> 8) & 255) / 255, b: (n & 255) / 255 };
}

// Dark (default palette of the test env) and a typical light palette.
const PALETTES = {
    dark: { surface: hex('#120c0d'), text: hex('#f0dedf'), accent: hex('#ffb2b8') },
    light: { surface: hex('#fff8f7'), text: hex('#22191a'), accent: hex('#8c4a52') },
    oled: { surface: hex('#000000'), text: hex('#f0dedf'), accent: hex('#ffb2b8') },
    lowContrast: { surface: hex('#5a5a5a'), text: hex('#c8c8c8'), accent: hex('#ffffff') },
};

test('surface effects: none is the default, unknown ids fall back to it', () => {
    assert.equal(E.DEFAULT_ID, 'none');
    assert.equal(themeDefaults.surfaceEffect, 'none');
    assert.deepEqual([...E.ids()], ['none', 'crt', 'ink']);
    assert.equal(E.isValid('crt'), true);
    assert.equal(E.isValid('vhs'), false);
    assert.equal(E.get('vhs').id, 'none');
    assert.equal(E.get(undefined).id, 'none');
});

test('surface effects: every entry is complete and its files exist', () => {
    for (const id of E.ids()) {
        const e = E.get(id);
        for (const f of ['label', 'surface', 'highlight', 'highlightOption']) assert.equal(typeof e[f], 'string', id + '.' + f);
        assert.ok(Array.isArray(e.options) && Array.isArray(e.overlay) && Array.isArray(e.highlightVariants), id);
        for (const o of e.options) assert.ok(o in E.OPTIONS, id + ' option ' + o);
        for (const o of e.overlay) {
            assert.ok(['black', 'white', 'text', 'accent'].includes(o.toward), id);
            assert.ok(o.alpha > 0 && o.alpha < 0.5, id + ' overlay alpha stays subtle');
        }
        for (const file of [e.surface, e.highlight].filter(Boolean)) assert.ok(fs.existsSync(path.join(FX_DIR, file)), file);
        if (e.highlight) assert.ok(e.highlightVariants.length > 0, id);
        if (e.highlightOption) assert.ok(e.options.includes(e.highlightOption), id);
    }
    // "none" costs nothing: no component at all
    assert.equal(E.get('none').surface, '');
    assert.equal(E.get('none').highlight, '');
    // compiled shaders ship next to their sources
    for (const f of fs.readdirSync(FX_DIR).filter(f => f.endsWith('.frag'))) assert.ok(fs.existsSync(path.join(FX_DIR, f + '.qsb')), f + '.qsb');
});

test('surface effects: options get defaults and ranges', () => {
    const d = E.options(null);
    assert.deepEqual({ ...d }, { intensity: 0.5, flicker: true, grain: 0.6, brushHighlights: true });
    assert.deepEqual({ ...E.options(themeDefaults.surfaceEffectOptions) }, { ...d }, 'defaults match config/defaults/theme.js');
    const o = E.options({ intensity: 7, grain: -1, flicker: 'yes', brushHighlights: false });
    assert.equal(o.intensity, 1);
    assert.equal(o.grain, 0);
    assert.equal(o.flicker, true, 'non-boolean falls back to the default');
    assert.equal(o.brushHighlights, false);
    assert.equal(E.options({ intensity: NaN }).intensity, 0.5);
    assert.equal(E.options({ intensity: '0.9' }).intensity, 0.5, 'strings are not numbers');
});

test('surface effects: only shell surfaces, never app windows', () => {
    for (const s of ['bar', 'notch', 'popups', 'dock', 'sidebars', 'settings', 'widgets']) assert.equal(E.appliesTo(s), true, s);
    for (const s of ['windows', 'terminal', 'lockscreen', '', undefined]) assert.equal(E.appliesTo(s), false, String(s));
});

test('surface effects: highlights follow the registry and the option', () => {
    assert.equal(E.highlights('ink', {}, 'primary'), true);
    assert.equal(E.highlights('ink', {}, 'focus'), true);
    assert.equal(E.highlights('ink', {}, 'bg'), false);
    assert.equal(E.highlights('ink', { brushHighlights: false }, 'primary'), false);
    assert.equal(E.highlights('crt', {}, 'primary'), false);
    assert.equal(E.highlights('none', {}, 'primary'), false);
    assert.equal(E.usesOption('crt', 'flicker'), true);
    assert.equal(E.usesOption('crt', 'grain'), false);
    assert.equal(E.usesOption('ink', 'grain'), true);
});

test('surface effects: text stays at WCAG AA at any intensity', () => {
    for (const id of E.ids()) {
        for (const [name, pal] of Object.entries(PALETTES)) {
            const base = E.worstContrast(id, 0, pal);
            for (const want of [0, 0.25, 0.5, 0.75, 1]) {
                const s = E.safeStrength(id, want, pal);
                assert.ok(s >= 0 && s <= want + 1e-9, `${id}/${name}: ${s} <= ${want}`);
                const c = E.worstContrast(id, s, pal);
                assert.ok(c >= Math.min(C.WCAG_AA, base * 0.97) - 1e-6, `${id}/${name}@${want}: contrast ${c.toFixed(2)}`);
            }
        }
    }
    // Normal palettes keep the full intensity (the clamp only guards edge cases)
    assert.equal(E.safeStrength('crt', 1, PALETTES.dark), 1);
    assert.equal(E.safeStrength('ink', 1, PALETTES.light), 1);
    // A palette already below AA is never pushed further down
    assert.ok(E.safeStrength('crt', 1, PALETTES.lowContrast) < 1);
    assert.equal(E.safeStrength('crt', 0.4, null), 0.4);
});

test('surface effects: surface visibility and scanline row mapping', () => {
    assert.equal(E.surfaceVisibility(1), 1);
    assert.equal(E.surfaceVisibility(0), 0, 'invisible surfaces show no effect');
    assert.ok(E.surfaceVisibility(0.2) > 0 && E.surfaceVisibility(0.2) < 1);
    assert.equal(E.surfaceVisibility(undefined), 1);
    // untransformed item at y=40: row = y + 40
    assert.deepEqual([...E.screenRowMap({ x: 10, y: 40 }, { x: 11, y: 40 }, { x: 10, y: 41 })], [0, 1, 40]);
    // left-edge island (x and y swapped): screen rows run along local x
    assert.deepEqual([...E.screenRowMap({ x: 0, y: 0 }, { x: 0, y: 1 }, { x: 1, y: 0 })], [1, 0, 0]);
    assert.deepEqual([...E.screenRowMap(null, null, null)], [0, 1, 0]);
});

test('indicator styles: registry', () => {
    assert.equal(I.DEFAULT_ID, 'pill');
    assert.equal(wsDefaults.indicatorStyle, 'pill');
    assert.deepEqual([...I.ids()], ['pill', 'underline', 'dot', 'brush', 'bracket']);
    assert.equal(I.get('zigzag').id, 'pill');
    for (const id of I.ids()) {
        const s = I.get(id);
        assert.equal(typeof s.label, 'string');
        assert.equal(typeof s.filled, 'boolean');
        assert.ok(fs.existsSync(path.join(IND_DIR, s.component)), s.component);
    }
    assert.equal(I.filled('pill'), true);
    assert.equal(I.filled('brush'), true);
    assert.equal(I.filled('underline'), false);
    assert.equal(I.filled('bracket'), false);
});

test('indicator styles: box stretches between the two indices', () => {
    assert.deepEqual({ ...I.box(2, 2, 28, 4, false) }, { x: 60, y: 4, width: 28, height: 28 });
    assert.deepEqual({ ...I.box(3, 1, 28, 4, false) }, { x: 32, y: 4, width: 84, height: 28 });
    assert.deepEqual({ ...I.box(2, 2, 28, 4, true) }, { x: 4, y: 60, width: 28, height: 28 });
    // classic pill geometry is unchanged: box inset by 4 = the old highlight
    const b = I.box(1, 1, 28, 4, false);
    assert.equal(b.x + 4, 1 * 28 + 4 + 4);
    assert.equal(b.height - 8, 28 - 8);
});

test('indicator styles: underline and dot stay inside the box', () => {
    for (const vertical of [false, true]) {
        for (const [w, h] of [[28, 28], [84, 28], [28, 84], [20, 20], [40, 40]]) {
            if (!vertical && h > w && h !== w) continue;
            for (const shape of [I.underline(w, h, Math.min(w, h), vertical), I.dot(w, h, Math.min(w, h), vertical)]) {
                assert.ok(shape.x >= 0 && shape.y >= 0, JSON.stringify(shape));
                assert.ok(shape.x + shape.width <= w + 1e-9 && shape.y + shape.height <= h + 1e-9, JSON.stringify({ w, h, shape }));
                assert.ok(shape.width > 0 && shape.height > 0);
                assert.equal(shape.radius, Math.min(shape.width, shape.height) / 2);
            }
        }
    }
    // the dot stretches into a capsule along the bar while travelling
    assert.equal(I.dot(84, 28, 28, false).width - I.dot(28, 28, 28, false).width, 56);
    assert.equal(I.dot(28, 84, 28, true).height - I.dot(28, 28, 28, true).height, 56);
});

test('config: validator, enums and catalog know both registries', () => {
    assert.equal(validator.validate('crt', 'none', 'surfaceEffect'), 'crt');
    assert.equal(validator.validate('vhs', 'none', 'surfaceEffect'), 'none');
    assert.equal(validator.validate('bracket', 'pill', 'indicatorStyle'), 'bracket');
    assert.equal(validator.validate('zigzag', 'pill', 'indicatorStyle'), 'pill');
    assert.deepEqual([...enums.surfaceEffects()], [...E.ids()]);
    assert.deepEqual([...enums.indicatorStyles()], [...I.ids()]);
    const theme = JSON.parse(fs.readFileSync(path.join(ROOT, 'assets/schema/theme.schema.json'), 'utf8'));
    const ws = JSON.parse(fs.readFileSync(path.join(ROOT, 'assets/schema/workspaces.schema.json'), 'utf8'));
    assert.deepEqual(theme.properties.surfaceEffect.enum, [...E.ids()]);
    assert.deepEqual(ws.properties.indicatorStyle.enum, [...I.ids()]);
});
