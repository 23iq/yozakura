const { test } = require('node:test');
const assert = require('node:assert/strict');
const path = require('node:path');
const { loadLibrary } = require('./lib/qmljs.cjs');
const C = loadLibrary(path.join(__dirname, '../modules/bar/activities/ActivityChips.js'));
const R = loadLibrary(path.join(__dirname, '../modules/widgets/defaultview/activities/ActivityRegistry.js'));
const plain = (v) => JSON.parse(JSON.stringify(v));

const act = (id, source, category = 'task', label = '') => ({ id, source, category, label });
const resolved = R.resolve([]);

test('chips: up to max, the rest behind one "+N" chip', () => {
    const list = [act('a', 'timers'), act('b', 'downloads'), act('c', 'privacy', 'privacy')];
    assert.deepEqual(plain(C.chips(list, 4)).overflow, 0);
    assert.equal(C.chips(list, 3).shown.length, 3);
    const two = plain(C.chips(list, 2));
    assert.deepEqual(two.shown.map((a) => a.id), ['a']);
    assert.equal(two.overflow, 2);
    assert.deepEqual(plain(C.chips(null, 4)), { shown: [], overflow: 0 });
    assert.equal(C.chips(list, 0).shown.length, 1, 'at least one chip');
});

test('context counts what each panel needs', () => {
    const ctx = plain(C.context({ tasks: [act('t', 'timers'), act('d', 'downloads')], transfers: [{}, {}], privacy: [act('m', 'privacy', 'privacy')] }));
    assert.deepEqual(ctx, { transfers: 2, timers: 1, privacy: 1 });
    assert.deepEqual(plain(C.context(null)), { transfers: 0, timers: 0, privacy: 0 });
});

test('a chip opens the notch panel of its registry trigger, when available', () => {
    const all = { transfers: true, timers: true, privacy: true };
    assert.equal(C.panelFor(act('downloads', 'downloads'), resolved, all), 'transfers', 'browser downloads join "downloads"');
    assert.equal(C.panelFor(act('timer:1', 'timers'), resolved, all), 'timers');
    assert.equal(C.panelFor(act('recording', 'recording', 'privacy'), resolved, all), 'privacy');
    assert.equal(C.panelFor(act('privacy:mic', 'privacy', 'privacy'), resolved, all), 'privacy');
    assert.equal(C.panelFor(act('osd', 'osd', 'privacy'), resolved, all), '', 'ephemeral ones open nothing');
    assert.equal(C.panelFor(act('downloads', 'downloads'), resolved, { transfers: false }), '', 'unavailable panel');
    assert.equal(C.panelFor(null, resolved, all), '');
});

test('labels show only when they fit', () => {
    assert.ok(C.showLabel(act('a', 'x', 'task', '47%'), 20, 30));
    assert.ok(!C.showLabel(act('a', 'x', 'task', '18:42'), 40, 30));
    assert.ok(!C.showLabel(act('a', 'x', 'task', ''), 0, 30));
});

test('click pins and unpins; hold while pinned or hovered', () => {
    let s = C.clicked({ chip: '', pinned: false }, 'a');
    assert.deepEqual(plain(s), { chip: 'a', pinned: true });
    assert.deepEqual(plain(C.clicked(s, 'b')), { chip: 'b', pinned: true }, 'another chip moves the pin');
    assert.deepEqual(plain(C.clicked(s, 'a')), { chip: '', pinned: false });
    assert.ok(C.held(true, false, false));
    assert.ok(C.held(false, true, false));
    assert.ok(C.held(false, false, true), 'pointer moved from the chip into the popup');
    assert.ok(!C.held(false, false, false));
});
