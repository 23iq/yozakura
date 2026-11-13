// The Widgets & clock stage's pure helpers (modules/settings/stages/DesktopPlace.js):
// the clock's side and where "Move here" sits.
const { test } = require('node:test');
const assert = require('node:assert/strict');
const path = require('node:path');
const { loadLibrary } = require('./lib/qmljs.cjs');

const D = loadLibrary(path.join(__dirname, '../modules/settings/stages/DesktopPlace.js'));

test('the clock side: where it is drawn, else the setting', () => {
    assert.equal(D.clockSide('left', ''), 'left');
    assert.equal(D.clockSide('auto', ''), 'right');
    assert.equal(D.clockSide('right', ''), 'right');
    // "auto" placed it left on this wallpaper: the stage says left
    assert.equal(D.clockSide('auto', 'left'), 'left');
    assert.equal(D.clockSide('right', 'left'), 'left');
});

test('the target is the other side, only where the style can go', () => {
    assert.equal(D.moveTarget('left', ['left', 'right']), 'right');
    assert.equal(D.moveTarget('right', ['left', 'right']), 'left');
    assert.equal(D.moveTarget('right', ['right']), '');
    assert.equal(D.moveTarget('left', []), 'right');
});

test('the side of drawn bounds', () => {
    assert.equal(D.sideOf({ x: 100, w: 400 }, 2560), 'left');
    assert.equal(D.sideOf({ x: 1800, w: 500 }, 2560), 'right');
    assert.equal(D.sideOf(null, 2560), '');
    assert.equal(D.sideOf({ x: 0, w: 0 }, 2560), '');
});
