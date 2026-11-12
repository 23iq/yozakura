const { test } = require('node:test');
const assert = require('node:assert/strict');
const path = require('node:path');
const { loadLibrary } = require('./lib/qmljs.cjs');
const B = loadLibrary(path.join(__dirname, '../modules/shell/osd/OsdWindowBox.js'));
const E = loadLibrary(path.join(__dirname, '../modules/shell/EdgeLayout.js'));

const SCREEN = { w: 1920, h: 1080 };
const env = (bar) => ({ screen: SCREEN, frame: 0,
    bar: { pos: bar, size: 40, visible: true }, dock: { pos: 'bottom', size: 0, visible: false },
    notch: { pos: 'top', height: 36, visible: true } });

// Where a compositor puts a layer surface with these anchors and margins
// (exclusive zone -1: relative to the whole output)
function landed(b, s) {
    return {
        x: b.anchors.left ? b.margins.left : s.w - b.margins.right - b.w,
        y: b.anchors.top ? b.margins.top : s.h - b.margins.bottom - b.h,
    };
}

for (const edge of ['top', 'bottom', 'left', 'right']) {
    test(`${edge}: anchored to its edge and the start edge across it, lands exactly`, () => {
        const size = { w: 220, h: 52 };
        const place = E.osdPlacement(env('top'), edge, size);
        const b = B.box(place, size, 14, SCREEN);
        const vertical = edge === 'left' || edge === 'right';
        assert.equal(b.anchors[edge], true);
        assert.equal(vertical ? b.anchors.top : b.anchors.left, true);
        assert.equal(Object.values(b.anchors).filter(Boolean).length, 2, 'two anchors, never stretched');
        const at = landed(b, SCREEN);
        assert.deepEqual(at, { x: b.x, y: b.y });
        // The OSD sits inside at its screen position
        assert.equal(b.x + b.offsetX, place.x);
        assert.equal(b.y + b.offsetY, place.y);
    });

    test(`${edge}: room for the OSD, its slide towards the edge and the pad`, () => {
        const size = { w: 220, h: 52 };
        const place = E.osdPlacement(env('left'), edge, size);
        const b = B.box(place, size, 14, SCREEN, 4);
        assert.ok(b.offsetX >= 4 && b.offsetY >= 4);
        assert.ok(b.w - b.offsetX - size.w >= 4 && b.h - b.offsetY - size.h >= 4);
        // The hidden pose (slid 14 px towards the edge) is inside too
        const slide = { top: [0, -14], bottom: [0, 14], left: [-14, 0], right: [14, 0] }[edge];
        const hx = b.offsetX + slide[0];
        const hy = b.offsetY + slide[1];
        assert.ok(hx >= 0 && hy >= 0 && hx + size.w <= b.w && hy + size.h <= b.h, JSON.stringify(b));
        // Small: a fraction of the screen
        assert.ok(b.w * b.h < SCREEN.w * SCREEN.h / 20);
    });
}

test('clamped to the screen, never empty', () => {
    const b = B.box({ edge: 'top', x: 2, y: 3 }, { w: 100, h: 40 }, 14, { w: 300, h: 200 }, 4);
    assert.equal(b.x, 0);
    assert.equal(b.y, 0);
    assert.equal(b.offsetX, 2);
    assert.equal(b.offsetY, 3);
    const tiny = B.box({ edge: 'bottom', x: 500, y: 500 }, { w: 10, h: 10 }, 14, { w: 100, h: 100 });
    assert.ok(tiny.w >= 1 && tiny.h >= 1 && tiny.x + tiny.w <= 100 && tiny.y + tiny.h <= 100);
});

test('fractional placements round outwards to whole pixels', () => {
    const b = B.box({ edge: 'bottom', x: 100.5, y: 300.25 }, { w: 50.5, h: 20 }, 14, SCREEN, 0);
    assert.equal(b.x, 100);
    assert.equal(b.y, 300);
    assert.equal(b.w, 51);
    assert.equal(b.h, 35);
    assert.ok(Number.isInteger(b.margins.bottom) && Number.isInteger(b.margins.left));
});
