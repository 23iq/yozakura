// Motion profiles (config/motion): registry integrity, resolution of the
// Hyprland animation tree, overrides, Lua rendering, curve sampling, and the
// sakura profile reproducing the hand-written sakura.lua state exactly.
const { test } = require('node:test');
const assert = require('node:assert/strict');
const path = require('node:path');
const { loadLibrary } = require('./lib/qmljs.cjs');

const root = path.join(__dirname, '..');
const Profiles = loadLibrary(path.join(root, 'config/motion/MotionProfiles.js'));
const Spec = loadLibrary(path.join(root, 'config/motion/MotionSpec.js'));
const Budget = loadLibrary(path.join(__dirname, '../config/motion/MotionBudget.js'));
const fixture = require('./fixtures/motion/sakura-hyprctl.json');

const plain = v => JSON.parse(JSON.stringify(v));

test('every profile is valid and listed once', () => {
    const ids = Profiles.ids();
    assert.equal(new Set(ids).size, ids.length);
    for (const id of ['smooth', 'springs', 'gentle', 'stepped', 'snappy', 'off', 'sakura'])
        assert.ok(ids.includes(id), id);
    for (const p of Profiles.all())
        assert.deepEqual(plain(Spec.validate(p)), [], p.id);
    assert.equal(Profiles.resolveId('nope').id, Profiles.DEFAULT_ID);
});

test('resolve emits every tree node once, parents first, with known curves', () => {
    for (const p of Profiles.all()) {
        const spec = Spec.resolve({ profile: p.id });
        if (p.disabled) {
            assert.equal(spec.enabled, false);
            assert.equal(spec.animations.length, 0);
            assert.equal(spec.shell.scale, 0);
            continue;
        }
        const leaves = spec.animations.map(a => a.leaf);
        assert.deepEqual(plain(leaves), plain(Spec.nodes()), p.id);
        const names = spec.curves.map(c => c.name);
        for (const a of spec.animations) {
            assert.ok(a.speed > 0, `${p.id}.${a.leaf} speed`);
            assert.ok(names.includes(a.curve) || ['default', 'linear'].includes(a.curve), `${p.id}.${a.leaf} curve ${a.curve}`);
            assert.equal(a.kind, (spec.curves.find(c => c.name === a.curve) || {}).type === 'spring' ? 'spring' : 'bezier');
        }
        // Only referenced curves are emitted.
        for (const c of spec.curves)
            assert.ok(spec.animations.some(a => a.curve === c.name), `${p.id}: unused curve ${c.name}`);
    }
});

// Effective value of a node in `hyprctl animations -j` output (non-overridden
// nodes inherit their parent's config, like Hyprland does).
function effective(node) {
    const byName = Object.fromEntries(fixture.animations.map(a => [a.name, a]));
    let n = node;
    while (n && byName[n] && !byName[n].overridden)
        n = Spec.parentOf(n);
    return byName[n || 'global'];
}
function curvePoints(name, curves) {
    const c = curves.find(x => x.name === name);
    return c.X0 !== undefined ? [c.X0, c.Y0, c.X1, c.Y1] : [c.points[0][0], c.points[0][1], c.points[1][0], c.points[1][1]];
}

test('sakura profile reproduces the sakura.lua animation state exactly', () => {
    const spec = Spec.resolve({ profile: 'sakura', vertical: false });
    const builtin = [{ name: 'default', X0: 0, Y0: 0.75, X1: 0.15, Y1: 1 }];
    for (const a of spec.animations) {
        const want = effective(a.leaf);
        assert.ok(want, `${a.leaf} exists in Hyprland`);
        assert.equal(a.enabled, want.enabled, `${a.leaf}.enabled`);
        // The hand-written state, except for the motion budget's compositor caps.
        const own = Profiles.get('sakura').leaves[a.leaf] !== undefined;
        const cap = (own && Budget.COMPOSITOR.find(c => c.re.test(a.leaf)) || { max: Infinity }).max;
        assert.equal(a.speed, Math.min(Math.round(want.speed * 100) / 100, cap), `${a.leaf}.speed`);
        assert.equal(a.style, want.style, `${a.leaf}.style`);
        const got = a.curve === 'default' ? curvePoints('default', builtin) : curvePoints(a.curve, spec.curves);
        assert.deepEqual(got.map(v => Math.round(v * 100) / 100), curvePoints(want.bezier, fixture.curves.concat(builtin)).map(v => Math.round(v * 100) / 100), `${a.leaf}.curve`);
    }
    assert.equal(Spec.animation(spec, 'borderangle').style, 'loop');
    assert.equal(spec.shell.scale, 1);
});

