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

test('rows: UI words are translated; a badge is your own prefix of that provider', () => {
    const prefix = id => ({ commands: '!', timers: '', routines: '@@' })[id];
    const rows = plain(Samples.rows('list', 'te', t, glyph, prefix));
    assert.equal(rows.commands[0].title, '[launcher.cmd.dnd]');
    assert.equal(rows.routines[0].title, '[prefs.timers.section.focus]');
    assert.equal(rows.timers[0].title, '10:00 · [focus.timer_name]');
    assert.equal(rows.commands[0].badge, '! dnd');
    assert.equal(rows.routines[0].badge, '@@ focus');
    // (no prefix of yours: nothing to type, no badge)
    assert.equal(rows.timers[0].badge, '');
    assert.equal(plain(Samples.rows('list', 'te', t, glyph)).commands[0].badge, '');
    // every key a sample row names exists in every language
    const fs = require('node:fs');
    const src = fs.readFileSync(path.join(__dirname, '..', 'modules/settings/stages/LauncherSamples.js'), 'utf8');
    const keys = [...src.matchAll(/"(?:title|subtitle|hint|badge)Key": "([^"]+)"/g)].map(m => m[1]);
    assert.ok(keys.length > 10);
    for (const lang of ['en', 'es', 'ru']) {
        const tr = JSON.parse(fs.readFileSync(path.join(__dirname, '..', 'translations', lang + '.json'), 'utf8'));
        for (const k of keys) assert.ok(k in tr, `${lang}: ${k}`);
    }
});
