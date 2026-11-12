const { test } = require('node:test');
const assert = require('node:assert/strict');
const path = require('node:path');

const qmljs = require('./lib/qmljs.cjs');
const S = qmljs.loadLibrary(path.join(__dirname, '../modules/services/IdleSchedule.js'));

test('listener seconds match the old 1 s tick', () => {
    assert.equal(S.listenerSeconds({ timeout: 150 }), 150);
    assert.equal(S.listenerSeconds({ timeout: '30' }), 30);
    assert.equal(S.listenerSeconds({ timeout: 2.5 }), 3, 'fractional: the next whole second');
    assert.equal(S.listenerSeconds({}), 60, 'missing: 60 s');
    assert.equal(S.listenerSeconds({ timeout: 0 }), 60, 'zero: 60 s (timeout || 60)');
    assert.equal(S.listenerSeconds({ timeout: -5 }), 1, 'negative: the first tick');
    assert.equal(S.listenerSeconds({ timeout: 'soon' }), Infinity, 'not a number: never');
});

test('thresholds are sorted, unique, whole seconds with the extra delays', () => {
    const listeners = [{ timeout: 300 }, { timeout: 150 }, { timeout: 300 }, { timeout: 'x' }];
    assert.deepEqual(Array.from(S.thresholds(listeners, [60])), [60, 150, 300]);
    assert.deepEqual(Array.from(S.thresholds(listeners, [0, -1, 59.2])), [60, 150, 300]);
    assert.deepEqual(Array.from(S.thresholds([], [60])), [60]);
    assert.deepEqual(Array.from(S.thresholds(null, [])), []);
});

test('next delay sleeps until the next threshold, capped', () => {
    const t = [60, 150, 300];
    assert.equal(S.nextDelay(t, 0), 60000);
    assert.equal(S.nextDelay(t, 60000), 90000, 'a reached threshold is not scheduled again');
    assert.equal(S.nextDelay(t, 61500), 88500);
    assert.equal(S.nextDelay(t, 300000), -1, 'nothing left: no wake-up');
    assert.equal(S.nextDelay([], 0), -1);
    assert.equal(S.nextDelay([200000], 0), S.MAX_STEP_MS);
});

test('due lists listeners that reached their timeout and have not fired', () => {
    const listeners = [{ timeout: 150 }, { timeout: 300 }, { timeout: 30 }];
    assert.deepEqual(Array.from(S.due(listeners, 29, [])), []);
    assert.deepEqual(Array.from(S.due(listeners, 150, [])), [0, 2]);
    assert.deepEqual(Array.from(S.due(listeners, 300, [0, 2])), [1]);
    assert.deepEqual(Array.from(S.due(listeners, 9999, [0, 1, 2])), []);
});

test('a mid-wait change credits the time spent, never a suspend', () => {
    assert.equal(S.waitCredit(400, 1000), 400);
    assert.equal(S.waitCredit(1000, 1000), 1000);
    assert.equal(S.waitCredit(1000 + S.SUSPEND_SLACK_MS, 1000), 1000, 'timer latency: capped at the armed wait');
    assert.equal(S.waitCredit(3600000, 30000), 0, 'a gap only a missed suspend explains: no credit');
    assert.equal(S.waitCredit(-5, 1000), 0);
    assert.equal(S.waitCredit(5000, -1), 5000, 'no armed wait: the time since the last threshold');
});
