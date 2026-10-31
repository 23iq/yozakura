const { test } = require('node:test');
const assert = require('node:assert/strict');
const Presets = require('./lib/presetsets.cjs');
const path = require('node:path');
const { loadLibrary } = require('./lib/qmljs.cjs');
const B = loadLibrary(path.join(__dirname, '../config/motion/MotionBudget.js'));
const P = loadLibrary(path.join(__dirname, '../config/motion/MotionProfiles.js'));

test('tokens respect the budget at any base', () => {
    for (const base of [0, 100, 300, 2000]) {
        assert.ok(B.token('enter', base) <= 220);
        assert.ok(B.token('exit', base) <= 160);
        assert.ok(B.token('morph', base) <= 280);
        assert.ok(B.token('emphasis', base) <= 360);
        assert.ok(B.token('micro', base) <= 120);
        assert.ok(B.token('glide', base) <= 220);
        if (base > 0) assert.ok(B.token('exit', base) < B.token('enter', base), `exit < enter at ${base}`);
    }
    assert.equal(B.token('glide', 0), 0);
    assert.equal(B.token('pan', 0), 0);
    assert.ok(B.token('pan', 2000) <= 700);
    assert.ok(B.token('pan', 300) > B.token('glide', 300));
    assert.ok(B.token('micro', 300) < B.token('glide', 300));
    assert.equal(B.token('enter', 0), 0);
    assert.equal(B.token('morph', 300), 280);
});

test('shellBase compresses above the knee and caps slow profiles', () => {
    assert.equal(B.shellBase(340, 1.6), 240);
    assert.equal(B.shellBase(220, 0.6), 132);
    assert.equal(B.shellBase(160, 1), 160);
    assert.equal(B.shellBase(300, 1), 230);
    assert.equal(B.shellBase(300, 0), 0);
    // Monotonic: a longer setting is never faster
    let prev = -1;
    for (let d = 0; d <= 400; d += 10) {
        const v = B.shellBase(d, 1);
        assert.ok(v >= prev, `shellBase(${d})`);
        prev = v;
    }
});

test('enter easings are never In/InOut, soft or (for panels) bouncy', () => {
    assert.equal(B.enterEasing('InOutSine'), 'OutCubic');
    assert.equal(B.enterEasing('OutSine'), 'OutCubic');
    assert.equal(B.enterEasing('InOutExpo'), 'OutExpo');
    assert.equal(B.enterEasing('InCubic'), 'OutCubic');
    assert.equal(B.enterEasing('OutBack'), 'OutBack');
    assert.equal(B.panelEasing('OutBack'), 'OutQuart');
    assert.equal(B.panelEasing('OutElastic'), 'OutQuart');
    assert.equal(B.panelEasing('OutQuart'), 'OutQuart');
    assert.equal(B.exitEasing('OutSine'), 'InQuad');
    assert.equal(B.exitEasing('Linear'), 'Linear');
});

test('a staggered list never adds more than STAGGER_MAX', () => {
    assert.equal(B.stagger(0, 40), 0);
    assert.equal(B.stagger(2, 40), 80);
    assert.equal(B.stagger(100, 40), B.STAGGER_MAX);
    assert.equal(B.stagger(5, 0), 0);
});

test('every motion profile is within the shell and compositor budget', () => {
    for (const p of P.all()) {
        if (p.disabled) continue;
        assert.ok(p.shell.scale <= 1.2, `${p.id} shell scale ${p.shell.scale}`);
        assert.deepEqual(JSON.parse(JSON.stringify(B.compositorViolations(p))), [], p.id);
    }
});

test('every bundled preset set has a budget-friendly animDuration', () => {
    const sets = Presets.listSets();
    assert.ok(sets.length >= 10);
    for (const name of sets) {
        const d = (Presets.composeSet(name).theme || {}).animDuration;
        if (d === undefined) continue;
        assert.ok(d >= 160 && d <= 300, `${name}: animDuration ${d}`);
    }
});

// The shell motion a bundled set really plays: its theme.animDuration through
// its motion profile's scale (and an explicit motionDurationScale), like
// Config.animDuration does, then each token.
function setMotion(name) {
    const c = Presets.composeSet(name);
    const theme = c.theme || {};
    const comp = c.compositor || {};
    const profile = P.resolveId(comp.motionProfile);
    const anim = theme.animDuration === undefined ? 300 : theme.animDuration;
    const scale = profile.disabled ? 0 : profile.shell.scale;
    const user = comp.motionDurationScale > 0 ? comp.motionDurationScale : 1;
    const base = Math.round(B.shellBase(anim, scale) * user);
    const t = {};
    for (const k of ['enter', 'exit', 'morph', 'emphasis', 'micro', 'glide', 'pan']) t[k] = B.token(k, base);
    return { base, t, profile, palette: theme.paletteTransitionDuration };
}

test('every bundled set plays its shell motion inside the budget', () => {
    for (const name of Presets.listSets()) {
        const { base, t, profile } = setMotion(name);
        if (base === 0) continue;
        assert.ok(base <= 240, `${name}: base ${base}`);
        assert.ok(t.enter <= 220 && t.enter >= 80, `${name}: enter ${t.enter}`);
        assert.ok(t.exit < t.enter && t.exit <= 160, `${name}: exit ${t.exit}`);
        assert.ok(t.glide <= 220 && t.micro <= 120, `${name}: glide ${t.glide} micro ${t.micro}`);
        assert.ok(t.morph <= 280 && t.pan <= 700, `${name}: morph ${t.morph} pan ${t.pan}`);
        // Panels decelerate crisply and never overshoot, whatever the profile.
        const panel = B.panelEasing(profile.shell.easing);
        assert.ok(!/^(In|OutSine|OutQuad|OutBack|OutElastic|OutBounce)/.test(panel), `${name}: panel easing ${panel}`);
    }
});

test('the island-less flagship sets are calm, not slow', () => {
    for (const name of ['Kotoba', 'Hanami', 'Emaki']) {
        const { t, palette } = setMotion(name);
        assert.ok(t.enter >= 150 && t.enter <= 200, `${name}: enter ${t.enter}`);
        assert.ok(t.exit >= 100 && t.exit <= 140, `${name}: exit ${t.exit}`);
        assert.ok(palette <= 700, `${name}: palette crossfade ${palette}`);
    }
    // Device is the quick one, but an exit still reads as motion, not a cut.
    const dev = setMotion('Device');
    assert.ok(dev.t.enter >= 110 && dev.t.enter <= 160, `Device: enter ${dev.t.enter}`);
    assert.ok(dev.t.exit >= 80, `Device: exit ${dev.t.exit}`);
});

test('the gentle profile is calm, not slow: no compositor leaf above 300 ms but the border fade', () => {
    const g = P.get('gentle');
    for (const [node, leaf] of Object.entries(g.leaves)) {
        if (node === 'border') continue;
        assert.ok(leaf.speed <= 3, `gentle ${node}: speed ${leaf.speed}`);
    }
});
