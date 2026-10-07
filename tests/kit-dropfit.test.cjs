const { test } = require('node:test');
const assert = require('node:assert/strict');
const path = require('node:path');
const { loadLibrary } = require('./lib/qmljs.cjs');

const F = loadLibrary(path.join(__dirname, '../modules/components/kit/DropFit.js'));

test('opens below when the list fits under the anchor', () => {
    assert.equal(F.dropY(100, 32, 200, 4, 800), 36);
});

test('opens above near the bottom of the window', () => {
    assert.equal(F.dropY(700, 32, 200, 4, 800), -204);
});

test('stays below when it fits neither way, and with an unknown window', () => {
    assert.equal(F.dropY(150, 32, 400, 4, 500), 36);
    assert.equal(F.dropY(700, 32, 200, 4, 0), 36);
});
