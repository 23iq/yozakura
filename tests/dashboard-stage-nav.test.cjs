'use strict';
// modules/widgets/dashboard/stage/StageNav.js: arrow-key focus moves.
const test = require('node:test');
const assert = require('node:assert/strict');
const path = require('node:path');
const qmljs = require('./lib/qmljs.cjs');

const N = qmljs.loadLibrary(path.join(__dirname, '../modules/widgets/dashboard/stage/StageNav.js'));

// play | 3 tiles | a wide slider; a right column of two rows.
const r = (x, y, w, h) => ({ x, y, w, h });
const rects = [
    r(100, 0, 60, 60), // 0 play
    r(0, 100, 50, 50), r(60, 100, 50, 50), r(120, 100, 50, 50), // 1..3 tiles
    r(0, 170, 170, 30), // 4 slider
    r(220, 0, 200, 40), r(220, 50, 200, 40), // 5, 6 right rows
];

test('left / right stay in the row', () => {
    assert.equal(N.pick(rects, 1, 'right'), 2);
    assert.equal(N.pick(rects, 2, 'left'), 1);
    assert.equal(N.pick(rects, 1, 'left'), -1);
});

test('up / down pick the nearest across', () => {
    assert.equal(N.pick(rects, 3, 'up'), 0);
    assert.equal(N.pick(rects, 2, 'down'), 4);
    assert.equal(N.pick(rects, 4, 'up'), 2);
    assert.equal(N.pick(rects, 5, 'down'), 6);
});

test('right from the left column reaches the right column', () => {
    assert.equal(N.pick(rects, 0, 'right'), 5);
    assert.equal(N.pick(rects, 6, 'left'), 0);
});

test('direction maps the arrow keys', () => {
    assert.equal(N.direction(0x01000012), 'left');
    assert.equal(N.direction(0x01000015), 'down');
    assert.equal(N.direction(65), '');
});
