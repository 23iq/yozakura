const { test } = require('node:test');
const assert = require('node:assert/strict');
const path = require('node:path');
const { loadLibrary } = require('./lib/qmljs.cjs');
const R = loadLibrary(path.join(__dirname, '../modules/dock/DockReveal.js'));

const base = { preview: false, fullscreen: false, availableOnFullscreen: false, hoverToReveal: true,
    keepHidden: false, pinned: true, hovered: false, hasWindows: true };
const s = (o) => Object.assign({}, base, o);

test('outside fullscreen: the pin, hover or an empty workspace show the dock', () => {
    assert.equal(R.reveal(s()), true);
    assert.equal(R.reveal(s({ pinned: false })), false);
    assert.equal(R.reveal(s({ pinned: false, hovered: true })), true);
    assert.equal(R.reveal(s({ pinned: false, hasWindows: false })), true);
    assert.equal(R.reveal(s({ keepHidden: true })), false, 'keepHidden overrides the pin');
    assert.equal(R.reveal(s({ keepHidden: true, hovered: true })), true);
    assert.equal(R.reveal(s({ keepHidden: true, hovered: true, hoverToReveal: false })), false);
    assert.equal(R.takesInput(s({ pinned: false })), true, 'a hidden dock keeps its edge strip');
});

test('over a fullscreen window it shows only by hover, with both options on', () => {
    assert.equal(R.reveal(s({ fullscreen: true })), false);
    assert.equal(R.reveal(s({ fullscreen: true, hovered: true })), false);
    assert.equal(R.reveal(s({ fullscreen: true, availableOnFullscreen: true, hovered: true })), true);
    assert.equal(R.reveal(s({ fullscreen: true, availableOnFullscreen: true, hoverToReveal: false, hovered: true })), false);
});

test('a dock that cannot show over fullscreen takes no input there', () => {
    assert.equal(R.takesInput(s({ fullscreen: true })), false);
    assert.equal(R.takesInput(s({ fullscreen: true, availableOnFullscreen: true })), true);
    assert.equal(R.takesInput(s({ fullscreen: true, availableOnFullscreen: true, hoverToReveal: false })), false);
    assert.equal(R.takesInput(s({ fullscreen: true, preview: true })), true, 'a preview always shows');
});
