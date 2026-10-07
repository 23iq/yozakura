const { test } = require('node:test');
const assert = require('node:assert/strict');
const Presets = require('./lib/presetsets.cjs');
const path = require('node:path');
const { loadLibrary } = require('./lib/qmljs.cjs');
const B = loadLibrary(path.join(__dirname, '../config/motion/MotionBudget.js'));
const P = loadLibrary(path.join(__dirname, '../config/motion/MotionProfiles.js'));

test('tokens respect the budget at any base', () => {
    for (const base of [0, 100, 300, 2000]) {
        assert.ok(B.token('enter', base) <= 260);
        assert.ok(B.token('exit', base) <= 180);
        assert.ok(B.token('morph', base) <= 360);
        assert.ok(B.token('emphasis', base) <= 450);
    }
    assert.equal(B.token('enter', 0), 0);
    assert.equal(B.token('morph', 300), 360);
});

test('shellBase caps slow profiles', () => {
    assert.equal(B.shellBase(340, 1.6), 300);
    assert.equal(B.shellBase(220, 0.6), 132);
    assert.equal(B.shellBase(300, 0), 0);
});

test('enter easings are never In/InOut', () => {
    assert.equal(B.enterEasing('InOutSine'), 'OutSine');
    assert.equal(B.enterEasing('InOutExpo'), 'OutExpo');
    assert.equal(B.enterEasing('InCubic'), 'OutCubic');
    assert.equal(B.enterEasing('OutBack'), 'OutBack');
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
