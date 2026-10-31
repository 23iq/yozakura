const { test } = require('node:test');
const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');
const { loadLibrary } = require('./lib/qmljs.cjs');

const ROOT = path.join(__dirname, '..');
const S = loadLibrary(path.join(ROOT, 'modules/bar/sentence/Sentence.js'));
const lang = (code) => JSON.parse(fs.readFileSync(path.join(ROOT, `translations/${code}.json`), 'utf8'));
const tables = { en: lang('en'), es: lang('es'), ru: lang('ru') };
const trOf = (code) => [(k) => tables[code][k] ?? tables.en[k] ?? '', (k) => tables[code][k] !== undefined || tables.en[k] !== undefined];
const plain = (a) => JSON.parse(JSON.stringify(a));

const VALUES = {
    clock: { time: '18:20', day: 'Saturday' },
    window: { app: 'Firefox' },
    workspace: { ws: '2' },
    battery: { pct: 82, charging: false },
    network: { kind: 'wifi', name: 'home' },
    volume: { pct: 40, muted: false },
    media: { playing: true, artist: 'Nujabes', title: 'Aruarian Dance' },
    notifications: { n: 3 },
    weather: { temp: '18°', desc: 'cloudy' },
};

const sentence = (code, opts, values = VALUES) => {
    const [tr, has] = trOf(code);
    return plain(S.build(values, opts, tr, has, code).map((f) => f.text));
};

test('the example line reads as one sentence in English', () => {
    assert.deepEqual(sentence('en', { order: ['clock', 'window', 'workspace', 'battery', 'media'], verbosity: 'full' }),
        ['Saturday, 18:20', 'Firefox on desk 2', 'battery 82%', 'playing Nujabes, Aruarian Dance']);
});

test('Russian uses its own grammar: na stole, plural forms', () => {
    const ru = (n) => sentence('ru', { order: ['window', 'workspace', 'notifications'], verbosity: 'short' },
        { ...VALUES, notifications: { n } });
    assert.deepEqual(ru(1), ['Firefox на столе 2', '1 уведомление']);
    assert.deepEqual(ru(3), ['Firefox на столе 2', '3 уведомления']);
    assert.deepEqual(ru(5), ['Firefox на столе 2', '5 уведомлений']);
    assert.deepEqual(ru(21), ['Firefox на столе 2', '21 уведомление']);
    assert.deepEqual(ru(12), ['Firefox на столе 2', '12 уведомлений']);
});

test('every template exists in en, es and ru with the same placeholders', () => {
    const keys = Object.keys(tables.en).filter((k) => k.startsWith('bar.sentence.'));
    assert.ok(keys.length > 15);
    const ph = (s) => (s.match(/\{\w+\}/g) || []).sort().join(',');
    for (const code of ['es', 'ru'])
        for (const k of keys) {
            const base = k.replace(/\.(one|few|many|other)$/, '');
            const own = tables[code][k] ?? tables[code][base + '.many'] ?? tables[code][base + '.other'];
            assert.ok(own !== undefined, `${code}: ${k}`);
            assert.equal(ph(own), ph(tables.en[k]), `${code}: ${k}`);
        }
    for (const k of ['bar.sentence.notifications.short', 'bar.sentence.notifications.full'])
        for (const f of ['one', 'few', 'many']) assert.ok(tables.ru[`${k}.${f}`], `ru ${k}.${f}`);
});

test('empty fragments hide: no battery, nothing playing, no notifications', () => {
    const v = { ...VALUES, battery: null, media: { playing: false, title: 'x' }, notifications: { n: 0 }, window: null };
    assert.deepEqual(sentence('en', { order: ['window', 'workspace', 'battery', 'media', 'notifications'] }, v), ['desk 2']);
    assert.deepEqual(sentence('en', { order: ['clock'] }, { clock: { time: '', day: 'x' } }), []);
});

test('the window merges with its workspace only when they are adjacent', () => {
    const [tr, has] = trOf('en');
    const merged = S.build(VALUES, { order: ['window', 'workspace'] }, tr, has, 'en');
    assert.equal(merged.length, 1);
    assert.deepEqual(plain(merged[0].ids), ['window', 'workspace']);
    assert.equal(merged[0].action, 'overview');
    assert.deepEqual(sentence('en', { order: ['workspace', 'clock', 'window'], verbosity: 'short' }), ['desk 2', '18:20', 'Firefox']);
});

test('segments mark data apart from the template words', () => {
    assert.deepEqual(plain(S.segments('battery {pct}%', { pct: 82 })),
        [{ text: 'battery ', value: false }, { text: '82', value: true }, { text: '%', value: false }]);
    assert.deepEqual(plain(S.segments('{a} x', { a: '' })), []);
    assert.equal(S.fill('{app} on desk {ws}', { app: 'Kitty', ws: 3 }), 'Kitty on desk 3');
});

