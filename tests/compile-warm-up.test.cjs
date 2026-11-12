const { test } = require('node:test');
const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');
const qmljs = require('./lib/qmljs.cjs');

const Q = qmljs.loadLibrary(path.join(__dirname, '../modules/shell/hosts/CompileQueue.js'));
const W = qmljs.loadLibrary(path.join(__dirname, '../modules/shell/hosts/WarmUp.js'));
const defaults = qmljs.loadLibrary(path.join(__dirname, '../config/defaults/performance.js')).data;

const run = (over) => Q.next({ enabled: true, index: 0, count: 4, busy: false, pending: false, ...over });

test('the entries are the heavy rarely opened views, in first-open order, and exist', () => {
    assert.deepEqual(Array.from(Q.ENTRIES), [
        'modules/widgets/dashboard/DashboardView.qml',
        'modules/widgets/overview/OverviewPopup.qml',
        'modules/settings/SettingsWindow.qml',
        'modules/widgets/presets/PresetsPopup.qml',
    ]);
    for (const f of Q.ENTRIES)
        assert.ok(fs.existsSync(path.join(__dirname, '..', f)), f);
});

test('compiles the next entry when idle, one at a time', () => {
    assert.equal(run().action, 'compile');
    assert.equal(run({ index: 3 }).action, 'compile');
    const wait = run({ pending: true });
    assert.equal(wait.action, 'wait', 'never two compiles at once');
    assert.equal(wait.delay, Q.GAP);
});

test('waits while a window is open or opening', () => {
    const r = run({ busy: true });
    assert.equal(r.action, 'wait');
    assert.equal(r.delay, Q.BUSY_RETRY);
});

test('stops when done or turned off', () => {
    assert.equal(run({ index: 4 }).action, 'stop');
    assert.equal(run({ enabled: false }).action, 'stop');
    assert.equal(run({ enabled: undefined }).action, 'stop');
    assert.equal(Q.next(undefined).action, 'stop');
    assert.equal(run({ count: 0 }).action, 'stop');
});

test('starts several seconds after startup, then spaces entries out', () => {
    assert.ok(Q.START_DELAY >= 5000, 'after the launcher pre-creation (~3 s)');
    assert.equal(Q.delayBefore(0), Q.START_DELAY);
    assert.equal(Q.delayBefore(1), Q.GAP);
    assert.equal(Q.delayBefore(3), Q.GAP);
    assert.ok(Q.GAP >= 500);
});

test('timings can be shortened (tests) and fall back to the defaults', () => {
    const t = { startDelay: 10, gap: 5, busyRetry: 7 };
    assert.equal(Q.delayBefore(0, t), 10);
    assert.equal(Q.delayBefore(2, t), 5);
    assert.equal(run({ busy: true }).delay, Q.BUSY_RETRY);
    assert.equal(Q.next({ enabled: true, index: 0, count: 1, busy: true }, t).delay, 7);
    assert.equal(Q.delayBefore(0, { startDelay: 0 }), Q.START_DELAY);
});

test('a component is settled once ready, failed or null, not while loading', () => {
    assert.equal(Q.settled(Q.READY), true);
    assert.equal(Q.settled(Q.ERROR), true);
    assert.equal(Q.settled(Q.NULL), true);
    assert.equal(Q.settled(Q.LOADING), false);
});

test('performance.warmViews gates every warm-up, on by default', () => {
    assert.equal(defaults.warmViews, true);
    assert.equal(W.enabled(defaults), true);
    assert.equal(W.enabled({ ...defaults, warmViews: false }), false);
    assert.equal(W.enabled({}), true);
    assert.equal(W.enabled(undefined), true);
    assert.equal(W.enabled({ warmViews: null }), true);
});
