const { test } = require('node:test');
const assert = require('node:assert/strict');
const fs = require('node:fs');
const vm = require('node:vm');
const path = require('node:path');

function load(rel) {
    const ctx = {};
    const src = fs.readFileSync(path.join(__dirname, '..', rel), 'utf8').replace(/^\.pragma library\s*/, '');
    vm.runInNewContext(src, ctx);
    return ctx;
}

const spec = load('config/ColorSpec.js');
const app = load('modules/services/CompositorAppearance.js');

// Minimal stand-in for Config.resolveColor + Qt.color: palette roles,
// #rrggbb literals and the "@alpha" suffix.
const palette = { primary: '#feb0d1', tertiary: '#f3b7c8', surfaceBright: '#3d3639', surface: '#1a1112', shadow: '#000000' };
function hexToColor(hex) {
    const h = hex.replace('#', '');
    return { r: parseInt(h.slice(0, 2), 16) / 255, g: parseInt(h.slice(2, 4), 16) / 255, b: parseInt(h.slice(4, 6), 16) / 255, a: 1 };
}
function resolve(s) {
    const p = spec.parse(s);
    const base = p.base.startsWith('#') ? p.base : palette[p.base];
    const c = hexToColor(base);
    return { r: c.r, g: c.g, b: c.b, a: c.a * (p.alpha === null ? 1 : p.alpha) };
}

test('color spec alpha suffix parses roles and literals, plain specs untouched', () => {
    assert.deepEqual({ ...spec.parse('surfaceBright@0.5') }, { base: 'surfaceBright', alpha: 0.5 });
    assert.deepEqual({ ...spec.parse('#ff0000@.25') }, { base: '#ff0000', alpha: 0.25 });
    assert.deepEqual({ ...spec.parse('primary') }, { base: 'primary', alpha: null });
    assert.equal(spec.parse('primary@2').alpha, 1);
    assert.equal(spec.parse('primary@abc').alpha, null);
    assert.equal(spec.parse('primary@abc').base, 'primary@abc');
    assert.equal(spec.alphaOf('primary'), 1);
    assert.equal(spec.baseOf('primary@0.3'), 'primary');
    assert.equal(spec.compose('primary', 1), 'primary');
    assert.equal(spec.compose('primary', 0.5), 'primary@0.5');
});

test('formatColor emits rgb() when opaque and rgba() otherwise', () => {
    assert.equal(app.formatColor({ r: 1, g: 0, b: 0, a: 1 }), 'rgb(ff0000)');
    assert.equal(app.formatColor({ r: 0, g: 0, b: 0, a: 0.5 }), 'rgba(00000080)');
    assert.equal(app.formatColor(app.withAlpha(resolve('primary'), 0.4)), 'rgba(feb0d166)');
});

test('border value keeps gradients and angle, single colors stay strings', () => {
    const grad = app.borderValue(['primary', 'tertiary'], 45, 'primary', resolve);
    assert.deepEqual(JSON.parse(JSON.stringify(grad)), { colors: ['rgb(feb0d1)', 'rgb(f3b7c8)'], angle: 45 });
    assert.equal(app.borderString(grad), 'rgb(feb0d1) rgb(f3b7c8) 45deg');
    assert.equal(app.firstColor(grad), 'rgb(feb0d1)');
    assert.equal(app.borderValue(['primary'], 45, 'surface', resolve), 'rgb(feb0d1)');
    assert.equal(app.borderValue([], 45, 'surface', resolve), 'rgb(1a1112)');
    // QVariantList-like sequences (not real arrays) are accepted.
    const seq = { length: 2, 0: 'surfaceBright@0.5', 1: 'surface' };
    assert.deepEqual(JSON.parse(JSON.stringify(app.borderValue(seq, 90, 'surface', resolve))), { colors: ['rgba(3d363980)', 'rgb(1a1112)'], angle: 90 });
});

test('hyprland config carries gradients, shadow colors with opacity and every blur key', () => {
    const compositor = {
        activeBorderColor: ['primary', 'tertiary'], borderAngle: 45,
        inactiveBorderColor: ['surfaceBright@0.5', 'surface'], inactiveBorderAngle: 45,
        syncBorderColor: false, gapsIn: 8, gapsOut: 18, shadowEnabled: true, shadowRange: 20,
        shadowRenderPower: 3, shadowColor: 'primary', shadowColorInactive: 'shadow', shadowOpacity: 0.4,
        blurNoise: 0.015, blurContrast: 1.05, blurBrightness: 0.9, blurVibrancy: 0.2,
        blurPopups: true, blurPopupsIgnorealpha: 0.2,
    };
    const hl = app.buildHyprlandConfig({
        compositor, resolve, borderSize: 2, rounding: 16, borderColor: 'primary',
        shadowColor: 'primary', shadowOpacity: 0.4, layout: 'scrolling',
    });
    assert.deepEqual(JSON.parse(JSON.stringify(hl.general.col)), {
        active_border: { colors: ['rgb(feb0d1)', 'rgb(f3b7c8)'], angle: 45 },
        inactive_border: { colors: ['rgba(3d363980)', 'rgb(1a1112)'], angle: 45 },
    });
    assert.equal(hl.general.layout, 'scrolling');
    assert.equal(hl.decoration.shadow.color, 'rgba(feb0d166)');
    assert.equal(hl.decoration.shadow.color_inactive, 'rgba(00000066)');
    assert.equal(hl.decoration.shadow.render_power, 3);
    const blur = hl.decoration.blur;
    assert.equal(blur.noise, 0.015);
    assert.equal(blur.contrast, 1.05);
    assert.equal(blur.brightness, 0.9);
    assert.equal(blur.vibrancy, 0.2);
    assert.equal(blur.popups, true);
    assert.equal(blur.popups_ignorealpha, 0.2);
    for (const key of ['ignore_opacity', 'new_optimizations', 'xray', 'vibrancy_darkness', 'special', 'input_methods', 'input_methods_ignorealpha'])
        assert.ok(key in blur, key);
    // syncBorderColor collapses the active border onto the synced color.
    const synced = app.buildHyprlandConfig({ compositor: { ...compositor, syncBorderColor: true }, resolve, borderColor: 'tertiary' });
    assert.equal(synced.general.col.active_border, 'rgb(f3b7c8)');
});

test('luaLiteral renders the gradient table hl.config expects', () => {
    assert.equal(app.luaLiteral({ colors: ['rgb(a)', 'rgb(b)'], angle: 45 }), '{colors = {"rgb(a)", "rgb(b)"}, angle = 45}');
    assert.equal(app.luaLiteral({ ok: true, n: NaN, s: null }), '{ok = true, n = nil, s = nil}');
});
