const { test } = require('node:test');
const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');
const qmljs = require('./lib/qmljs.cjs');

const B = qmljs.loadLibrary(path.join(__dirname, '../modules/services/Backoff.js'));

test('doubles from the base up to the cap', () => {
    const d = [1, 2, 3, 4, 5, 6, 7, 8].map(n => B.delay(n, 5000, 600000, 0));
    assert.deepEqual(d, [5000, 10000, 20000, 40000, 80000, 160000, 320000, 600000]);
    assert.equal(B.delay(50, 5000, 600000, 0), 600000);
    assert.equal(B.delay(1e9, 5000, 600000, 0), 600000);
});

test('bad input stays sane', () => {
    assert.equal(B.delay(0, 5000, 600000, 0), 5000);
    assert.equal(B.delay(-3, 5000, 600000, 0), 5000);
    assert.equal(B.delay(undefined, 5000, 600000, 0), 5000);
    assert.equal(B.delay(3, 5000, 1000, 0), 5000, 'cap below base: base wins');
});

test('jitter stays within +-jitter and inside [base, cap]', () => {
    assert.equal(B.delay(3, 5000, 600000, 0.2, () => 0.5), 20000);
    assert.equal(B.delay(3, 5000, 600000, 0.2, () => 0), 16000);
    assert.equal(B.delay(3, 5000, 600000, 0.2, () => 1), 24000);
    assert.equal(B.delay(1, 5000, 600000, 0.5, () => 0), 5000, 'never below base');
    assert.equal(B.delay(20, 5000, 600000, 0.5, () => 1), 600000, 'never above cap');
    for (let i = 0; i < 200; i++) {
        const v = B.delay(4, 5000, 600000, 0.25);
        assert.ok(v >= 30000 && v <= 50000, String(v));
    }
});

test('WeatherService retries through the backoff and resets on network changes', () => {
    const qml = fs.readFileSync(path.join(__dirname, '../modules/services/WeatherService.qml'), 'utf8');
    assert.match(qml, /import "Backoff\.js" as Backoff/);
    assert.match(qml, /Backoff\.delay\(/);
    assert.match(qml, /target: NetworkService/);
    assert.doesNotMatch(qml, /interval: 3000\n\s*repeat: false\n\s*onTriggered: root\.updateWeather\(\)/, 'fixed 3 s retry is back');
});
