const { test } = require('node:test');
const assert = require('node:assert/strict');
const path = require('node:path');
const { loadLibrary } = require('./lib/qmljs.cjs');

const T = loadLibrary(path.join(__dirname, '../modules/widgets/dashboard/DashboardTabs.js'));

test('fitScreen clamps to the screen room and ignores an unknown screen', () => {
    assert.equal(T.fitScreen(850, 1920, 24), 850);
    assert.equal(T.fitScreen(850, 800, 24), 752);
    assert.equal(T.fitScreen(850, 0, 24), 850);
    assert.equal(T.fitScreen(850, 10, 24), 1);
});
