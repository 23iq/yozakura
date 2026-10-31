const { test } = require('node:test');
const assert = require('node:assert/strict');
const path = require('node:path');
const { loadLibrary } = require('./lib/qmljs.cjs');
const P = loadLibrary(path.join(__dirname, '../modules/notifications/strips/StripPhysics.js'));

test('no sway with motion off; capped otherwise', () => {
    assert.equal(P.swayDuration(0), 0);
    assert.equal(P.swayDuration(-5), 0);
    assert.equal(P.swayDuration(300), 1200);
    assert.equal(P.swayDuration(5000), 2400);
});

test('the sway starts and ends at rest and decays', () => {
    assert.equal(P.swayAngle(0, 7), 0);
    assert.equal(P.swayAngle(1, 7), 0);
    assert.equal(P.swayAngle(0.4, 0), 0);
    const peaks = [];
    for (let i = 0; i <= 200; i++)
        peaks.push(Math.abs(P.swayAngle(i / 200, 7)));
    const first = Math.max(...peaks.slice(0, 40)), late = Math.max(...peaks.slice(140));
    assert.ok(first > 2 && first <= 7, String(first));
    assert.ok(late < first / 4, 'damped');
    // It swings both ways
    const signs = new Set();
    for (let i = 1; i < 100; i++)
        signs.add(Math.sign(P.swayAngle(i / 100, 7)));
    assert.ok(signs.has(1) && signs.has(-1));
});

test('neighbours get a light nudge, far strips none', () => {
    assert.equal(P.amplitude(0), 7);
    assert.ok(P.amplitude(1) < 2.5 && P.amplitude(1) > 0);
    assert.ok(P.amplitude(2) < P.amplitude(1));
    assert.equal(P.amplitude(3), 0);
});

test('pull away opens, flick back or swipe dismisses, per edge', () => {
    assert.equal(P.gesture('top', 0, 40, 24), 'expand');
    assert.equal(P.gesture('top', 0, -30, 24), 'dismiss');
    assert.equal(P.gesture('top', 40, 0, 24), 'dismiss');
    assert.equal(P.gesture('top', 10, 10, 24), 'none');
    assert.equal(P.gesture('bottom', 0, -40, 24), 'expand');
    assert.equal(P.gesture('bottom', 0, 40, 24), 'dismiss');
    assert.equal(P.gesture('left', 40, 0, 24), 'expand');
    assert.equal(P.gesture('right', 40, 0, 24), 'dismiss');
    assert.equal(P.gesture('right', -40, 0, 24), 'expand');
});

test('a dragged strip follows the pointer around its pivot, within a limit', () => {
    assert.ok(P.dragTilt('top', 30, 100) < 0, 'drag right swings a hanging strip counter-clockwise');
    assert.ok(P.dragTilt('bottom', 30, 100) > 0);
    assert.ok(P.dragTilt('left', 30, 100) > 0);
    assert.equal(Math.abs(P.dragTilt('top', 1000, 10)), 24);
    assert.equal(Math.abs(P.dragTilt('top', 0, 100)), 0);
});

test('timeouts lift away gently, flicks leave at once', () => {
    assert.equal(P.exitDuration('flick', 200), 200);
    assert.equal(P.exitDuration('lift', 200), 400);
    assert.equal(P.exitDuration('lift', 0), 0);
});
