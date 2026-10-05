// Glass system (modules/theme/Glass*.js): curve, migration identity for every
// preset, legibility clamp, overrides, compositor overlay.
const { test } = require('node:test');
const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');

const qmljs = require('./lib/qmljs.cjs');
const repo = path.join(__dirname, '..');
const lib = rel => qmljs.loadLibrary(path.join(repo, rel));
const plain = v => JSON.parse(JSON.stringify(v));

const Curve = lib('modules/theme/GlassCurve.js');
const Contrast = lib('modules/theme/GlassContrast.js');
const Model = lib('modules/theme/GlassModel.js');
const Appearance = lib('modules/services/CompositorAppearance.js');
const ThemeDefaults = lib('config/defaults/theme.js').data;
const CompositorDefaults = lib('config/defaults/compositor.js').data;

const GLASS = ThemeDefaults.glass;
const glass = over => Object.assign(plain(GLASS), over || {});

function presets() {
    const out = [['defaults', ThemeDefaults, CompositorDefaults]];
    const dir = path.join(repo, 'assets/presets');
    for (const name of fs.readdirSync(dir).sort()) {
        const read = f => {
            const p = path.join(dir, name, f);
            return fs.existsSync(p) ? JSON.parse(fs.readFileSync(p, 'utf8')) : {};
        };
        out.push([name, Object.assign(plain(ThemeDefaults), read('theme.json')), Object.assign(plain(CompositorDefaults), read('compositor.json'))]);
    }
    const sakura = require('./fixtures/glass/sakura-glass.json');
    out.push(['Sakura Glass', Object.assign(plain(ThemeDefaults), sakura.theme), Object.assign(plain(CompositorDefaults), sakura.compositor)]);
    return out;
}

const hex = h => ({ r: parseInt(h.slice(1, 3), 16) / 255, g: parseInt(h.slice(3, 5), 16) / 255, b: parseInt(h.slice(5, 7), 16) / 255 });
const VARIANTS = Object.keys(Model.GLASS_VARIANTS);
const designOf = (theme, v) => theme[Model.GLASS_VARIANTS[v]].opacity;

test('curve: solid at 0, monotonic, invertible', () => {
    for (const name of Curve.NAMES) {
        const p = Curve.spec(name);
        assert.equal(Curve.at(name, 0, false), p.neutral, name);
        for (const light of [false, true]) {
            let prev = Curve.at(name, 0, light);
            const dir = Math.sign(Curve.at(name, 1, light) - prev);
            for (let a = 0.05; a <= 1.0001; a += 0.05) {
                const v = Curve.at(name, a, light);
                assert.ok((v - prev) * dir >= -1e-12, `${name} not monotonic at ${a}`);
                prev = v;
            }
        }
    }
    for (const a of [0.1, 0.33, 0.5, 0.8])
        assert.ok(Math.abs(Curve.invert('opacity', Curve.at('opacity', a, false), false) - a) < 1e-9);
    assert.ok(Curve.at('opacity', 0.5, false) < 0.9 && Curve.at('opacity', 0.5, false) > 0.7, '0.5 = tasteful frosted');
});

test('reference amount derives from the preset opacities', () => {
    assert.equal(Model.deriveReference(ThemeDefaults), 0);
    const sakura = require('./fixtures/glass/sakura-glass.json').theme;
    const ref = Model.deriveReference(sakura);
    assert.ok(ref > 0.3 && ref < 0.55, `sakura reference ${ref}`);
});

