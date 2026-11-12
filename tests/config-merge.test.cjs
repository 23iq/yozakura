// config/ConfigMerge.js: what this process changed in a config domain since
// it last read or wrote the file, laid over the file as another process
// left it (ConfigFile.qml merges instead of writing its whole adapter).
const { test } = require('node:test');
const assert = require('node:assert/strict');
const path = require('node:path');
const { loadLibrary } = require('./lib/qmljs.cjs');

const M = loadLibrary(path.join(__dirname, '../config/ConfigMerge.js'));
const plain = v => JSON.parse(JSON.stringify(v));

// A JsonObject stand-in: has objectName like every QObject.
const qobj = props => Object.assign({ objectName: '' }, props);

test('serialize follows the defaults and recurses into JsonObjects', () => {
    const adapter = {
        model: 'y', list: ['a'], extra: 1,
        quickAsk: qobj({ enabled: true, hotkey: 'k' }),
        map: { a: { b: 1 } }
    };
    const defaults = { model: '', list: [], quickAsk: { enabled: false, hotkey: '' }, map: {} };
    assert.deepEqual(plain(M.serialize(adapter, defaults)), {
        model: 'y', list: ['a'], quickAsk: { enabled: true, hotkey: 'k' }, map: { a: { b: 1 } }
    });
});

test('changes are the leaves local changed, arrays are values', () => {
    const base = { a: 1, b: [1, 2], o: { x: 1, y: 2 }, m: { k: 1 } };
    const local = { a: 1, b: [1, 3], o: { x: 1, y: 5 }, m: {} };
    assert.deepEqual(plain(M.changes(base, local)), [
        { path: ['b'], value: [1, 3] },
        { path: ['o', 'y'], value: 5 },
        { path: ['m', 'k'] }
    ]);
    assert.equal(M.changes(base, local)[2].value, undefined, 'a removed map key');
});

test('nothing changed: no changes; keys only the file has are not dropped', () => {
    assert.deepEqual(plain(M.changes({ a: 1, unknown: 2 }, { a: 1 })), []);
});

test('no base yet: every local key counts (the old whole write)', () => {
    assert.deepEqual(plain(M.changes(null, { a: 1, b: 2 })).map(c => c.path), [['a'], ['b']]);
});

test('assign: in place into JsonObjects, copies of plain maps', () => {
    const map = { keep: 1, gone: 2 };
    const adapter = { top: 0, ai: qobj({ quick: qobj({ on: false }) }), map };
    M.assign(adapter, ['top'], 4);
    M.assign(adapter, ['ai', 'quick', 'on'], true);
    M.assign(adapter, ['map', 'gone'], undefined);
    M.assign(adapter, ['map', 'deep', 'x'], 1);
    assert.equal(adapter.top, 4);
    assert.equal(adapter.ai.quick.on, true);
    assert.deepEqual(plain(adapter.map), { keep: 1, deep: { x: 1 } });
    assert.notEqual(adapter.map, map, 'a map is replaced, so its property notifies');
    M.assign(adapter, ['ai', 'nope'], undefined);
    assert.ok(!('nope' in adapter.ai) || adapter.ai.nope === undefined, 'a removed JsonObject property is left alone');
});

test('the merge keeps both processes\' edits', () => {
    const base = { a: 1, b: 1, o: { x: 1, y: 1 } };
    const local = { a: 2, b: 1, o: { x: 1, y: 2 } };       // this process: a, o.y
    const disk = { a: 1, b: 3, o: { x: 3, y: 1 } };        // the other one: b, o.x
    const adapter = Object.assign({}, disk, { o: qobj(disk.o) });
    M.changes(base, local).forEach(c => M.assign(adapter, c.path, c.value));
    assert.deepEqual(plain(M.serialize(adapter, base)), { a: 2, b: 3, o: { x: 3, y: 2 } });
});
