// config/WriteThrottle.js: a burst of edits becomes one write when it stops,
// and a long burst (a slider drag) still writes every maxWait ms.
const { test } = require('node:test');
const assert = require('node:assert/strict');
const path = require('node:path');
const { loadLibrary } = require('./lib/qmljs.cjs');

const T = loadLibrary(path.join(__dirname, '../config/WriteThrottle.js'));

test('no delay: every edit is written at once', () => {
    assert.equal(T.decide(1000, -1, 0, 250), 'now');
});

test('a fresh edit waits for the burst to end', () => {
    assert.equal(T.decide(1000, -1, 150, 250), 'later');
    assert.equal(T.decide(1100, 1000, 150, 250), 'later');
});

test('a long burst writes once maxWait passed since its oldest edit', () => {
    assert.equal(T.decide(1249, 1000, 150, 250), 'later');
    assert.equal(T.decide(1250, 1000, 150, 250), 'now');
});

test('a drag of two seconds at 60 Hz writes a few times per second', () => {
    let since = -1;
    let writes = 0;
    for (let t = 0; t <= 2000; t += 16) {
        if (since < 0)
            since = t;
        if (T.decide(t, since, 150, 250) === 'now') {
            writes++;
            since = -1;
        }
    }
    assert.ok(writes >= 6 && writes <= 9, `writes: ${writes}`);
});

test('maxWait 0: no cap, only the trailing write', () => {
    assert.equal(T.decide(99999, 0, 150, 0), 'later');
});
