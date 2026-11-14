// Picture grids (controls/PictureGrid.js): compact cards, balanced rows (no
// orphan), every row filled to the card's edge, the short last row centred.
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

test('a few options stay on one line a little under the size', () => {
    // three shapes in a 290 px card: 3 of about 89 px, not 2 + 1
    assert.equal(G.columns(290, 12, 3, 96), 3);
    // five styles in a 500 px column: one line of five, not 4 + 1
    assert.equal(G.columns(500, 12, 5, 110), 5);
    // too far under: wrapped
    assert.equal(G.columns(220, 12, 3, 96), 2);
});

test('wrapped rows are balanced: no orphan', () => {
    // six that do not fit one line: 3 + 3, not 4 + 2
    assert.equal(G.columns(480, 12, 6, 110), 3);
    // seven: 4 + 3; eight: 4 + 4
    assert.equal(G.columns(500, 12, 7, 110), 4);
    assert.equal(G.columns(500, 12, 8, 110), 4);
    // nine in four columns' room: 3 + 3 + 3
    assert.equal(G.columns(500, 12, 9, 110), 3);
});

test('cards fill the row; only a very short row stops growing', () => {
    assert.equal(G.cardWidth(500, 12, 4, 190), Math.floor((500 - 36) / 4));
    // three in a wide card reach the edge
    assert.equal(G.cardWidth(790, 12, 3, 190), Math.floor((790 - 24) / 3));
    // two in a wide card stop at 1.5x the cap
    assert.equal(G.cardWidth(900, 8, 2, 150), 225);
});

test('the short last row is centred', () => {
    const p = JSON.parse(JSON.stringify(G.places(7, 4, 100, 60, 10)));
    assert.deepEqual(p[0], { x: 0, y: 0 });
    assert.deepEqual(p[3], { x: 330, y: 0 });
    // row of three in a row of four: shifted by half a card and gap
    assert.deepEqual(p[4], { x: 55, y: 70 });
    assert.deepEqual(p[6], { x: 275, y: 70 });
});
