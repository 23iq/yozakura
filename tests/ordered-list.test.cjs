const { test } = require('node:test');
const assert = require('node:assert/strict');
const path = require('node:path');
const { loadLibrary } = require('./lib/qmljs.cjs');

const L = loadLibrary(path.join(__dirname, '..', 'modules/settings/editors/OrderedList.js'));
const plain = (v) => JSON.parse(JSON.stringify(v));
const V = ['a', 'b', 'c', 'd'];

test('rows: chosen in order, then the rest off (subset) or on (ranking)', () => {
    assert.deepEqual(plain(L.rows(['c', 'a', 'x', 'a'], V, true)),
        [{ value: 'c', on: true }, { value: 'a', on: true }, { value: 'b', on: false }, { value: 'd', on: false }]);
    assert.deepEqual(plain(L.rows(['c'], V, false)).map((r) => r.on), [true, true, true, true]);
    assert.deepEqual(plain(L.rows(undefined, V, true)).map((r) => r.on), [false, false, false, false]);
});

test('move stays among the chosen ones', () => {
    assert.deepEqual(plain(L.move(['a', 'b', 'c'], V, true, 'c', -1)), ['a', 'c', 'b']);
    assert.deepEqual(plain(L.move(['a', 'b'], V, true, 'a', -1)), ['a', 'b']);
    assert.deepEqual(plain(L.move(['a', 'b'], V, true, 'b', 1)), ['a', 'b']);
    // a ranking holds every value: moving past the stored ones works
    assert.deepEqual(plain(L.move(['b'], V, false, 'b', 2)), ['a', 'c', 'b', 'd']);
});

test('toggle appends or removes', () => {
    assert.deepEqual(plain(L.toggle(['a'], V, 'c', true)), ['a', 'c']);
    assert.deepEqual(plain(L.toggle(['a', 'c'], V, 'a', false)), ['c']);
    assert.deepEqual(plain(L.toggle(['a'], V, 'zzz', true)), ['a']);
});
