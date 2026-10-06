const { test } = require('node:test');
const assert = require('node:assert/strict');
const path = require('node:path');
const { loadLibrary } = require('./lib/qmljs.cjs');
const N = loadLibrary(path.join(__dirname, '../modules/notch/NotchShape.js'));
const same = (a, b, m) => assert.deepEqual(JSON.parse(JSON.stringify(a)), b, m);
const EDGES = ['top', 'bottom', 'left', 'right'];

test('edge corners take the edge radius and the center-facing ones the outer radius, on every edge', () => {
    const want = {
        top: { tl: 0, tr: 0, bl: 9, br: 9 }, bottom: { tl: 9, tr: 9, bl: 0, br: 0 },
        left: { tl: 0, bl: 0, tr: 9, br: 9 }, right: { tr: 0, br: 0, tl: 9, bl: 9 }
    };
    for (const pos of EDGES) same(N.radii(pos, 0, 9), want[pos], pos);
    same(N.radii('nope', 0, 9), want.top);
});
test('the concave screen corners sit along the edge', () => {
    for (const pos of EDGES) {
        const v = pos === 'left' || pos === 'right';
        same(N.size(pos, { w: 100, h: 40 }, 8), v ? { w: 100, h: 56 } : { w: 116, h: 40 }, pos);
        assert.equal(N.vertical(pos), v);
    }
});
test('a side silhouette is the top one turned toward the screen center', () => {
    same(N.frame('left', 80, 300), { w: 300, h: 80, rotation: -90, edge: 'top' });
    same(N.frame('right', 80, 300), { w: 300, h: 80, rotation: 90, edge: 'top' });
    same(N.frame('bottom', 300, 80), { w: 300, h: 80, rotation: 0, edge: 'bottom' });
    same(N.frame('top', 300, 80), { w: 300, h: 80, rotation: 0, edge: 'top' });
});
test('the hidden offset slides the notch back behind its own edge', () => {
    same(N.hideOffset('top', 50), { x: 0, y: -66 });
    same(N.hideOffset('bottom', 50), { x: 0, y: 66 });
    same(N.hideOffset('left', 50), { x: -66, y: 0 });
    same(N.hideOffset('right', 20), { x: 66, y: 0 });
});
test('expanded views hug the screen edge and center on the other axis', () => {
    const box = { w: 400, h: 300 }, view = { w: 200, h: 100 };
    same(N.viewPos('top', box, view, 16), { x: 100, y: 16 });
    same(N.viewPos('bottom', box, view, 16), { x: 100, y: 184 });
    same(N.viewPos('left', box, view, 16), { x: 16, y: 100 });
    same(N.viewPos('right', box, view, 16), { x: 184, y: 100 });
});
test('the hover strip lies on the notch edge', () => {
    const screen = { w: 1920, h: 1080 };
    same(N.hoverStrip('left', { x: 10, y: 400, w: 40, h: 200 }, screen, 8, 10), { x: 0, y: 390, w: 18, h: 220 });
    same(N.hoverStrip('right', { x: 1870, y: 400, w: 40, h: 200 }, screen, 8, 10), { x: 1902, y: 390, w: 18, h: 220 });
    same(N.hoverStrip('top', { x: 800, y: 0, w: 300, h: 40 }, screen, 8, 10), { x: 790, y: 0, w: 320, h: 8 });
    same(N.hoverStrip('bottom', { x: 800, y: 1040, w: 300, h: 40 }, screen, 8, 10), { x: 790, y: 1072, w: 320, h: 8 });
});
