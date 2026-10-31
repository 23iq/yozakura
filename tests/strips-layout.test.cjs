const { test } = require('node:test');
const assert = require('node:assert/strict');
const path = require('node:path');
const { loadLibrary } = require('./lib/qmljs.cjs');
const L = loadLibrary(path.join(__dirname, '../modules/notifications/strips/StripLayout.js'));
const plain = o => JSON.parse(JSON.stringify(o));

test('auto hangs from the top edge; explicit edges are kept, junk is auto', () => {
    assert.equal(L.resolveEdge('auto'), 'top');
    assert.equal(L.resolveEdge('left'), 'left');
    assert.equal(L.resolveEdge('bottom'), 'bottom');
    assert.equal(L.resolveEdge('diagonal'), 'top');
    assert.equal(L.isRow('top'), true);
    assert.equal(L.isRow('right'), false);
});

test('slots keep the newest max groups and count the rest for the knot', () => {
    assert.deepEqual(plain(L.slots(['a', 'b', 'c'], 5)), { keys: ['a', 'b', 'c'], overflow: 0 });
    assert.deepEqual(plain(L.slots(['a', 'b', 'c', 'd', 'e', 'f', 'g'], 4)), { keys: ['a', 'b', 'c', 'd'], overflow: 3 });
    assert.equal(L.slots([], 0).keys.length, 0);
    assert.equal(L.slots(['a', 'b'], 0).keys.length, 1, 'at least one strip');
});

test('a strip keeps its thread length; lengths vary within the step', () => {
    assert.equal(L.threadLength('Mail', 8, 20), L.threadLength('Mail', 8, 20));
    const lens = ['Mail', 'Slack', 'Firefox', 'Telegram', 'Steam', 'Calendar'].map(k => L.threadLength(k, 8, 20));
    lens.forEach(n => assert.ok(n >= 8 && n <= 28, String(n)));
    assert.ok(new Set(lens).size > 2, 'a loose rhythm, not a ruler');
});

const dims = { thread: 20, long: 160, short: 40, cardW: 360, cardH: 120 };

test('top strips hang down: thread from the pivot to the body', () => {
    const f = L.frame('top', Object.assign({ open: 0 }, dims));
    assert.deepEqual(plain(f.pivot), { x: 20, y: 0 });
    assert.equal(f.w, 40);
    assert.equal(f.h, 180);
    assert.deepEqual(plain(f.body), { x: 0, y: 20, w: 40, h: 160 });
    assert.equal(f.thread.h, 20);
    assert.equal(f.textRotation, 90);
});

test('an open strip is the card, still on its thread', () => {
    const f = L.frame('top', Object.assign({ open: 1 }, dims));
    assert.deepEqual(plain(f.body), { x: 0, y: 20, w: 360, h: 120 });
    const half = L.frame('top', Object.assign({ open: 0.5 }, dims));
    assert.equal(half.body.w, 200);
    assert.equal(half.body.h, 140);
});

test('bottom strips stand up, side strips lie like tags', () => {
    const b = L.frame('bottom', Object.assign({ open: 0 }, dims));
    assert.deepEqual(plain(b.pivot), { x: 20, y: 180 });
    assert.deepEqual(plain(b.body), { x: 0, y: 0, w: 40, h: 160 });
    const l = L.frame('left', Object.assign({ open: 0 }, dims));
    assert.equal(l.w, 180);
    assert.equal(l.h, 40);
    assert.deepEqual(plain(l.pivot), { x: 0, y: 20 });
    assert.equal(l.body.x, 20);
    assert.equal(l.textRotation, 0);
    const r = L.frame('right', Object.assign({ open: 1 }, dims));
    assert.deepEqual(plain(r.body), { x: 0, y: 0, w: 360, h: 120 });
    assert.deepEqual(plain(r.pivot), { x: 380, y: 60 });
});

test('hole by the edge, then art, then the text lane', () => {
    const o = { hole: 16, art: 20, pad: 8 };
    const t = L.lanes('top', 40, 160, o);
    assert.equal(t.hole.x, 20);
    assert.ok(t.hole.y < t.art.y && t.art.y < t.lane.y);
    assert.equal(t.lane.length, 160 - 44 - 8);
    const b = L.lanes('bottom', 40, 160, o);
    assert.ok(b.hole.y > b.art.y && b.art.y > b.lane.y);
    assert.equal(b.hole.y, 160 - t.hole.y);
    const l = L.lanes('left', 160, 40, o);
    assert.equal(l.hole.y, 20);
    assert.ok(l.hole.x < l.art.x && l.art.x < l.lane.x);
    const r = L.lanes('right', 160, 40, o);
    assert.ok(r.hole.x > r.art.x && r.art.x > r.lane.x);
    assert.equal(L.lanes('top', 40, 10, o).lane.length, 0);
});

test('towardEdge points back at the edge', () => {
    assert.deepEqual(plain(L.towardEdge('top')), { x: 0, y: -1 });
    assert.deepEqual(plain(L.towardEdge('right')), { x: 1, y: 0 });
});