test('vertical bar turns workspace slides vertical, special workspaces untouched', () => {
    const h = Spec.resolve({ profile: 'sakura', vertical: false });
    const v = Spec.resolve({ profile: 'sakura', vertical: true });
    assert.equal(Spec.animation(h, 'workspaces').style, 'slidefade 20%');
    assert.equal(Spec.animation(v, 'workspaces').style, 'slidefadevert 20%');
    assert.equal(Spec.animation(v, 'workspacesIn').style, 'slidefadevert 20%');
    assert.equal(Spec.animation(v, 'specialWorkspaceIn').style, 'slidevert');
    assert.equal(Spec.verticalStyle('slide'), 'slidevert');
    assert.equal(Spec.verticalStyle('slidevert'), 'slidevert');
    assert.equal(Spec.verticalStyle('fade'), 'fade');
});

test('overrides: duration scale, workspace style, border loop, per-node', () => {
    const base = Spec.resolve({ profile: 'smooth' });
    const slow = Spec.resolve({ profile: 'smooth', durationScale: 2 });
    assert.equal(Spec.animation(slow, 'windowsIn').speed, Spec.animation(base, 'windowsIn').speed * 2);
    assert.equal(slow.shell.scale, 2);

    assert.equal(Spec.animation(Spec.resolve({ profile: 'smooth', workspaceStyle: 'fade' }), 'workspaces').style, 'fade');
    assert.equal(Spec.animation(Spec.resolve({ profile: 'smooth', workspaceStyle: 'slide', vertical: true }), 'workspacesOut').style, 'slidevert');

    const loopOn = Spec.resolve({ profile: 'smooth', borderLoop: 'on', borderLoopSpeed: 30 });
    const ba = Spec.animation(loopOn, 'borderangle');
    assert.deepEqual(plain(ba), { leaf: 'borderangle', enabled: true, speed: 30, curve: 'motionLinear', kind: 'bezier', style: 'loop' });
    assert.ok(loopOn.curves.some(c => c.name === 'motionLinear'));
    // The loop speed is a period: never scaled by the duration scale.
    assert.equal(Spec.animation(Spec.resolve({ profile: 'sakura', durationScale: 0.5 }), 'borderangle').speed, 100);
    assert.equal(Spec.animation(Spec.resolve({ profile: 'sakura', borderLoop: 'off' }), 'borderangle').style, '');

    const ov = Spec.resolve({ profile: 'smooth', overrides: { windows: { speed: 7 }, fadeIn: { curve: [0.1, 0.2, 0.3, 1] }, windowsOut: { enabled: false, curve: 'nope' } } });
    assert.equal(Spec.animation(ov, 'windowsIn').speed, 7, 'children inherit an overridden parent');
    assert.equal(Spec.animation(ov, 'fadeIn').curve, 'motionOverrideFadeIn');
    assert.deepEqual(plain(ov.curves.find(c => c.name === 'motionOverrideFadeIn').points), [[0.1, 0.2], [0.3, 1]]);
    assert.equal(Spec.animation(ov, 'windowsOut').enabled, false);
    assert.equal(Spec.animation(ov, 'windowsOut').curve, 'smoothStandard', 'unknown curve names are ignored');
});

test('springs keep their spring kind and a bezier fallback', () => {
    const spec = Spec.resolve({ profile: 'springs' });
    const a = Spec.animation(spec, 'windowsIn');
    assert.equal(a.kind, 'spring');
    const c = spec.curves.find(x => x.name === a.curve);
    assert.equal(c.type, 'spring');
    assert.equal(c.points.length, 2);
    assert.match(Spec.luaAnimation(a), /spring = "springsBounce"/);
    assert.match(Spec.luaCurve(c), /^hl\.curve\("springsBounce", \{ type = "spring", mass = 1, stiffness = 200, dampening = 18 \}\)$/);
});