test('verbosity and states pick their templates', () => {
    const en = (id, v, verb) => sentence('en', { order: [id], verbosity: verb }, { [id]: v })[0];
    assert.equal(en('battery', { pct: 50, charging: true }, 'full'), 'charging, 50%');
    assert.equal(en('battery', { pct: 50, charging: true }, 'short'), '50%');
    assert.equal(en('volume', { pct: 40, muted: true }, 'full'), 'muted');
    assert.equal(en('network', { kind: 'offline' }, 'short'), 'offline');
    assert.equal(en('network', { kind: 'wifi', name: '' }, 'full'), undefined);
    assert.equal(en('media', { playing: true, title: 'Song', artist: '' }, 'full'), 'playing Song');
    assert.equal(en('weather', { temp: '18°', desc: '' }, 'full'), '18°');
    assert.equal(en('notifications', { n: 1 }, 'full'), '1 new notification');
});

test('narrow bars drop the lowest priority first, never shrink a fragment', () => {
    const ids = ['clock', 'window', 'battery', 'media'];
    const w = [100, 120, 80, 200];
    assert.deepEqual(plain(S.fit(ids, w, S.DEFAULT_PRIORITY, 10000, 20)), [true, true, true, true]);
    // media > window > battery in the default ranking: battery goes first
    assert.deepEqual(plain(S.fit(ids, w, S.DEFAULT_PRIORITY, 470, 20)), [true, true, false, true]);
    assert.deepEqual(plain(S.fit(ids, w, S.DEFAULT_PRIORITY, 330, 20)), [true, false, false, true]);
    assert.deepEqual(plain(S.fit(ids, w, ['battery', 'clock'], 330, 20)), [true, false, true, false]);
    assert.deepEqual(plain(S.fit(ids, w, S.DEFAULT_PRIORITY, 50, 20)), [false, false, false, false]);
    assert.deepEqual(plain(S.fit(ids, w, S.DEFAULT_PRIORITY, 0, 20)), [true, true, true, true]);
    assert.equal(S.leadIndex([false, true, true]), 1);
    assert.equal(S.leadIndex([false]), -1);
});

test('lists normalize; priority ranks every fragment', () => {
    assert.deepEqual(plain(S.normalizeList(['media', 'bogus', 'media', 'clock'], S.DEFAULT_ORDER)), ['media', 'clock']);
    assert.deepEqual(plain(S.normalizeList(undefined, S.DEFAULT_ORDER)), plain(S.DEFAULT_ORDER));
    const p = S.normalizePriority(['weather']);
    assert.equal(p[0], 'weather');
    assert.equal(p.length, S.FRAGMENTS.length);
    assert.equal(S.separator('nope'), 'dash');
    assert.equal(S.separatorGlyph('dot'), '·');
    assert.equal(S.separatorHugs('comma'), true);
    assert.equal(S.verbosity('x'), 'full');
    for (const id of S.FRAGMENTS) assert.ok(S.action(id), id);
});

test('long titles trim at a word boundary, never mid-word', () => {
    assert.equal(S.trimWords('Aruarian Dance', 36), 'Aruarian Dance');
    assert.equal(S.trimWords('one two three four', 12), 'one two…');
    assert.equal(S.trimWords('Supercalifragilistic', 5), 'Supercalifragilistic');
    assert.equal(S.trimWords('a, b c', 3), 'a…');
    assert.equal(S.capitalizeFirst('суббота, 18:20'), 'Суббота, 18:20');
});

test('defaults and the settings catalog agree with the registry', () => {
    const bar = loadLibrary(path.join(ROOT, 'config/defaults/bar.js')).data;
    const o = bar.moduleOptions.sentence;
    assert.deepEqual(plain(S.normalizeList(o.fragments, [])), plain(o.fragments));
    assert.deepEqual(plain(S.normalizePriority(o.priority)), plain(o.priority));
    assert.ok(S.SEPARATORS.includes(o.separator));
    assert.ok(S.VERBOSITIES.includes(o.verbosity));
    const reg = loadLibrary(path.join(ROOT, 'modules/bar/BarModuleRegistry.js'));
    assert.ok(reg.has('sentence'));
});

test('the line stops short of the notch on its edge', () => {
    assert.equal(S.room(100, 300, 1600, 0, 16), Infinity);
    // start side: from x=100 to the notch's left edge (800 - 150 - 16)
    assert.equal(S.room(100, 300, 1600, 300, 16), 534);
    // end side: from the notch's right edge to the module's right edge
    assert.equal(S.room(1100, 400, 1600, 300, 16), 534);
    assert.equal(S.budget(1600, 0, Infinity), 800);
    assert.equal(S.budget(1600, 500, Infinity), 500);
    assert.equal(S.budget(1600, 5000, Infinity), 1600);
    assert.equal(S.budget(1600, 0, 300), 300);
});