test('migration: every preset keeps its exact look at its own amount', () => {
    for (const [name, theme, comp] of presets()) {
        for (const g of [glass(), glass({ amount: Model.deriveReference(theme) })]) {
            const ctx = Model.context(g, theme, theme.lightMode);
            for (const v of VARIANTS) {
                for (const floor of [0, 0.6, 0.95]) {
                    assert.equal(Model.variantOpacity(ctx, v, designOf(theme, v), '', floor), designOf(theme, v), `${name} ${v} floor ${floor}`);
                    for (const s of Model.SURFACES)
                        assert.equal(Model.variantOpacity(ctx, v, designOf(theme, v), s, floor), designOf(theme, v), `${name} ${v} @${s}`);
                }
                assert.equal(Model.effect(ctx, 'tintStrength', v, designOf(theme, v), 'popups'), 0, `${name} tint`);
                assert.equal(Model.effect(ctx, 'borderHighlight', v, designOf(theme, v), 'popups'), 0, `${name} highlight`);
            }
            const t = theme.terminalOpacity >= 0 ? theme.terminalOpacity : theme.srBg.opacity;
            assert.equal(Model.terminalOpacity(ctx, theme, 0.9), t, `${name} terminal`);
            assert.equal(Model.shadowScale(ctx), 1, `${name} shadow`);
            const opts = { compositor: comp, resolve: () => ({ r: 0, g: 0, b: 0, a: 1 }), borderSize: 2, rounding: 8 };
            const before = plain(Appearance.buildHyprlandConfig(opts));
            const after = plain(Appearance.buildHyprlandConfig(Object.assign({ glass: Model.compositor(ctx, comp) }, opts)));
            assert.deepEqual(after, before, `${name} compositor`);
            assert.equal(Model.shellBlur(ctx), true);
        }
    }
});

test('amount 0 is solid, 1 is very glassy, monotonic in between', () => {
    for (const [name, theme, comp] of presets()) {
        const at = a => Model.context(glass({ amount: a }), theme, theme.lightMode);
        for (const v of VARIANTS) {
            const d = designOf(theme, v);
            if (!(d > 0)) {
                assert.equal(Model.variantOpacity(at(1), v, d, '', 0), d, `${name} ${v} transparent by design stays`);
                continue;
            }
            assert.equal(Model.variantOpacity(at(0), v, d, '', 0), 1, `${name} ${v} solid at 0`);
            let prev = 1;
            for (let a = 0; a <= 1.0001; a += 0.1) {
                const o = Model.variantOpacity(at(a), v, d, '', 0);
                assert.ok(o <= prev + 1e-9, `${name} ${v} grows at ${a}`);
                prev = o;
            }
            // A preset already at the end of the curve (reference 1) keeps its look at 1.
            if (Model.deriveReference(theme) < 1)
                assert.ok(Model.variantOpacity(at(1), v, d, '', 0) <= Curve.at('opacity', 1, false) + 1e-9, `${name} ${v} glassy at 1`);
        }
        assert.equal(Model.compositor(at(0), comp).blur.enabled, Model.deriveReference(theme) === 0 ? comp.blurEnabled : false, `${name} blur at 0`);
        const k1 = Model.compositor(at(1), comp);
        if (Model.deriveReference(theme) < 1)
            assert.ok(k1.blur.enabled && k1.blur.size >= 12 && k1.shadowScale > 1, `${name} glassy blur at 1`);
    }
});

test('legibility: glass never drops below the WCAG floor it is given', () => {
    const sakura = require('./fixtures/glass/sakura-glass.json').theme;
    const ctx = Model.context(glass({ amount: 1 }), sakura, false);
    for (const v of ['popup', 'pane', 'common', 'bg'])
        assert.ok(Model.variantOpacity(ctx, v, designOf(sakura, v), '', 0.66) >= 0.66, v);
    // A design already below the floor is never made worse.
    assert.equal(Model.variantOpacity(ctx, 'internalbg', 0.7, '', 0.9), 0.7);
    assert.ok(Model.variantOpacity(ctx, 'internalbg', 0.7, '', 0.5) < 0.7);
});

