// Pure helpers of the settings preset studio (modules/settings/presets/PresetModel.js).
const { test } = require('node:test');
const assert = require('node:assert/strict');
const path = require('node:path');

const qmljs = require('./lib/qmljs.cjs');
const repo = path.join(__dirname, '..');
const M = qmljs.loadLibrary(path.join(repo, 'modules/settings/presets/PresetModel.js'));
const en = require('../translations/en.json');
const plain = v => JSON.parse(JSON.stringify(v));

// `preset aspects --json` (backend/pkg/presets.Aspects); the Go tests keep
// this fixture in sync.
const aspects = require('./fixtures/preset-aspects.json');

const presets = [
    { name: 'Neon Tokyo', official: true, author: 'Yozakura', description: 'OLED black islands', tags: ['islands', 'oled', 'frame'],
      look: { 'bar.position': 'top', 'theme.lightMode': false, 'theme.oledMode': true, 'theme.animDuration': 200, 'desktop.depthClock': true, 'wallpaper.matugenScheme': 'scheme-content' } },
    { name: 'Glacier', official: true, author: 'Frost Studio', tags: ['classic', 'light'],
      look: { 'bar.position': 'bottom', 'theme.lightMode': true, 'theme.oledMode': false, 'theme.animDuration': 400, 'desktop.depthClock': false, 'wallpaper.matugenScheme': 'scheme-fidelity' } },
    { name: 'Mine', official: false, author: 'User', tags: ['classic', 'dark'],
      look: { 'bar.position': 'left', 'theme.lightMode': false, 'theme.oledMode': false, 'theme.animDuration': 0, 'desktop.depthClock': false } },
];

test('gallery filter: kind and query over name, author, description and tags', () => {
    const names = l => l.map(p => p.name);
    assert.deepEqual(names(M.filter(presets, '', 'all')), ['Neon Tokyo', 'Glacier', 'Mine']);
    assert.deepEqual(names(M.filter(presets, '', 'builtin')), ['Neon Tokyo', 'Glacier']);
    assert.deepEqual(names(M.filter(presets, '', 'user')), ['Mine']);
    assert.deepEqual(names(M.filter(presets, '', 'light')), ['Glacier']);
    assert.deepEqual(names(M.filter(presets, '', 'dark')), ['Neon Tokyo', 'Mine']);
    assert.deepEqual(names(M.filter(presets, 'frost', 'all')), ['Glacier']);
    assert.deepEqual(names(M.filter(presets, 'oled islands', 'all')), ['Neon Tokyo']);
    assert.deepEqual(names(M.filter(presets, 'black', 'builtin')), ['Neon Tokyo']);
    assert.deepEqual(names(M.filter(presets, 'nothing here', 'all')), []);
});

test('every filter and tag has a translation', () => {
    for (const f of M.FILTERS)
        assert.ok(en['prefs.presets.filter.' + f], f);
    for (const t of Object.keys(M.TAG_LABELS))
        assert.ok(en[M.tagLabel(t)], t);
    assert.equal(M.tagLabel('mystery'), 'mystery');
    for (const a of aspects.concat([{ id: 'other' }])) {
        assert.ok(en['prefs.presets.aspect.' + a.id], a.id);
        assert.ok(en['prefs.presets.aspect.' + a.id + '.desc'], a.id);
        assert.ok(M.aspectIcon(a.id));
    }
});

test('aspectOf mirrors the Go registry (moved keys win over domains)', () => {
    assert.equal(M.aspectOf(aspects, 'bar.position'), 'layout');
    assert.equal(M.aspectOf(aspects, 'theme.roundness'), 'colors');
    assert.equal(M.aspectOf(aspects, 'theme.animDuration'), 'windows');
    assert.equal(M.aspectOf(aspects, 'wallpaper.matugenScheme'), 'colors');
    assert.equal(M.aspectOf(aspects, 'desktop.depthClock'), 'desktop');
    assert.equal(M.aspectOf(aspects, 'voice.model'), 'other');
});

