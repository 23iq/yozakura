const { test } = require('node:test');
const assert = require('node:assert/strict');
const path = require('node:path');

const qmljs = require('./lib/qmljs.cjs');
const Anchor = qmljs.loadLibrary(path.join(__dirname, '..', 'modules/aicenter/transcript/ScrollAnchor.js'));
const plain = v => JSON.parse(JSON.stringify(v));

// rows of three source items; item 1 has a thinking row and a reply
const ROWS = [
    { key: '0', source: 0 },
    { key: '1:think', source: 1 },
    { key: '1:text', source: 1 },
    { key: '2', source: 2 },
];
const resolve = (rows, at) => plain(Anchor.resolve(rows.length, i => rows[i], at));

test('a row is found by its key, wherever it moved', () => {
    assert.deepEqual(resolve(ROWS, { key: '1:text', source: 1, index: 1 }), { index: 2, exact: true, complete: true });
    const noThinking = ROWS.filter(r => !r.key.endsWith(':think'));
    assert.deepEqual(resolve(noThinking, { key: '1:text', source: 1, index: 2 }), { index: 1, exact: true, complete: true });
});

test('a hidden row stands in with the first row of its source item', () => {
    const noThinking = ROWS.filter(r => !r.key.endsWith(':think'));
    assert.deepEqual(resolve(noThinking, { key: '1:think', source: 1, index: 1 }), { index: 1, exact: false, complete: true });
});

test('rows still loading: not complete until a later source item is there', () => {
    assert.deepEqual(resolve([], { key: '1:text', source: 1, index: 2 }), { index: -1, exact: false, complete: false });
    const partial = ROWS.slice(0, 2);
    assert.deepEqual(resolve(partial, { key: '1:text', source: 1, index: 2 }), { index: 1, exact: false, complete: false });
});

test('an index alone, and nothing remembered', () => {
    assert.deepEqual(resolve(ROWS, { index: 3, offset: 0 }), { index: 3, exact: true, complete: true });
    assert.deepEqual(resolve(ROWS, { index: 9 }), { index: -1, exact: false, complete: false });
    assert.equal(resolve(ROWS, -1).index, -1);
    assert.equal(resolve(ROWS, 5080).index, -1);
});
