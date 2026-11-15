// The Power page's idle timeline model (modules/settings/editors/IdleSteps.js):
// idle listeners read as four steps, a step moved or turned off rewrites
// only its listener, the track scale, and handles kept in order.
const { test } = require('node:test');
const assert = require('node:assert/strict');
const path = require('node:path');
const { loadLibrary } = require('./lib/qmljs.cjs');

const S = loadLibrary(path.join(__dirname, '..', 'modules/settings/editors/IdleSteps.js'));
const plain = v => JSON.parse(JSON.stringify(v));
const DEFAULTS = [
    { timeout: 150, onTimeout: 'yozakura brightness 10 -s', onResume: 'yozakura brightness -r' },
    { timeout: 300, onTimeout: 'loginctl lock-session' },
    { timeout: 330, onTimeout: 'yozakura screen off', onResume: 'yozakura screen on' },
    { timeout: 1800, onTimeout: 'yozakura suspend' },
];
const tr = k => ({ 'prefs.power.never': 'Never', 'prefs.power.seconds': '%1 s', 'prefs.power.minutes': '%1 min',
    'prefs.power.minutes_seconds': '%1 min %2 s', 'prefs.power.hours': '%1 h', 'prefs.power.hours_minutes': '%1 h %2 min' })[k];

test('the default listeners read as dim, lock, screen off and sleep', () => {
    assert.deepEqual(plain(S.read(DEFAULTS)), { dim: 150, lock: 300, off: 330, sleep: 1800 });
    assert.equal(S.stepOf({ onTimeout: 'hyprlock' }), 'lock');
    assert.equal(S.stepOf({ onTimeout: 'systemctl hibernate' }), 'sleep');
    assert.equal(S.stepOf({ onTimeout: 'notify-send hi' }), '');
    assert.deepEqual(plain(S.read([])), { dim: null, lock: null, off: null, sleep: null });
});

test('moving a step rewrites its listener only and keeps the rest (sorted)', () => {
    const custom = DEFAULTS.concat([{ timeout: 600, onTimeout: 'notify-send away' }]);
    const out = S.withStep(custom, 'lock', 600);
    assert.equal(out.length, 5);
    assert.equal(out.find(l => l.onTimeout === 'loginctl lock-session').timeout, 600);
    assert.ok(out.some(l => l.onTimeout === 'notify-send away'), 'a listener of no step is kept');
    for (let i = 1; i < out.length; i++)
        assert.ok(out[i - 1].timeout <= out[i].timeout, 'sorted by time');
    assert.equal(custom[1].timeout, 300, 'the input is not changed');
});

test('never removes the step; turning it on again brings its default listener', () => {
    const off = S.withStep(DEFAULTS, 'sleep', null);
    assert.equal(S.read(off).sleep, null);
    assert.equal(off.length, 3);
    const back = S.withStep(off, 'sleep', 3600);
    assert.deepEqual(plain(back[back.length - 1]), { onTimeout: 'yozakura suspend', timeout: 3600 });
});

test('the track: log scale, snapped times, never past the time span', () => {
    assert.equal(S.toPos(S.MIN), 0);
    assert.ok(Math.abs(S.toPos(S.MAX) - S.TIME_SPAN) < 1e-9);
    assert.equal(S.toPos(null), 1);
    for (const t of S.NICE)
        assert.equal(S.fromPos(S.toPos(t)), t, `${t} round-trips`);
    assert.equal(S.fromPos(0.99), null);
    assert.equal(S.fromPos(-1), S.MIN);
});

test('a step stays between the steps that are on around it', () => {
    const steps = S.read(DEFAULTS);
    assert.deepEqual(plain(S.range(steps, 'lock')), { min: 150, max: 330 });
    assert.equal(S.clampTo(steps, 'lock', 3600), 330);
    assert.equal(S.clampTo(steps, 'lock', 30), 150);
    assert.equal(S.clampTo(steps, 'lock', null), null, 'any step may go to never, later ones on or not');
    assert.equal(S.clampTo(steps, 'dim', null), null, 'dimming can be turned off while lock and sleep stay');
    assert.equal(S.clampTo(steps, 'sleep', null), null, 'the last step may go to never');
    assert.equal(S.clampTo(Object.assign({}, steps, { off: null, sleep: null }), 'lock', null), null);
    // a step off between two that are on: they still order around it
    assert.deepEqual(plain(S.range(Object.assign({}, steps, { lock: null }), 'off')), { min: 150, max: 1800 });
});

