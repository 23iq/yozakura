// The Widgets page's pure helpers (modules/settings/stages/DesktopPlace.js):
// a widget chip turns its type on (one widget in a free spot) or off.
const { test } = require('node:test');
const assert = require('node:assert/strict');
const path = require('node:path');
const { loadLibrary } = require('./lib/qmljs.cjs');

const D = loadLibrary(path.join(__dirname, '../modules/settings/stages/DesktopPlace.js'));
const SCREEN = { name: 'DP-1', w: 2560, h: 1440 };

test('turning a type on adds one widget of it, inside the screen', () => {
    const out = D.toggled([], 'media', SCREEN, 24, []);
    assert.equal(out.length, 1);
    const w = out[0];
    assert.equal(w.type, 'media');
    assert.equal(w.monitor, 'DP-1');
    assert.ok(w.x >= 0 && w.y >= 0 && w.x + w.w <= 1 && w.y + w.h <= 1);
    assert.equal(D.countOf(out, 'media'), 1);
});

test('a second type lands clear of the first', () => {
    const one = D.toggled([], 'calendar', SCREEN, 24, []);
    const two = D.toggled(one, 'system', SCREEN, 24, []);
    assert.equal(two.length, 2);
    const [a, b] = two;
    const apart = a.x + a.w <= b.x || b.x + b.w <= a.x || a.y + a.h <= b.y || b.y + b.h <= a.y;
    assert.ok(apart, 'the widgets do not overlap');
});

test('turning a type off removes every widget of it, keeps the others', () => {
    const list = D.toggled(D.toggled([], 'note', SCREEN, 0, []), 'weather', SCREEN, 0, []);
    const more = list.concat([{ id: 'note-2', type: 'note', x: 0.1, y: 0.1, w: 0.1, h: 0.1 }]);
    const out = D.toggled(more, 'note', SCREEN, 0, []);
    assert.equal(D.countOf(out, 'note'), 0);
    assert.equal(D.countOf(out, 'weather'), 1);
});

test('an unknown type changes nothing; the clock side', () => {
    assert.equal(D.toggled([], 'nope', SCREEN, 24, []).length, 0);
    assert.equal(D.clockSide('left'), 'left');
    assert.equal(D.clockSide('auto'), 'right');
    assert.equal(D.clockSide('right'), 'right');
});
