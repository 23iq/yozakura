// Timer helpers (modules/services/timers/TimerFormat.js): time left from the
// backend view, display rows, formatting, quick input preview.
const { test } = require('node:test');
const assert = require('node:assert/strict');
const path = require('node:path');
const { loadLibrary } = require('./lib/qmljs.cjs');

const F = loadLibrary(path.join(__dirname, '../modules/services/timers/TimerFormat.js'));
const plain = v => JSON.parse(JSON.stringify(v));
const tr = (k, ...a) => k + (a.length ? '(' + a.join(',') + ')' : '');

const NOW = 1_800_000_000_000;

test('time left: running counts to endsAt, paused keeps leftMs, ringing is 0', () => {
    assert.equal(F.timerLeft({ state: 'running', endsAt: NOW + 61_000, leftMs: 5 }, NOW), 61_000);
    assert.equal(F.timerLeft({ state: 'running', endsAt: NOW - 5 }, NOW), 0);
    assert.equal(F.timerLeft({ state: 'paused', leftMs: 30_000 }, NOW), 30_000);
    assert.equal(F.timerLeft({ state: 'ringing', leftMs: 30_000 }, NOW), 0);
    assert.equal(F.timerLeft(null, NOW), 0);
});

test('stopwatch elapsed', () => {
    assert.equal(F.stopwatchElapsed({ state: 'running', startedAt: NOW - 2000, accumMs: 500 }, NOW), 2500);
    assert.equal(F.stopwatchElapsed({ state: 'paused', accumMs: 900, elapsedMs: 900 }, NOW), 900);
    assert.equal(F.stopwatchElapsed({ state: 'idle' }, NOW), 0);
    assert.equal(F.stopwatchActive({ state: 'paused' }), true);
    assert.equal(F.stopwatchActive({ state: 'idle' }), false);
    assert.deepEqual(plain(F.laps({ laps: [{ n: 1 }, { n: 2 }] })).map(l => l.n), [2, 1], 'newest first');
});

test('formatting', () => {
    assert.equal(F.clock(65_000), '01:05');
    assert.equal(F.clock(64_001), '01:05', 'counts down rounding up');
    assert.equal(F.clock(64_999, false), '01:04', 'stopwatch rounds down');
    assert.equal(F.clock(3_725_000), '1:02:05');
    assert.equal(F.compact(45_000), '45s');
    assert.equal(F.compact(25 * 60_000), '25m');
    assert.equal(F.compact(24 * 60_000 + 1), '25m');
    assert.equal(F.compact(65 * 60_000), '1h 5m');
    assert.equal(F.compact(120 * 60_000), '2h');
    assert.equal(F.label(90_000, true), '01:30');
    assert.equal(F.label(90_000, false), '2m');
    assert.equal(F.duration(600), '10m');
    assert.equal(F.duration(5400), '1h 30m');
    assert.equal(F.duration(90), '1m 30s');
    assert.equal(F.duration(0), '0s');
    const at = new Date(2026, 9, 6, 18, 5).getTime();
    assert.equal(F.timeOfDay(at, false), '18:05');
    assert.equal(F.timeOfDay(at, true), '6:05 PM');
    assert.equal(F.timeOfDay(new Date(2026, 9, 6, 0, 30).getTime(), true), '12:30 AM');
});

test('titles: name, Pomodoro phase, fallback', () => {
    assert.equal(F.timerTitle({ name: 'tea' }, tr), 'tea');
    assert.equal(F.timerTitle({}, tr), 'timers.timer');
    assert.equal(F.timerTitle({ pomodoro: { phase: 'break' } }, tr), 'timers.phase.break');
    assert.equal(F.timerTitle({ name: 'Study', pomodoro: { phase: 'work' } }, tr), 'Study · timers.phase.work');
});

test('rows: ringing first, then running, paused; progress and left at now', () => {
    const view = {
        timers: [
            { id: 't1', state: 'paused', leftMs: 30_000, totalMs: 60_000, createdAt: 1 },
            { id: 't2', state: 'running', endsAt: NOW + 15_000, totalMs: 60_000, createdAt: 2 },
            { id: 't3', state: 'ringing', totalMs: 60_000, createdAt: 3 },
            { id: 't4', state: 'running', endsAt: NOW + 45_000, totalMs: 60_000, createdAt: 0 }
        ],
        reminders: [{ id: 'r2', at: NOW + 3 * 3600_000, message: 'late' }, { id: 'r1', at: NOW + 600_000, message: 'soon' }]
    };
    const rows = plain(F.timerRows(view, NOW));
    assert.deepEqual(rows.map(r => r.id), ['t3', 't4', 't2', 't1']);
    assert.equal(rows[0].ringing, true);
    assert.equal(rows[0].progress, 0);
    assert.equal(rows[2].leftMs, 15_000);
    assert.equal(rows[2].progress, 0.25);
    assert.equal(rows[3].leftMs, 30_000);
    const all = plain(F.reminderRows(view, NOW, 0));
    assert.deepEqual(all.map(r => r.id), ['r1', 'r2']);
    assert.deepEqual(plain(F.reminderRows(view, NOW, 15 * 60_000)).map(r => r.id), ['r1'], 'lead time filter');
    assert.deepEqual(plain(F.timerRows({}, NOW)), []);
});

test('quick input preview of an Intent', () => {
    assert.deepEqual(plain(F.preview({ kind: 'timer', seconds: 600, name: 'tea' }, tr, false)), { icon: 'timer', text: 'timers.preview.timer(10m) · tea' });
    const at = new Date(2026, 9, 6, 18, 0).getTime();
    assert.deepEqual(plain(F.preview({ kind: 'reminder', at, name: 'call mom' }, tr, false)), { icon: 'alarm', text: 'timers.preview.reminder(18:00) · call mom' });
    assert.equal(F.preview({ kind: 'stopwatch' }, tr).icon, 'watch');
    assert.equal(F.preview({ kind: 'pomodoro' }, tr).icon, 'countdown');
    assert.equal(F.preview(null, tr), null);
    assert.equal(F.preview({ kind: 'weird' }, tr), null);
});