test('two listeners of one step: moving the knob moves both, never removes the shown one only', () => {
    // screen dim at 150 s and the keyboard backlight off at 160 s
    const two = [
        { timeout: 150, onTimeout: 'brightnessctl -s set 10', onResume: 'brightnessctl -r' },
        { timeout: 160, onTimeout: 'brightnessctl -sd rgb:kbd_backlight set 0', onResume: 'brightnessctl -rd rgb:kbd_backlight' },
        { timeout: 300, onTimeout: 'loginctl lock-session' },
    ];
    const moved = S.withStep(two, 'dim', 200);
    assert.equal(moved.length, 3, 'no listener is lost');
    assert.equal(moved.find(l => /kbd/.test(l.onTimeout)).timeout, 210, 'the second one keeps its 10 s after the first');
    assert.equal(S.read(moved).dim, 200);
    const off = S.withStep(two, 'dim', null);
    assert.equal(off.length, 2, 'never removes the first listener of the step only');
    assert.ok(off.some(l => /kbd/.test(l.onTimeout)), 'the keyboard backlight listener stays');
    assert.equal(S.read(off).dim, 160, 'and now shows as the step');
    // two lock listeners: both kept on a move
    const locks = [{ timeout: 300, onTimeout: 'loginctl lock-session' }, { timeout: 310, onTimeout: 'hyprlock --immediate' }];
    assert.deepEqual(plain(S.withStep(locks, 'lock', 600).map(l => l.timeout)), [600, 610]);
});

test('the keyboard steps a knob through the snapped times inside its range', () => {
    const steps = S.read(DEFAULTS); // dim 150, lock 300, off 330, sleep 1800
    assert.equal(S.nudge(steps, 'dim', 1), 180);
    assert.equal(S.nudge(steps, 'dim', -1), 120);
    assert.equal(S.nudge(steps, 'lock', 1), 330, 'stops at the next step');
    assert.equal(S.nudge(steps, 'off', -1), 300, 'stops at the previous step');
    assert.equal(S.nudge(steps, 'sleep', 1), 2700);
    assert.equal(S.nudge(Object.assign({}, steps, { sleep: 7200 }), 'sleep', 1), null, 'past the last time: never');
    assert.equal(S.nudge(Object.assign({}, steps, { sleep: null }), 'sleep', -1), 7200, 'from never back to the latest time');
    assert.equal(S.nudge(Object.assign({}, steps, { dim: null }), 'dim', -1), 300, 'from never: the latest time before the next step');
    assert.equal(S.nudge(Object.assign({}, steps, { dim: null }), 'dim', 1), null);
});

test('handles at nearly the same time are pushed apart inside the track', () => {
    const xs = S.spread([100, 102, 104, 400], 30, 0, 500);
    assert.deepEqual(plain(xs), [100, 130, 160, 400]);
    const end = S.spread([480, 490, 500], 30, 0, 500);
    assert.deepEqual(plain(end), [440, 470, 500]);
});

test('knob centres: steps that are on at their times, steps that are off in the never zone', () => {
    // no dimming, lock at 5 min, sleep at 30 min (hypridle without dim)
    const steps = { dim: null, lock: 300, off: null, sleep: 1800 };
    const c = S.centres(steps, 0, 500, 30);
    assert.ok(Math.abs(c.lock - S.toPos(300) * 500) < 1e-6, `lock at its time (${c.lock})`);
    assert.ok(Math.abs(c.sleep - S.toPos(1800) * 500) < 1e-6, `sleep at its time (${c.sleep})`);
    for (const id of ['dim', 'off']) {
        assert.ok(c[id] >= 500 * S.TIME_SPAN && c[id] <= 500, `${id} in the never zone (${c[id]})`);
    }
    assert.ok(c.dim !== c.off, 'off knobs do not sit on each other where there is room');
    // the defaults: nearly equal times pushed apart, all inside the time span
    const d = S.centres(S.read(DEFAULTS), 0, 500, 30);
    assert.ok(d.off - d.lock >= 30 - 1e-9 && d.lock - d.dim >= 30 - 1e-9);
    assert.ok(d.sleep <= 500 * S.TIME_SPAN + 1e-9);
});

test('times read as people say them', () => {
    assert.equal(S.label(45, tr), '45 s');
    assert.equal(S.label(150, tr), '2 min 30 s');
    assert.equal(S.label(300, tr), '5 min');
    assert.equal(S.label(5400, tr), '1 h 30 min');
    assert.equal(S.label(7200, tr), '2 h');
    assert.equal(S.label(null, tr), 'Never');
});
