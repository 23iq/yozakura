const { test } = require('node:test');
const assert = require('node:assert/strict');
const fs = require('node:fs');
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

test('every bundled preset has a budget-friendly animDuration', () => {
    const dir = path.join(__dirname, '../assets/presets');
    for (const name of fs.readdirSync(dir)) {
        const f = path.join(dir, name, 'theme.json');
        if (!fs.existsSync(f)) continue;
        const d = JSON.parse(fs.readFileSync(f, 'utf8')).animDuration;
        if (d === undefined) continue;
        assert.ok(d >= 160 && d <= 300, `${name}: animDuration ${d}`);
    }
});
