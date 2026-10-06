const { test } = require('node:test');
const assert = require('node:assert/strict');
const path = require('node:path');
const { loadLibrary } = require('./lib/qmljs.cjs');
const R = loadLibrary(path.join(__dirname, '../modules/notch/NotchReveal.js'));

const base = { enabled: true, keepHidden: false, sameEdge: true, hasWindows: false, fullscreen: false,
    barPinned: true, availableOnFullscreen: false, open: false, interacting: false };
const s = (o) => Object.assign({}, base, o);

test('a pinned bar on the same edge keeps the notch shown', () => {
    assert.equal(R.reveal(s()), true);
    assert.equal(R.reveal(s({ barPinned: false })), false);
    assert.equal(R.reveal(s({ barPinned: false, interacting: true })), true);
});

test('on another edge it hides with windows or keepHidden, and shows on interaction', () => {
    assert.equal(R.reveal(s({ sameEdge: false })), true);
    assert.equal(R.reveal(s({ sameEdge: false, hasWindows: true })), false);
    assert.equal(R.reveal(s({ sameEdge: false, keepHidden: true })), false);
    assert.equal(R.reveal(s({ sameEdge: false, keepHidden: true, interacting: true })), true);
    assert.equal(R.reveal(s({ keepHidden: true })), true, 'keepHidden is ignored on the bar edge');
});

test('fullscreen hard-hides unless the bar is available on fullscreen', () => {
    assert.equal(R.reveal(s({ fullscreen: true, open: true, interacting: true })), false);
    assert.equal(R.reveal(s({ fullscreen: true, availableOnFullscreen: true, interacting: true })), true);
});

test('a disabled notch only shows while a view is open in it', () => {
    assert.equal(R.reveal(s({ enabled: false })), false);
    assert.equal(R.reveal(s({ enabled: false, interacting: true })), false);
    assert.equal(R.reveal(s({ enabled: false, open: true, interacting: true })), true);
});
