const { test } = require('node:test');
const assert = require('node:assert/strict');
const path = require('node:path');
const { loadLibrary } = require('./lib/qmljs.cjs');

const P = loadLibrary(path.join(__dirname, '../modules/services/Plural.js'));

test('en and es: one only for 1', () => {
    for (const lang of ['en', 'es', 'de', 'xx', '']) {
        assert.equal(P.category(lang, 1), 'one');
        assert.equal(P.category(lang, 0), 'other');
        assert.equal(P.category(lang, 2), 'other');
    }
});

test('ru: one / few / many', () => {
    const want = { 1: 'one', 2: 'few', 4: 'few', 5: 'many', 11: 'many', 12: 'many', 14: 'many', 21: 'one', 22: 'few', 25: 'many', 101: 'one', 111: 'many', 0: 'many' };
    for (const [n, c] of Object.entries(want))
        assert.equal(P.category('ru', Number(n)), c, `ru ${n}`);
    assert.equal(P.category('ru-RU', 3), 'few');
    assert.equal(P.category('uk', 22), 'few');
});
