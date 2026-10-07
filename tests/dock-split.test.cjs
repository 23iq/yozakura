const { test } = require('node:test');
const assert = require('node:assert/strict');
const path = require('node:path');
const { loadLibrary } = require('./lib/qmljs.cjs');
const S = loadLibrary(path.join(__dirname, '../modules/bar/panels/styles/DockSplit.js'));
const same = (a, b, m) => assert.deepEqual(JSON.parse(JSON.stringify(a)), b, m);

test('the end group goes right, the groups before it left', () => {
    same(S.runs(['a', 'b'], [], ['c']), { left: ['a', 'b'], right: ['c'] });
    same(S.runs(['a'], ['m'], ['c']), { left: ['a', '__sep__', 'm'], right: ['c'] });
    same(S.runs([], ['m'], ['c']), { left: ['m'], right: ['c'] });
    same(S.runs(['a'], ['m'], []), { left: ['a'], right: ['m'] });
});

test('a single group cannot part', () => {
    same(S.runs(['a', 'b'], [], []), { left: ['a', 'b'], right: [] });
    same(S.runs([], [], []), { left: [], right: [] });
    assert.equal(S.parts({ enabled: true, left: 300, right: 0, pad: 6, gap: 8, claim: 400, max: 1900 }), false);
});

const o = { left: 300, right: 200, pad: 6, sep: 17 };

test('it parts only for a claim that fits the edge', () => {
    assert.equal(S.parts({ ...o, enabled: true, gap: 8, claim: 400, max: 1900 }), true);
    // 2 * 312 + 416 = 1040
    assert.equal(S.partedLength({ ...o, gap: 416 }), 1040);
    assert.equal(S.parts({ ...o, enabled: true, gap: 8, claim: 400, max: 1039 }), false, 'too long: stays whole');
    assert.equal(S.parts({ ...o, enabled: true, gap: 8, claim: 0, max: 1900 }), false, 'nothing claimed');
    assert.equal(S.parts({ ...o, enabled: false, gap: 8, claim: 400, max: 1900 }), false);
});

test('resting: one capsule, the runs meet at the separator', () => {
    const l = S.layout({ ...o, gap: 416, part: 0 });
    const rest = S.restLength(o); // 529
    assert.equal(rest, 529);
    assert.equal(l.leftFrom, -rest / 2);
    assert.equal(l.rightTo, rest / 2);
    assert.equal(l.leftTo, l.seam);
    assert.equal(l.rightFrom, l.seam);
    assert.equal(l.leftRun, -rest / 2 + 6);
    assert.equal(l.rightRun, rest / 2 - 6 - 200);
});

test('parted: the gap is centered, each run beside it', () => {
    const l = S.layout({ ...o, gap: 416, part: 1 });
    same([l.leftTo, l.rightFrom], [-208, 208]);
    same([l.leftFrom, l.rightTo], [-208 - 312, 208 + 212]);
    assert.equal(l.rightRun, 208 + 6);
    // half of 1040 minus half the gap: the runs reach up to the gap
    same([l.startReach, l.endReach], [312, 312]);
});

test('halfway the surfaces are between both', () => {
    const a = S.layout({ ...o, gap: 416, part: 0 });
    const b = S.layout({ ...o, gap: 416, part: 1 });
    const m = S.layout({ ...o, gap: 416, part: 0.5 });
    assert.equal(m.leftTo, (a.leftTo + b.leftTo) / 2);
    assert.equal(m.rightFrom, (a.rightFrom + b.rightFrom) / 2);
    assert.equal(JSON.stringify(S.layout({ ...o, gap: 416, part: 3 })), JSON.stringify(b), 'clamped');
});
