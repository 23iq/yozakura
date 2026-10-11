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

test('the last visible tab cannot be hidden', () => {
    const one = T.setVisible(T.resolve([]), 'wallpapers', false);
    const two = T.setVisible(one, 'metrics', false);
    assert.deepEqual(JSON.parse(JSON.stringify(T.visibleIndices(two))), [0]);
    const refused = T.setVisible(two, 'widgets', false);
    assert.equal(refused.filter(t => t.visible).length, 1);
    assert.equal(T.setVisible(refused, 'metrics', true).filter(t => t.visible).length, 2);
});

test('homeOf keeps a known home view, defaults to the stage', () => {
    assert.equal(T.homeOf('composed'), 'composed');
    assert.equal(T.homeOf('bento'), 'bento');
    assert.equal(T.homeOf('stage'), 'stage');
    assert.equal(T.homeOf(undefined), 'stage');
    assert.equal(T.homeOf('grid'), 'stage');
});
