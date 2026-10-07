const { test } = require('node:test');
const assert = require('node:assert/strict');
const path = require('node:path');
const { loadLibrary } = require('./lib/qmljs.cjs');
const A = loadLibrary(path.join(__dirname, '../modules/notch/NotchAvoid.js'));
const same = (a, b, m) => assert.deepEqual(JSON.parse(JSON.stringify(a)), b, m);

// 1920 px top edge, a 40 px bar 8 px from the edge
const base = { pos: 'top', transient: true, total: 1920, barDepth: 48, edgeGap: 4, gap: 4 };
const centered = (len) => ({ start: (1920 - len) / 2, length: len });

test('a bar packing every module in one run (dock-like) covers its whole span', () => {
    same(A.occupied({ lo: 600, hi: 1320, startReach: 0, endReach: 0 }), [[600, 1320]]);
    same(A.occupied({ lo: 0, hi: 1920, startReach: 300, endReach: 200, center: true }), [[0, 1920]], 'a center group closes the middle');
    same(A.occupied(null), []);
    same(A.occupied({ lo: 5, hi: 5 }), []);
});

test('a bar with start and end groups leaves the middle free', () => {
    same(A.occupied({ lo: 0, hi: 1920, inset: 8, startReach: 400, endReach: 300 }), [[0, 408], [1612, 1920]]);
    same(A.occupied({ lo: 0, hi: 1920, inset: 8, startReach: 400, endReach: 0 }), [[0, 408]]);
});

test('a notch over a dock-like bar drops below it when it grows', () => {
    const occ = A.occupied({ lo: 560, hi: 1360 });
    same(A.avoid({ ...base, occupied: occ, ...centered(440) }), { mode: 'drop', along: 0, across: 48 });
    same(A.avoid({ ...base, transient: false, occupied: occ, ...centered(440) }), { mode: 'edge', along: 0, across: 0 }, 'the resting notch stays where it is');
});

test('a grown notch that fits between the groups stays on the edge', () => {
    const occ = A.occupied({ lo: 0, hi: 1920, inset: 8, startReach: 400, endReach: 300 });
    same(A.avoid({ ...base, occupied: occ, ...centered(600) }), { mode: 'edge', along: 0, across: 0 });
});

test('it slides into the free slot when centered it would touch a group', () => {
    const occ = A.occupied({ lo: 0, hi: 1920, inset: 8, startReach: 700, endReach: 100 });
    // centered 700 px: [610, 1310] overlaps [0, 708]; the slot [708, 1812] holds it
    same(A.avoid({ ...base, occupied: occ, ...centered(700) }), { mode: 'shift', along: 98, across: 0 });
    // too long for the slot: drop
    same(A.avoid({ ...base, occupied: occ, ...centered(1200) }).mode, 'drop');
});

test('nothing to avoid: no bar on the edge, no overlap, side edges', () => {
    same(A.avoid({ ...base, occupied: [], ...centered(440) }).mode, 'edge');
    same(A.avoid({ ...base, occupied: [[0, 200]], ...centered(440) }).mode, 'edge');
    for (const pos of ['left', 'right'])
        same(A.avoid({ ...base, pos, occupied: [[0, 1080]], start: 300, length: 400 }).mode, 'edge', pos);
    same(A.avoid(null).mode, 'edge');
});

test('a dropped notch never moves toward the edge', () => {
    same(A.avoid({ ...base, barDepth: 0, edgeGap: 10, occupied: [[0, 1920]], ...centered(400) }).across, 0);
});

test('the offset grows away from every edge', () => {
    const r = { along: 5, across: 30 };
    same(A.offset('top', r), { x: 5, y: 30 });
    same(A.offset('bottom', r), { x: 5, y: -30 });
    same(A.offset('left', r), { x: 30, y: 5 });
    same(A.offset('right', r), { x: -30, y: 5 });
    same(A.offset('top', null), { x: 0, y: 0 });
});

test('the hover stem bridges the edge and the dropped notch, as wide as the resting notch', () => {
    const screen = { w: 1920, h: 1080 };
    const rest = { x: 940, y: 0, w: 40, h: 10 };
    same(A.stem('top', rest, 52, screen), { x: 940, y: 0, w: 40, h: 52 });
    same(A.stem('bottom', { ...rest, y: 1070 }, 52, screen), { x: 940, y: 1028, w: 40, h: 52 });
    same(A.stem('left', { x: 0, y: 500, w: 10, h: 40 }, 52, screen), { x: 0, y: 500, w: 52, h: 40 });
    same(A.stem('right', { x: 1910, y: 500, w: 10, h: 40 }, 52, screen), { x: 1868, y: 500, w: 52, h: 40 });
});

test('free slots fill the gaps between overlapping spans', () => {
    same(A.freeSlots(100, [[60, 80], [0, 10], [5, 20]]), [[20, 60], [80, 100]]);
    same(A.freeSlots(100, []), [[0, 100]]);
});
