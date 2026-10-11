'use strict';
// modules/components/kit/KeyedSync.js: key list edits for animated lists.
const test = require('node:test');
const assert = require('node:assert');
const path = require('node:path');
const qmljs = require('./lib/qmljs.cjs');

const K = qmljs.loadLibrary(path.join(__dirname, '../modules/components/kit/KeyedSync.js'));

const cases = [
    [[], []],
    [[], ['a', 'b']],
    [['a', 'b'], []],
    [['a', 'b', 'c'], ['a', 'c']],
    [['a', 'b', 'c'], ['c', 'a', 'b']],
    [['a', 'b', 'c'], ['d', 'b', 'a']],
    [['x', 'y'], ['y', 'z', 'x', 'w']],
];

test('ops turn the old keys into the new ones', () => {
    for (const [from, to] of cases)
        assert.deepEqual(K.apply(from, K.ops(from, to)), to, JSON.stringify([from, to]));
});

test('no edits when nothing changed', () => {
    assert.deepEqual(K.ops(['a', 'b'], ['a', 'b']), []);
});

test('a removal is one remove, not a rebuild', () => {
    assert.deepEqual(JSON.parse(JSON.stringify(K.ops(['a', 'b', 'c'], ['a', 'c']))), [{ op: 'remove', at: 1 }]);
});

test('a new key on top is one insert', () => {
    assert.deepEqual(JSON.parse(JSON.stringify(K.ops(['a', 'b'], ['n', 'a', 'b']))), [{ op: 'insert', at: 0, key: 'n' }]);
});
