// Picture cards are compact (controls/PictureGrid.js): about 124-150 px,
// five or six a row in a wide card, at least two, never more than options.
const { test } = require('node:test');
const assert = require('node:assert/strict');
const path = require('node:path');
const { loadLibrary } = require('./lib/qmljs.cjs');

const G = loadLibrary(path.join(__dirname, '..', 'modules/settings/controls/PictureGrid.js'));

test('a wide card holds five or six pictures', () => {
    assert.equal(G.columns(707, 8, 0, 124), 5);
    assert.equal(G.columns(1100, 8, 0, 124), 8);
    assert.equal(G.columns(1100, 8, 6, 124), 6);
});

test('never fewer than two, never more than the options', () => {
    assert.equal(G.columns(200, 8, 6, 124), 2);
    assert.equal(G.columns(900, 8, 3, 124), 3);
});

test('a picture is never wider than the cap', () => {
    assert.equal(G.cardWidth(900, 8, 3, 150), 150);
    assert.equal(Math.round(G.cardWidth(300, 8, 2, 150)), 146);
});
