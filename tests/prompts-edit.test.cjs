const { test } = require('node:test');
const assert = require('node:assert/strict');
const path = require('node:path');
const qmljs = require('./lib/qmljs.cjs');
const P = qmljs.loadLibrary(path.join(__dirname, '..', 'modules/settings/editors/PromptsEdit.js'));
const plain = v => JSON.parse(JSON.stringify(v));

const list = () => [{ id: 'a', name: 'A' }, { id: 'b', name: 'B' }, { id: 'c', name: 'C' }];

test('edits address the item by id', () => {
    const out = plain(P.apply(list(), { id: 'b', index: 1 }, { name: 'B2' }));
    assert.deepEqual(out.map(x => x.name), ['A', 'B2', 'C']);
});

test('delete then edit with the stale index touches nothing else', () => {
    const afterDelete = plain(P.apply(list(), { id: 'a', index: 0 }, null));
    assert.deepEqual(afterDelete.map(x => x.id), ['b', 'c']);
    // the delegate of "a" is gone; the one of "c" still holds index 2
    const gone = plain(P.apply(afterDelete, { id: 'a', index: 0 }, { name: 'X' }));
    assert.deepEqual(gone, afterDelete);
    const c = plain(P.apply(afterDelete, { id: 'c', index: 2 }, { name: 'C2' }));
    assert.deepEqual(c.map(x => x.name), ['B', 'C2']);
});

test('append and id-less fallback', () => {
    assert.equal(P.apply(list(), null, { id: 'd' }).length, 4);
    const noId = plain(P.apply([{ name: 'x' }, { name: 'y' }], { id: '', index: 1 }, { name: 'Y' }));
    assert.deepEqual(noId.map(x => x.name), ['x', 'Y']);
    assert.equal(plain(P.apply([{ name: 'x' }], { id: '', index: 5 }, { name: 'Z' }))[0].name, 'x');
});
