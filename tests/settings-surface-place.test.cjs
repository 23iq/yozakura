// Pure geometry of the Launcher / Dashboard stages
// (modules/settings/stages/SurfacePlace.js): where a surface opens on the
// screen miniature, and the launcher's sample results.
const { test } = require('node:test');
const assert = require('node:assert/strict');
const path = require('node:path');
const { loadLibrary } = require('./lib/qmljs.cjs');

const P = loadLibrary(path.join(__dirname, '../modules/settings/stages/SurfacePlace.js'));

const FREE = { x: 0, y: 40, w: 1000, h: 500 };
const ISLAND = { x: 450, y: 0, w: 100, h: 30 };
const inside = (r) => r.x >= FREE.x - 1e-6 && r.x + r.w <= FREE.x + FREE.w + 1e-6;

test('a spotlight is centred in the free space', () => {
    const r = P.rect('spotlight', FREE, ISLAND, {});
    assert.equal(r.from, 'center');
    assert.ok(Math.abs(r.x + r.w / 2 - 500) < 1e-6);
    assert.ok(Math.abs(r.y + r.h / 2 - (40 + 250)) < 1e-6);
});

test('the notch grows from the island, on its edge, inside the screen', () => {
    const top = P.rect('notch', FREE, ISLAND, { islandEdge: 'top' });
    assert.equal(top.from, 'island');
    assert.equal(top.y, ISLAND.y);
    assert.ok(Math.abs(top.x + top.w / 2 - 500) < 1e-6);
    const low = P.rect('notch', FREE, { x: 450, y: 560, w: 100, h: 30 }, { islandEdge: 'bottom' });
    assert.equal(low.y + low.h, 590);
    const edge = P.rect('notch', FREE, { x: 0, y: 0, w: 60, h: 30 }, { islandEdge: 'top' });
    assert.ok(inside(edge), 'an island at the edge keeps the surface on screen');
});

test('a sheet takes a side, the full height; the dashboard is wider', () => {
    const right = P.rect('sheet', FREE, ISLAND, {});
    assert.equal(right.from, 'right');
    assert.equal(right.x + right.w, 1000);
    assert.equal(right.h, FREE.h);
    const left = P.rect('sheet', FREE, ISLAND, { sheetSide: 'left' });
    assert.equal(left.x, 0);
    assert.ok(P.rect('sheet', FREE, ISLAND, { wide: true }).w > right.w);
    assert.ok(P.rect('spotlight', FREE, ISLAND, { wide: true }).w > P.rect('spotlight', FREE, ISLAND, {}).w);
});

test('sample results follow the active providers, in order, up to max', () => {
    const r = P.results(['calculator', 'apps', 'clipboard', 'files'], 2);
    assert.equal(r.map((x) => x.id).join(','), 'calculator,apps');
    assert.equal(r[0].icon, 'calculator');
    assert.equal(P.results(['clipboard'], 5).length, 0, 'tab providers have no inline result');
    assert.equal(P.results(['apps', 'files', 'ai'], 9).length, 3);
});