test('composeLook takes each key from the preset chosen for its aspect', () => {
    const look = M.composeLook(aspects, presets, { layout: 'Mine', colors: 'Glacier', windows: 'Neon Tokyo', desktop: 'Neon Tokyo' }, 'Mine');
    assert.equal(look['bar.position'], 'left');
    assert.equal(look['theme.lightMode'], true);
    assert.equal(look['wallpaper.matugenScheme'], 'scheme-fidelity');
    assert.equal(look['theme.animDuration'], 200, 'motion follows windows, not colors');
    assert.equal(look['desktop.depthClock'], true);
    const d = M.defaultSources(aspects, presets, 'Mine');
    assert.deepEqual(plain(d), { layout: 'Mine', colors: 'Mine', windows: 'Mine', desktop: 'Mine', lockscreen: 'Mine', terminal: 'Mine' });
    assert.equal(M.defaultSources(aspects, presets, 'gone').layout, 'Neon Tokyo', 'falls back to the first preset');
    let i = 0;
    const s = M.shuffle(aspects, presets, () => (i++ % 3) / 3);
    assert.deepEqual(Object.keys(s), aspects.map(a => a.id));
});

test('names: unique suggestions and the backend rules', () => {
    assert.equal(M.uniqueName(presets, 'My look'), 'My look');
    assert.equal(M.uniqueName(presets, 'mine'), 'mine 2');
    assert.equal(M.nameProblem(presets, 'Fresh'), '');
    assert.equal(M.nameProblem(presets, 'neon tokyo'), 'prefs.presets.name.builtin');
    assert.equal(M.nameProblem(presets, 'MINE'), 'prefs.presets.name.taken');
    assert.equal(M.nameProblem(presets, 'Mine', 'Mine'), '', 'renaming to itself');
    for (const bad of ['', '  ', ' x', 'a/b', '.hidden', 'current', 'defaults'])
        assert.equal(M.nameProblem(presets, bad), 'prefs.presets.name.invalid', JSON.stringify(bad));
    for (const k of ['prefs.presets.name.invalid', 'prefs.presets.name.builtin', 'prefs.presets.name.taken'])
        assert.ok(en[k], k);
});

test('palette per look: scheme + mode, OLED blacks out the background roles', () => {
    const schemes = { 'scheme-content': { dark: { background: '#111111', surface: '#222222', primary: '#ff00aa' }, light: { background: '#ffffff', primary: '#aa0055' } } };
    const neon = M.paletteFor(presets[0].look, schemes);
    assert.equal(neon.background, '#000000');
    assert.equal(neon.surface, '#000000');
    assert.equal(neon.primary, '#ff00aa');
    assert.equal(schemes['scheme-content'].dark.background, '#111111', 'input untouched');
    assert.equal(M.paletteFor(presets[1].look, schemes), null, 'unknown scheme: null (live colors)');
    assert.equal(M.paletteFor({ 'theme.lightMode': true }, { 'scheme-tonal-spot': { light: { primary: '#123456' } } }).primary, '#123456');
});

test('thumbnail key changes with the look, wallpaper, palette and size only', () => {
    const k = M.thumbKey(presets[0].look, '/w/a.jpg', { primary: '#fff' }, '300x170');
    assert.equal(k, M.thumbKey(Object.assign({}, presets[0].look), '/w/a.jpg', { primary: '#fff' }, '300x170'));
    assert.notEqual(k, M.thumbKey(presets[1].look, '/w/a.jpg', { primary: '#fff' }, '300x170'));
    assert.notEqual(k, M.thumbKey(presets[0].look, '/w/b.jpg', { primary: '#fff' }, '300x170'));
    assert.notEqual(k, M.thumbKey(presets[0].look, '/w/a.jpg', { primary: '#000' }, '300x170'));
    assert.notEqual(k, M.thumbKey(presets[0].look, '/w/a.jpg', { primary: '#fff' }, '600x340'));
    assert.ok(k.startsWith(M.THUMB_VERSION + '|'));
});

test('editor helpers: values and jump targets', () => {
    assert.equal(M.formatValue(true), 'on');
    assert.equal(M.formatValue(0.3333), '0.33');
    assert.equal(M.formatValue(null), '—');
    assert.equal(M.formatValue(['primary']), '["primary"]');
    assert.ok(M.formatValue({ a: 'x'.repeat(80) }).endsWith('…'));
    const aspect = aspects[0];
    assert.deepEqual(plain(M.jumpTarget({ category: 'bar', section: 'placement', entry: '' }, aspect, () => true)), { category: 'bar', section: 'placement', entry: '' });
    assert.deepEqual(plain(M.jumpTarget({ key: 'bar.launcherIconSize' }, aspect, () => true)), { category: 'bar', section: '', entry: '' });
    assert.equal(M.jumpTarget({ category: 'gone' }, aspects[2], id => id !== 'gone').category, 'windows');
    assert.equal(M.seconds(9001), 10);
    assert.equal(M.seconds(-5), 0);
});
