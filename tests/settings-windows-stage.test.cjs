// The Windows stage geometry (modules/settings/stages/WindowTiles.js): the
// windows each layout makes, Hyprland's gaps, and the drag handles' maps.
const { test } = require('node:test');
const assert = require('node:assert/strict');
const path = require('node:path');
const { loadLibrary } = require('./lib/qmljs.cjs');

const T = loadLibrary(path.join(__dirname, '..', 'modules/settings/stages/WindowTiles.js'));

const right = r => r.x + r.w;
const bottom = r => r.y + r.h;
const near = (a, b, what) => assert.ok(Math.abs(a - b) < 1e-6, `${what}: ${a} != ${b}`);

test('every layout makes four windows inside the area, the outer gap on each side', () => {
    for (const layout of T.LAYOUTS) {
        const tiles = T.tiles(layout, 800, 450, 5, 10);
        assert.equal(tiles.length, 4, layout);
        for (const r of tiles) {
            assert.ok(r.x >= 10 - 1e-6 && r.y >= 10 - 1e-6, `${layout}: inside the edge gap`);
            assert.ok(bottom(r) <= 440 + 1e-6, `${layout}: above the bottom gap`);
            assert.ok(r.w > 0 && r.h > 0, `${layout}: a real window`);
        }
        // the focused window touches the left gap and spans the height
        near(tiles[0].x, 10, `${layout} left`);
        near(tiles[0].y, 10, `${layout} top`);
        near(bottom(tiles[0]), 440, `${layout} bottom`);
    }
});

test('neighbours are 2 x gapsIn apart (Hyprland: each side keeps gaps_in)', () => {
    const d = T.tiles('dwindle', 800, 450, 6, 4);
    near(d[1].x - right(d[0]), 12, 'dwindle: first split');
    near(d[2].y - bottom(d[1]), 12, 'dwindle: second split');
    near(d[3].x - right(d[2]), 12, 'dwindle: third split');
    near(right(d[1]), 796, 'dwindle: the right gap');
    const m = T.tiles('master', 800, 450, 6, 4);
    near(m[1].x - right(m[0]), 12, 'master: master to stack');
    near(m[2].y - bottom(m[1]), 12, 'master: inside the stack');
    assert.ok(m[0].w > m[1].w, 'master: the master is the widest');
});

test('scrolling runs its last column off the right edge', () => {
    const s = T.tiles('scrolling', 800, 450, 5, 10);
    assert.ok(right(s[3]) > 800, 'the third column is cut by the screen');
    near(s[1].x, s[2].x, 'the second column holds two windows');
});

test('an unknown layout draws as dwindle; zero gaps touch', () => {
    assert.deepEqual(JSON.parse(JSON.stringify(T.tiles('monocle', 400, 300, 0, 0))), JSON.parse(JSON.stringify(T.tiles('dwindle', 400, 300, 0, 0))));
    const z = T.tiles('dwindle', 400, 300, 0, 0);
    near(z[1].x, right(z[0]), 'no gap');
    near(z[0].x, 0, 'no edge gap');
});

test('drag handles: gap moves half the pointer, edges follow it, corners round inwards, all clamped', () => {
    assert.equal(T.gapFromDrag(4, 10), 9);
    assert.equal(T.gapFromDrag(4, -100), 0);
    assert.equal(T.gapFromDrag(40, 100), 50);
    assert.equal(T.edgeFromDrag(4, 12), 16);
    assert.equal(T.edgeFromDrag(90, 40), 100);
    assert.equal(T.roundingFromDrag(10, 10, 10), 20);
    assert.equal(T.roundingFromDrag(10, -30, -30), 0);
    assert.equal(T.roundingFromDrag(30, 40, 40), 40);
});

test('the drawn rounding is the shell one while it follows the shell', () => {
    assert.equal(T.rounding(true, 4, 16), 16);
    assert.equal(T.rounding(false, 4, 16), 4);
    assert.equal(T.rounding(false, 'x', 16), 0);
});
