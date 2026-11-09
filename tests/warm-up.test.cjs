const { test } = require('node:test');
const assert = require('node:assert/strict');
const path = require('node:path');
const qmljs = require('./lib/qmljs.cjs');

const W = qmljs.loadLibrary(path.join(__dirname, '../modules/shell/hosts/WarmUp.js'));

test('targetScreen prefers the focused screen, else the first one', () => {
    assert.equal(W.targetScreen(['A', 'B'], 'B'), 'B');
    assert.equal(W.targetScreen(['A', 'B'], ''), 'A');
    assert.equal(W.targetScreen(['A', 'B'], 'gone'), 'A');
    assert.equal(W.targetScreen([], 'A'), '');
    assert.equal(W.targetScreen(null, 'A'), '');
});

test('only one owner warms: the notch for a notch launcher, the hosts otherwise', () => {
    const screens = ['A', 'B'];
    assert.equal(W.shouldWarm('notch', 'notch', 'A', screens, 'A'), true);
    assert.equal(W.shouldWarm('hosts', 'notch', 'A', screens, 'A'), false);
    assert.equal(W.shouldWarm('hosts', 'spotlight', 'A', screens, 'A'), true);
    assert.equal(W.shouldWarm('hosts', 'sheet', 'A', screens, 'A'), true);
    assert.equal(W.shouldWarm('notch', 'spotlight', 'A', screens, 'A'), false);
});

test('only the target screen warms', () => {
    const screens = ['A', 'B'];
    assert.equal(W.shouldWarm('hosts', 'spotlight', 'B', screens, 'A'), false);
    assert.equal(W.shouldWarm('hosts', 'spotlight', 'B', screens, 'B'), true);
    assert.equal(W.shouldWarm('hosts', 'spotlight', '', screens, ''), false);
    assert.equal(W.shouldWarm('hosts', '', 'A', screens, ''), false);
});
