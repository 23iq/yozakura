const { test } = require('node:test');
const assert = require('node:assert/strict');
const path = require('node:path');
const { loadLibrary } = require('./lib/qmljs.cjs');

const M = loadLibrary(path.join(__dirname, '../modules/widgets/dashboard/emoji/EmojiModel.js'));
const plain = value => JSON.parse(JSON.stringify(value));

const TABLE = JSON.stringify({
    '😀': { name: 'grinning face', slug: 'grinning_face', group: 'Smileys & Emotion' },
    '👋': { name: 'waving hand', slug: 'waving_hand', group: 'People & Body', skin_tone_support: true },
    '🐱': { name: 'cat face', slug: 'cat_face', group: 'Animals & Nature' }
});

test('parseTable: rows with a search key; bad json is empty', () => {
    const rows = M.parseTable(TABLE);
    assert.equal(rows.length, 3);
    assert.deepEqual(plain(rows[1]), {
        emoji: '👋', name: 'waving hand', slug: 'waving_hand', group: 'People & Body',
        search: 'waving hand waving_hand', skin_tone_support: true
    });
    assert.equal(rows[0].skin_tone_support, false);
    assert.deepEqual(plain(M.parseTable('nope')), []);
    assert.deepEqual(plain(M.parseRecent('{"a":1}')), []);
    assert.equal(M.parseRecent('[{"emoji":"x"}]').length, 1);
});

test('filter: glyph, name, slug and group; empty query matches nothing', () => {
    const rows = M.parseTable(TABLE);
    assert.deepEqual(plain(M.filter(rows, 'CAT')).map(r => r.emoji), ['🐱']);
    assert.deepEqual(plain(M.filter(rows, 'waving_')).map(r => r.emoji), ['👋']);
    assert.deepEqual(plain(M.filter(rows, 'animals')).map(r => r.emoji), ['🐱']);
    assert.deepEqual(plain(M.filter(rows, '😀')).map(r => r.emoji), ['😀']);
    assert.equal(M.filter(rows, '').length, 0);
    assert.equal(M.initial(rows).length, 3);
});

test('recentEntry: skin tone in glyph, name and search', () => {
    const hand = M.parseTable(TABLE)[1];
    const e = M.recentEntry(hand, M.SKIN_TONES[0].modifier);
    assert.equal(e.emoji, '👋🏻');
    assert.equal(e.name, 'waving hand (light)');
    assert.equal(e.search, 'waving hand waving_hand light');
    assert.equal(M.recentEntry(hand, '').emoji, '👋');
    assert.equal(M.skinToneName('x'), 'default');
});

test('addRecent: dedupes, counts uses, most used first, capped', () => {
    let r = [];
    r = M.addRecent(r, { emoji: 'a' }, 1);
    r = M.addRecent(r, { emoji: 'b' }, 2);
    assert.deepEqual(plain(r).map(x => x.emoji), ['b', 'a']);
    r = M.addRecent(r, { emoji: 'a' }, 3);
    assert.deepEqual(plain(r).map(x => [x.emoji, x.usage]), [['a', 2], ['b', 1]]);
    for (let i = 0; i < 60; i++)
        r = M.addRecent(r, { emoji: 'e' + i }, 10 + i);
    assert.equal(r.length, M.MAX_RECENT);
    assert.equal(r[0].emoji, 'a');
});

test('geometry: recent strip, expanded tones, scroll into view', () => {
    const rows = [{ recent: true }, { tones: false }, { tones: true }, { tones: false }];
    const g = { row: 48, option: 36, recent: 96, expanded: 2 };
    assert.equal(M.rowHeight(rows, 0, g), 96);
    assert.equal(M.rowHeight(rows, 2, g), 48 + 5 * 36);
    assert.equal(M.rowHeight(rows, 1, Object.assign({}, g, { expanded: 1 })), 48);
    assert.equal(M.rowY(rows, 3, g), 96 + 48 + 228);
    assert.equal(M.scrollToShow(10, 48, 0, 200), -1);
    assert.equal(M.scrollToShow(300, 48, 0, 200), 148);
    assert.equal(M.scrollToShow(10, 48, 50, 200), 10);
});
