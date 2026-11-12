const { test } = require('node:test');
const assert = require('node:assert/strict');
const path = require('node:path');
const qmljs = require('./lib/qmljs.cjs');

const R = qmljs.loadLibrary(path.join(__dirname, '../modules/globals/BatterySaverRule.js'));
const defaults = qmljs.loadLibrary(path.join(__dirname, '../config/defaults/performance.js')).data;

test('the saver is opt-in: off by default changes nothing', () => {
    assert.equal(defaults.batterySaver, false);
    assert.equal(R.active(defaults.batterySaver, true, true), false);
});

test('active only when turned on and running from a battery', () => {
    assert.equal(R.active(true, true, true), true);
    assert.equal(R.active(true, true, false), false, 'on AC');
    assert.equal(R.active(true, false, false), false, 'desktop without a battery');
    assert.equal(R.active(true, false, true), false, 'no battery device, whatever UPower says');
    assert.equal(R.active(false, true, true), false);
});

test('missing values never turn it on', () => {
    for (const v of [undefined, null, 1, 'true'])
        assert.equal(R.active(v, true, true), false, String(v));
    assert.equal(R.active(true, undefined, true), false);
    assert.equal(R.active(true, true, undefined), false);
});
