const { test } = require('node:test');
const assert = require('node:assert/strict');
const path = require('node:path');
const { loadLibrary } = require('./lib/qmljs.cjs');

const A = loadLibrary(path.join(__dirname, '../modules/services/ai/Automations.js'));

test('the schedule check lands just after the next minute boundary', () => {
    assert.equal(A.msToNextMinute(0), 60250);
    assert.equal(A.msToNextMinute(59000), 1250);
    assert.equal(A.msToNextMinute(new Date(120000 + 30000)), 30250);
});

test('always within (250, 60250] ms', () => {
    for (let t = 0; t < 180000; t += 997) {
        const ms = A.msToNextMinute(t);
        assert.ok(ms > 250 && ms <= 60250, String(t));
        assert.equal((t + ms - 250) % 60000, 0);
    }
});
