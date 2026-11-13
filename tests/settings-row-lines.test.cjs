// A card's rows in lines (modules/settings/RowLines.js): picture choices
// that follow each other share a line when their pictures fit it.
const { test } = require('node:test');
const assert = require('node:assert/strict');
const path = require('node:path');
const { loadLibrary } = require('./lib/qmljs.cjs');

const R = loadLibrary(path.join(__dirname, '../modules/settings/RowLines.js'));

const pics = n => ({ display: 'cards', options: Array.from({ length: n }, (_, i) => ({ value: i })) });
const plain = { type: 'toggle' };
// plain arrays (the library runs in its own realm)
const L = (...a) => JSON.parse(JSON.stringify(R.lines(...a)));

test('two picture rows that fit share one line', () => {
    const e = [pics(2), pics(6)];
    assert.deepEqual(L(e, 1100, 12, 96), [[0, 1]]);
    // the shares follow the picture counts and leave the gap between rows
    const a = R.share(e, [0, 1], 0, 1100, 12), b = R.share(e, [0, 1], 1, 1100, 12);
    assert.equal(a, Math.floor((1100 - 24) * 2 / 8));
    assert.equal(b, Math.floor((1100 - 24) * 6 / 8));
    assert.ok(a + b + 24 <= 1100);
});

test('too many pictures for the width: a line each', () => {
    assert.deepEqual(L([pics(2), pics(6)], 700, 12, 96), [[0], [1]]);
});

test('plain rows and folding rows never share', () => {
    const fold = Object.assign(pics(2), { visibleWhen: { key: 'x', equals: true } });
    assert.deepEqual(L([plain, pics(2), plain, pics(3)], 1100, 12, 96), [[0], [1], [2], [3]]);
    assert.deepEqual(L([pics(2), fold], 1100, 12, 96), [[0], [1]]);
    assert.deepEqual(L([{ display: 'cards', options: [1] }, pics(2)], 1100, 12, 96), [[0], [1]]);
    assert.equal(R.share([plain], [0], 0, 500, 12), 500);
});

test('a picture editor declares its pictures', () => {
    assert.deepEqual(L([{ type: 'custom', component: 'ThemeModeCards', pictures: 3 }, pics(5)], 1100, 12, 96), [[0, 1]]);
    assert.deepEqual(L([{ type: 'custom', component: 'X' }, pics(5)], 1100, 12, 96), [[0], [1]]);
});

test('short rows stand beside pictures that leave room', () => {
    const T = (...a) => JSON.parse(JSON.stringify(R.layout(...a)));
    const edge = pics(4), sw = { type: 'toggle' };
    // four pictures of 190 leave 1100 - 796 - 24 = 280 px: two switches beside
    assert.deepEqual(T([edge, sw, sw], 1100, 12, 96, 190, 260), [{ rows: [0], side: [1, 2] }]);
    assert.equal(R.picturesWidth([edge, sw, sw], { rows: [0], side: [1, 2] }, 1100, 12, 190), 4 * 190 + 3 * 12);
    // not enough room, or a row that is not short: under the pictures
    assert.deepEqual(T([edge, sw], 1100, 12, 96, 190, 320), [{ rows: [0], side: [] }, { rows: [1], side: [] }]);
    assert.deepEqual(T([edge, { type: 'list' }], 1100, 12, 96, 190, 260), [{ rows: [0], side: [] }, { rows: [1], side: [] }]);
    // three at most; a dropdown counts as short, picture choices do not
    assert.deepEqual(T([pics(2), sw, { type: 'selector' }, sw, sw], 1100, 12, 96, 190, 260),
        [{ rows: [0], side: [1, 2, 3] }, { rows: [4], side: [] }]);
});

test('a third picture row joins while it fits, then starts a line', () => {
    assert.deepEqual(L([pics(2), pics(2), pics(2), pics(5)], 1100, 12, 96), [[0, 1, 2], [3]]);
});

test('a wide card puts short rows two a line', () => {
    const T = (...a) => JSON.parse(JSON.stringify(R.layout(...a)));
    const sw = { type: 'toggle' }, fold = { type: 'toggle', visibleWhen: { key: 'x', truthy: true } };
    const scr = { type: 'screens' };
    assert.deepEqual(T([sw, sw, sw, scr], 1100, 12, 96, 190, 280, 720),
        [{ rows: [0, 1], side: [] }, { rows: [2, 3], side: [] }]);
    assert.deepEqual(T([sw, { type: 'list' }, sw], 1100, 12, 96, 190, 280, 720),
        [{ rows: [0], side: [] }, { rows: [1], side: [] }, { rows: [2], side: [] }]);
    // equal shares, the gap between them
    assert.equal(R.share([sw, sw], [0, 1], 0, 1100, 12), Math.floor((1100 - 24) / 2));
    // a narrow card, or a row that folds: one a line
    assert.deepEqual(T([sw, sw], 500, 12, 96, 190, 280, 720), [{ rows: [0], side: [] }, { rows: [1], side: [] }]);
    assert.deepEqual(T([sw, fold], 1100, 12, 96, 190, 280, 720), [{ rows: [0], side: [] }, { rows: [1], side: [] }]);
});
