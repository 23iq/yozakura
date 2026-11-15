// The launcher previews' sample search (modules/settings/stages/
// LauncherSamples.js): the query the real launcher shows and the rows of
// the providers that are samples in a preview.
const { test } = require('node:test');
const assert = require('node:assert/strict');
const path = require('node:path');

const qmljs = require('./lib/qmljs.cjs');
const lib = file => qmljs.loadLibrary(path.join(__dirname, '..', file));
const plain = v => JSON.parse(JSON.stringify(v));

const Samples = lib('modules/settings/stages/LauncherSamples.js');
const Providers = lib('modules/widgets/launcher/Providers.js');

const t = k => '[' + k + ']';
const glyph = n => '<' + n + '>';

test('query: two letters of your first app, "fi" without apps, empty for a grid', () => {
    assert.equal(Samples.query(['Telegram', 'Discord'], 'list'), 'te');
    assert.equal(Samples.query([' ', 'Firefox'], 'cards'), 'fi');
    assert.equal(Samples.query(['X', 'kitty'], 'list'), 'ki');
    assert.equal(Samples.query([], 'list'), 'fi');
    assert.equal(Samples.query(null, 'list'), 'fi');
    assert.equal(Samples.query(['Telegram'], 'grid'), '');
});

test('rows: one sample row per non-live inline provider; none for a grid', () => {
    const rows = plain(Samples.rows('list', 'te', t, glyph));
    const inline = Providers.PROVIDERS.filter(p => p.kind === 'inline').map(p => p.id);
    for (const id of inline) {
        if (Samples.LIVE.indexOf(id) >= 0)
            assert.equal(rows[id], undefined, id + ' stays live');
        else
            assert.equal(rows[id].length, 1, id + ' has a sample row');
    }
    assert.deepEqual(plain(Samples.rows('grid', '', t, glyph)), {});
});

test('rows: provider row fields, translated, the AI row asks the query', () => {
    const rows = plain(Samples.rows('cards', 'te', t, glyph));
    assert.equal(rows.ai[0].title, 'te');
    assert.equal(rows.ai[0].subtitle, '[launcher.ai.ask]');
    assert.equal(rows.ai[0].hint, '[launcher.ai.send]');
    assert.equal(rows.calculator[0].icon, '<calculator>');
    assert.equal(rows.calculator[0].emphasis, true);
    assert.equal(rows.files[0].subtitle, '~/Documents/final-draft.pdf');
    for (const id of Object.keys(rows)) {
        const r = rows[id][0];
        assert.ok(r.key && r.title && r.hint, id + ' has a key, a title and what Enter does');
    }
});
