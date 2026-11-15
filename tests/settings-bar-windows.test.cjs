// The windows a vertical bar is shown through on the Bar stage
// (modules/settings/stages/BarWindows.js): its two ends, its middle when a
// module sits there, side by side, and its modules mapped into them.
const { test } = require('node:test');
const assert = require('node:assert/strict');
const path = require('node:path');
const { loadLibrary } = require('./lib/qmljs.cjs');

const B = loadLibrary(path.join(__dirname, '..', 'modules/settings/stages/BarWindows.js'));
const plain = v => JSON.parse(JSON.stringify(v));

test('a bar shorter than a window is one window', () => {
    assert.deepEqual(plain(B.windows(200, 240, [])), [{ y: 0, len: 200 }]);
});

test('a long bar shows its two ends; a middle only when a module sits there', () => {
    const ends = plain(B.windows(1440, 240, [{ y: 10, h: 30 }, { y: 1380, h: 40 }]));
    assert.deepEqual(ends, [{ y: 0, len: 240 }, { y: 1200, len: 240 }]);
    const mid = plain(B.windows(1440, 240, [{ y: 10, h: 30 }, { y: 700, h: 40 }]));
    assert.equal(mid.length, 3);
    assert.equal(mid[1].y, 720 - 120);
    // (a middle module near an end window keeps the window on the bar)
    const low = plain(B.windows(1440, 240, [{ y: 260, h: 10 }]));
    assert.ok(low[1].y >= 0 && low[1].y + 240 <= 1440);
});

test('the windows stand side by side, centred, their spans at the zoom', () => {
    const spans = [{ y: 0, len: 200 }, { y: 1240, len: 200 }];
    const r = plain(B.place(spans, 600, 240, 100, 1, 20));
    assert.equal(r.length, 2);
    assert.equal(r[0].x, 190);
    assert.equal(r[1].x, 310);
    assert.equal(r[0].y, 20);
    assert.equal(r[0].h, 200);
    assert.deepEqual(plain(B.place([], 600, 240, 100, 1, 20)), []);
});

test('modules land in the window that shows their middle, clipped to it', () => {
    const spans = [{ y: 0, len: 200 }, { y: 1240, len: 200 }];
    const rects = plain(B.place(spans, 600, 240, 100, 1, 20));
    const mods = [
        { id: 'launcher', x: 4, y: 8, w: 36, h: 36 },
        { id: 'clock', x: 4, y: 1400, w: 36, h: 30 },
        { id: 'hidden', x: 4, y: 700, w: 36, h: 30 },
        { id: 'cut', x: 4, y: 190, w: 36, h: 18 }
    ];
    const out = plain(B.mapModules(mods, spans, rects, 1));
    assert.deepEqual(out.map(m => m.id), ['launcher', 'clock', 'cut']);
    assert.deepEqual(out[0], { id: 'launcher', x: 194, y: 28, w: 36, h: 36 });
    assert.equal(out[1].x, 314);
    assert.equal(out[1].y, 20 + 160);
    // (the cut one ends at its window's bottom)
    assert.equal(out[2].y + out[2].h, 220);
});
