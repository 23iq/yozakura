const { test } = require('node:test');
const assert = require('node:assert/strict');
const path = require('node:path');
const { loadLibrary } = require('./lib/qmljs.cjs');
const D = loadLibrary(path.join(__dirname, '../modules/theme/DensityMetrics.js'));

test('cozy equals the historic literal sizes', () => {
    const m = D.metrics('cozy');
    assert.equal(m.rowHeight, 48); assert.equal(m.launcherWideW, 900);
    assert.equal(m.dashH, 430); assert.equal(m.osdW, 220); assert.equal(m.menuW, 160);
});
test('unknown density falls back to cozy', () => {
    assert.deepEqual(JSON.parse(JSON.stringify(D.metrics('huge'))), JSON.parse(JSON.stringify(D.metrics('cozy'))));
});
test('compact < cozy < roomy for every key', () => {
    const c = D.metrics('compact'), z = D.metrics('cozy'), r = D.metrics('roomy');
    for (const k of Object.keys(z)) assert.ok(c[k] < z[k] && z[k] < r[k], k);
});
