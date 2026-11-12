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
    assert.equal(S.clampTo(steps, 'lock', null), 330, 'not never while a later step is on');
    assert.equal(S.clampTo(steps, 'sleep', null), null, 'the last step may go to never');
    assert.equal(S.clampTo(Object.assign({}, steps, { off: null, sleep: null }), 'lock', null), null);
});

test('handles at nearly the same time are pushed apart inside the track', () => {
    const xs = S.spread([100, 102, 104, 400], 30, 0, 500);
    assert.deepEqual(plain(xs), [100, 130, 160, 400]);
    const end = S.spread([480, 490, 500], 30, 0, 500);
    assert.deepEqual(plain(end), [440, 470, 500]);
});

test('times read as people say them', () => {
    assert.equal(S.label(45, tr), '45 s');
    assert.equal(S.label(150, tr), '2 min 30 s');
    assert.equal(S.label(300, tr), '5 min');
    assert.equal(S.label(5400, tr), '1 h 30 min');
    assert.equal(S.label(7200, tr), '2 h');
    assert.equal(S.label(null, tr), 'Never');
});
