// The window corner and border strips (modules/settings/editors/StepPick.js):
// a value between the steps chooses no tile, and the keyboard steps from the
// value to the next step that way (never jumps to 0).
const { test } = require('node:test');
const assert = require('node:assert/strict');
const path = require('node:path');
const { loadLibrary } = require('./lib/qmljs.cjs');

const P = loadLibrary(path.join(__dirname, '..', 'modules/settings/editors/StepPick.js'));
const WIDTHS = [0, 1, 2, 3, 5];
const CORNERS = [0, 8, 16, 24, 32];

test('only a value equal to a step chooses a tile', () => {
    assert.equal(P.exactIndex(WIDTHS, 2), 2);
    assert.equal(P.exactIndex(WIDTHS, 4), -1);
    assert.equal(P.exactIndex(WIDTHS, 10), -1);
    assert.equal(P.exactIndex(CORNERS, 12), -1);
    assert.equal(P.exactIndex(CORNERS, '16'), 2, 'a stored string still matches');
});

test('the keyboard steps from the value, not from the start of the strip', () => {
    // a border of 4 (from the CLI): Right goes to 5, Left to 3, never to 0
    assert.equal(P.stepFrom(WIDTHS, 4, 1), 5);
    assert.equal(P.stepFrom(WIDTHS, 4, -1), 3);
    // a border of 10: Left comes down to the widest step, Right stays there
    assert.equal(P.stepFrom(WIDTHS, 10, -1), 5);
    assert.equal(P.stepFrom(WIDTHS, 10, 1), 5);
    // on a step: the next one
    assert.equal(P.stepFrom(WIDTHS, 2, 1), 3);
    assert.equal(P.stepFrom(WIDTHS, 0, -1), 0);
    assert.equal(P.stepFrom(CORNERS, 12, 1), 16);
    assert.equal(P.stepFrom(CORNERS, 12, -1), 8);
    assert.equal(P.stepFrom(CORNERS, undefined, 1), 32);
});
