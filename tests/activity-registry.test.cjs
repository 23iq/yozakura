const { test } = require('node:test');
const assert = require('node:assert/strict');
const path = require('node:path');
const { loadLibrary } = require('./lib/qmljs.cjs');
const R = loadLibrary(path.join(__dirname, '../modules/widgets/defaultview/activities/ActivityRegistry.js'));
const plain = v => JSON.parse(JSON.stringify(v));
const ids = list => plain(list).map(e => e.id);

test('every descriptor has the documented shape', () => {
    const want = ['media', 'tasks', 'timers', 'privacy', 'osd', 'battery', 'bluetooth', 'extras'];
    assert.deepEqual(ids(R.DESCRIPTORS).sort(), want.slice().sort());
    for (const d of R.DESCRIPTORS) {
        assert.ok(['leading', 'trailing', 'center'].includes(d.side), d.id);
        assert.equal(typeof d.priority, 'number', d.id);
        assert.ok(Array.isArray(d.sources), d.id);
        assert.equal(typeof d.trigger, 'string', d.id);
        assert.equal(typeof d.ephemeralMs, 'number', d.id);
    }
});
test('resolve with no config gives the registry defaults in priority order', () => {
    const r = plain(R.resolve([]));
    assert.equal(r.length, R.DESCRIPTORS.length);
    for (let i = 1; i < r.length; i++) assert.ok(r[i - 1].priority >= r[i].priority);
    assert.ok(r.every(e => e.side === R.descriptor(e.id).side));
    assert.deepEqual(plain(R.resolve(undefined)), r);
    assert.deepEqual(plain(R.resolve('garbage')), r);
});
test('resolve keeps the user order, side and enabled flag; missing ids get defaults; unknown ids are dropped', () => {
    const r = plain(R.resolve([
        { id: 'battery', side: 'leading', enabled: false },
        'nope',
        { id: 'privacy' },
        { id: 'battery', side: 'trailing' },
        { id: 'timers', side: 'sideways' },
        { id: 'media', side: 'leading' }
    ]));
    assert.deepEqual(r.slice(0, 4).map(e => e.id), ['battery', 'privacy', 'timers', 'media']);
    assert.equal(r.length, R.DESCRIPTORS.length, 'missing ids appended, duplicates and unknown dropped');
    assert.equal(r[0].side, 'leading');
    assert.equal(r[0].enabled, false);
    assert.equal(r[1].enabled, true);
    assert.equal(r[2].side, 'leading', 'invalid side falls back to the default');
    assert.equal(r[3].side, 'center', 'media is fixed in the center');
    assert.equal(R.isEnabled([{ id: 'battery', enabled: false }], 'battery'), false);
    assert.equal(R.isEnabled([], 'battery'), true);
    assert.equal(R.isEnabled([], 'unknown'), false);
});
test('sides route activities by source, drop disabled ones and follow the user order', () => {
    const acts = [
        { id: 'rec', source: 'recording', category: 'privacy', priority: 100 },
        { id: 't1', source: 'timers', category: 'task', priority: 50 },
        { id: 'dl', source: 'downloads', category: 'task', priority: 40 },
        { id: 'bat', source: 'battery', category: 'privacy', priority: 60 },
        { id: 'bt', source: 'bluetooth', category: 'privacy', priority: 55 },
        { id: 'x', source: 'mystery', category: 'privacy', priority: 99 }
    ];
    const s = plain(R.sides(acts, R.resolve([{ id: 'bluetooth', enabled: false }, { id: 'battery', side: 'leading' }])));
    assert.deepEqual(s.leading.map(a => a.id), ['bat', 't1', 'dl']);
    assert.deepEqual(s.trailing.map(a => a.id), ['rec', 'x'], 'unknown sources stay on their category side, last');
    const d = plain(R.sides(acts, R.resolve([])));
    assert.ok(d.trailing.some(a => a.id === 'bt'));
    assert.equal(plain(R.sides(null, R.resolve([]))).leading.length, 0);
});
test('trigger of an activity is its entry trigger; ephemeral ones have none', () => {
    const r = R.resolve([]);
    assert.equal(R.triggerOf({ source: 'timers' }, r), 'timers');
    assert.equal(R.triggerOf({ source: 'downloads' }, r), 'tasks');
    assert.equal(R.triggerOf({ source: 'recording' }, r), 'privacy');
    assert.equal(R.triggerOf({ source: 'battery' }, r), '');
    assert.equal(R.triggerOf(null, r), '');
    assert.equal(R.triggerOf({ source: 'x', category: 'privacy' }, r), 'privacy');
    assert.equal(R.triggerOf({ source: 'x', category: 'task' }, r), 'tasks');
    assert.ok(R.descriptor('osd').ephemeralMs >= 1000 && R.descriptor('osd').ephemeralMs <= 1500);
});