test('contrast: worst case over black and white backdrops', () => {
    assert.equal(Math.round(Contrast.worstContrast(hex('#000000'), hex('#ffffff'), 1)), 21);
    assert.equal(Contrast.worstContrast(hex('#000000'), hex('#ffffff'), 0), 1);
    const pairs = [['#1a1112', '#f0dedf'], ['#fff8f7', '#22191a'], ['#0b1326', '#dae2fd'], ['#3d3639', '#ffffff'], ['#f5f5f5', '#202020']];
    for (const [s, t] of pairs) {
        const a = Contrast.minOpacity(hex(s), hex(t), 4.5);
        assert.ok(a > 0 && a < 1, `${s} floor ${a}`);
        assert.ok(Contrast.worstContrast(hex(s), hex(t), a) >= 4.5 - 1e-6, `${s} at floor`);
        assert.ok(Contrast.worstContrast(hex(s), hex(t), a - 0.01) < 4.5, `${s} floor is minimal`);
        // Any concrete wallpaper color is at least as good as the worst case.
        for (const b of ['#ff0000', '#00ff88', '#808080', '#ffffff', '#000000']) {
            const c = Contrast.over(hex(s), hex(b), a);
            assert.ok(Contrast.ratio(Contrast.luminance(hex(t)), Contrast.luminance(c)) >= 4.5 - 1e-6, `${s} over ${b}`);
        }
    }
    assert.equal(Contrast.minOpacity(hex('#777777'), hex('#888888'), 4.5), 1, 'unreachable -> opaque');
});

test('glass off: solid surfaces, no blur, no effects', () => {
    const fixture = require('./fixtures/glass/sakura-glass.json');
    const sakura = { theme: Object.assign(plain(ThemeDefaults), fixture.theme), compositor: fixture.compositor };
    const ctx = Model.context(glass({ enabled: false, amount: 0.9 }), sakura.theme, false);
    for (const v of VARIANTS) {
        const d = designOf(sakura.theme, v);
        assert.equal(Model.variantOpacity(ctx, v, d, '', 0), d > 0 ? 1 : d, v);
        assert.equal(Model.effect(ctx, 'borderHighlight', v, d, 'popups'), 0);
    }
    assert.equal(Model.terminalOpacity(ctx, sakura.theme, 0), 1);
    assert.equal(Model.compositor(ctx, sakura.compositor).blur.enabled, false);
    assert.equal(Model.shellBlur(ctx), false);
});

test('overrides: advanced values are absolute, surfaces override their own amount', () => {
    const theme = ThemeDefaults;
    const g = glass({ amount: 0.5 });
    g.advanced.blurSize = 20;
    g.advanced.opacity = 0.75;
    g.surfaces.dock.amount = 0;
    g.surfaces.windows.inactiveOpacity = 0.1;
    const ctx = Model.context(g, theme, false);
    const k = Model.compositor(ctx, CompositorDefaults);
    assert.equal(k.blur.size, 20);
    assert.equal(k.inactiveOpacity, 0.3, 'window opacity clamped to 0.3');
    assert.equal(k.activeOpacity, 1, 'auto keeps windows opaque');
    assert.equal(Model.variantOpacity(ctx, 'popup', 1, 'popups', 0), 0.75);
    assert.equal(Model.variantOpacity(ctx, 'popup', 1, 'popups', 0.8), 0.8, 'override still clamped by the floor');
    assert.equal(Model.surfaceAmount(ctx, 'dock'), 0);
    assert.equal(Model.surfaceAmount(ctx, 'notch'), 0.5);
    assert.equal(Model.variantOpacity(ctx, 'primary', 0.4, '', 0.9), 0.4, 'accent variants are not glass');
    // Pinned reference: the same preset values now mean amount 0.2.
    const pinned = Model.context(glass({ referenceAmount: 0.2 }), theme, false);
    assert.equal(pinned.reference, 0.2);
    assert.equal(pinned.master, 0.2);
});

test('compositor overlay is a no-op without glass and scales the shadow', () => {
    const opts = { compositor: CompositorDefaults, resolve: () => ({ r: 1, g: 1, b: 1, a: 1 }) };
    const base = plain(Appearance.buildHyprlandConfig(opts));
    assert.deepEqual(plain(Appearance.applyGlass(plain(base), null)), base);
    const g = plain(Appearance.applyGlass(plain(base), { blur: { size: 9, enabled: true }, activeOpacity: 0.9, shadowScale: 2 }));
    assert.equal(g.decoration.blur.size, 9);
    assert.equal(g.decoration.blur.passes, base.decoration.blur.passes);
    assert.equal(g.decoration.active_opacity, 0.9);
    assert.equal(g.decoration.shadow.range, base.decoration.shadow.range * 2);
});