test('lua chunk: guarded statements, no semicolons, sakura.lua syntax', () => {
    const spec = Spec.resolve({ profile: 'sakura' });
    const chunk = Spec.luaChunk(spec);
    assert.ok(!chunk.includes(';'));
    assert.ok(chunk.startsWith('pcall(hl.config, { animations = { enabled = true } }) pcall(function() hl.curve('));
    assert.ok(!chunk.includes('\n'), 'one line');
    assert.ok(chunk.includes('hl.curve("sakuraOvershoot", { type = "bezier", points = { {0.05, 0.9}, {0.1, 1.08} } })'));
    assert.ok(chunk.includes('hl.animation({ leaf = "windowsIn", enabled = true, speed = 3.5, bezier = "sakuraOvershoot", style = "popin 85%" })'));
    assert.ok(chunk.includes('hl.animation({ leaf = "windowsMove", enabled = true, speed = 3.5, bezier = "sakuraOvershoot" })'));
    assert.ok(chunk.includes('hl.animation({ leaf = "borderangle", enabled = true, speed = 100, bezier = "sakuraLinear", style = "loop" })'));
    assert.equal(Spec.luaChunk(Spec.resolve({ profile: 'off' })), 'pcall(hl.config, { animations = { enabled = false } })');
});

test('curve sampling for previews', () => {
    assert.equal(Spec.bezierAt([0, 0, 1, 1], 0.3).toFixed(3), '0.300');
    assert.equal(Spec.bezierAt([0.4, 0, 0.2, 1], 0), 0);
    assert.equal(Spec.bezierAt([0.4, 0, 0.2, 1], 1), 1);
    // Overshoot curve goes above 1 before settling.
    const peak = Math.max(...Array.from({ length: 50 }, (_, i) => Spec.bezierAt([0.05, 0.9, 0.1, 1.08], i / 50)));
    assert.ok(peak > 1);
    // Stepped: holds, then jumps around the middle.
    assert.ok(Spec.bezierAt([1, 0, 0, 1], 0.3) < 0.15 && Spec.bezierAt([1, 0, 0, 1], 0.7) > 0.85);
    const spring = { type: 'spring', mass: 1, stiffness: 200, dampening: 18 };
    const s = Array.from({ length: 60 }, (_, i) => Spec.springAt(spring, i / 100));
    assert.ok(Math.max(...s) > 1, 'underdamped spring overshoots');
    assert.equal(Spec.curveAt(spring, 1, 0.45), 1);
    assert.equal(Spec.popinScale('popin 85%'), 0.85);
    assert.equal(Spec.popinScale('slide'), 1);
});

test('Go parity fixture is fresh (backend renders the same Lua)', () => {
    const fs = require('node:fs');
    const file = path.join(root, 'backend/pkg/svc/compositor/testdata/motion-parity.json');
    const want = JSON.parse(fs.readFileSync(file, 'utf8'));
    const out = { _comment: want._comment };
    for (const id of ['sakura', 'springs']) {
        const spec = plain(Spec.resolve({ profile: id }));
        out[id] = { spec, lua: Spec.luaChunk(spec) };
    }
    if (process.env.UPDATE_FIXTURES)
        fs.writeFileSync(file, JSON.stringify(out, null, 1) + '\n');
    else
        assert.deepEqual(out, want, 'run UPDATE_FIXTURES=1 node --test tests/motion-profiles.test.cjs');
});

test('smart gaps Lua matches the backend text', () => {
    const App = loadLibrary(path.join(root, 'modules/services/CompositorAppearance.js'));
    assert.equal(App.smartGapsLua(false), 'if __smartGapsRule then pcall(function() __smartGapsRule:set_enabled(false) end) end __smartGapsRule = nil');
    assert.ok(App.smartGapsLua(true).endsWith('pcall(function() __smartGapsRule = hl.workspace_rule({ workspace = "w[tv1]", gaps_in = 0, gaps_out = 0 }) end)'));
    assert.ok(!App.smartGapsLua(true).includes(';'));
});
