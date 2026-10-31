const { test } = require('node:test');
const assert = require('node:assert/strict');
const path = require('node:path');
const qmljs = require('./lib/qmljs.cjs');

const J = qmljs.loadLibrary(path.join(__dirname, '../config/JsonUtil.js'));

test('clone passes undefined/null/primitives through and deep copies', () => {
    assert.equal(J.clone(undefined), undefined);
    assert.equal(J.clone(null), null);
    assert.equal(J.clone(3), 3);
    const src = { a: [1, { b: 2 }] };
    const c = J.clone(src);
    assert.equal(JSON.stringify(c), JSON.stringify(src));
    c.a[1].b = 9;
    assert.equal(src.a[1].b, 2);
});

test('deepEqual handles undefined, null, NaN, nested arrays and key order', () => {
    assert.ok(J.deepEqual(undefined, undefined));
    assert.ok(!J.deepEqual(undefined, null));
    assert.ok(J.deepEqual(null, null));
    assert.ok(J.deepEqual(NaN, NaN));
    assert.ok(!J.deepEqual(1, 2));
    assert.ok(J.deepEqual({ a: 1, b: { c: [1, [2, 3]] } }, { b: { c: [1, [2, 3]] }, a: 1 }));
    assert.ok(!J.deepEqual([1, [2, 3]], [1, [3, 2]]));
    assert.ok(!J.deepEqual([], {}));
    assert.ok(J.deepEqual({ a: 1, b: undefined }, { a: 1 }));
    assert.ok(!J.deepEqual({ a: 1 }, { a: 1, b: 2 }));
});
