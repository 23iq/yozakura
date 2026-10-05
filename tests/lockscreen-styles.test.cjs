const { test } = require('node:test');
const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');
const qmljs = require('./lib/qmljs.cjs');

const loadLibrary = file => qmljs.loadLibrary(path.join(__dirname, file));
const plain = value => JSON.parse(JSON.stringify(value));

const registry = loadLibrary('../modules/lockscreen/styles/LockStyleRegistry.js');
const layout = loadLibrary('../modules/lockscreen/LockLayout.js');
const validator = loadLibrary('../config/ConfigValidator.js');
const enums = loadLibrary('../config/meta/Enums.js');
const defaults = plain(loadLibrary('../config/defaults/lockscreen.js').data);
const stylesDir = path.join(__dirname, '../modules/lockscreen/styles');

// ------------------------------------------------------------- registry

test('every registry entry has its file, translations and a known tone list', () => {
    const en = JSON.parse(fs.readFileSync(path.join(__dirname, '../translations/en.json'), 'utf8'));
    const ids = registry.ids();
    assert.equal(new Set(ids).size, ids.length, 'ids are unique');
    assert.ok(ids.includes(registry.DEFAULT_ID));
    for (const s of registry.styles) {
        assert.ok(fs.existsSync(path.join(stylesDir, s.file)), `${s.id}: ${s.file} exists`);
        const qml = fs.readFileSync(path.join(stylesDir, s.file), 'utf8');
        assert.match(qml, /^LockStyle \{/m, `${s.id} extends LockStyle`);
        for (const slot of ['backdrop', 'clock', 'passwordField', 'mediaCard', 'status'])
            assert.match(qml, new RegExp(`^    ${slot}: Component \\{`, 'm'), `${s.id} fills the ${slot} slot`);
        assert.ok(en[s.labelKey], `${s.id}: ${s.labelKey} translated`);
        assert.ok(en[s.descKey], `${s.id}: ${s.descKey} translated`);
        assert.ok(s.tones.length >= 1 && s.tones.every(t => t === 'light' || t === 'dark'), `${s.id}: tones`);
    }
});

test('every style file is registered', () => {
    const files = fs.readdirSync(stylesDir).filter(f => f.endsWith('Style.qml') && f !== 'LockStyle.qml');
    assert.deepEqual(files.sort(), plain(registry.styles.map(s => s.file)).sort());
});

test('the brief\'s six styles exist, glass first (default)', () => {
    assert.deepEqual(plain(registry.ids()), ['glass', 'paper', 'terminal', 'aurora', 'neon', 'poster']);
    assert.equal(registry.DEFAULT_ID, 'glass');
});

test('unknown ids fall back to the default style', () => {
    assert.equal(registry.get('nope').id, 'glass');
    assert.equal(registry.has('nope'), false);
    assert.equal(registry.get('paper').id, 'paper');
});

test('tone resolution: own tone, theme, forced, and styles without the tone', () => {
    assert.equal(registry.resolveTone('paper', 'style', false), 'light', 'paper is light by itself');
    assert.equal(registry.resolveTone('glass', 'style', true), 'dark', 'glass is dark by itself');
    assert.equal(registry.resolveTone('paper', 'theme', false), 'dark');
    assert.equal(registry.resolveTone('aurora', 'theme', true), 'light');
    assert.equal(registry.resolveTone('terminal', 'light', false), 'light');
    assert.equal(registry.resolveTone('neon', 'light', true), 'dark', 'neon has no light tone');
    assert.equal(registry.resolveTone('neon', 'theme', true), 'dark');
    assert.equal(registry.resolveTone('bogus', 'theme', true), 'light', 'unknown -> glass, which has light');
});

test('blur: -1 means the style\'s own, values are clamped', () => {
    assert.equal(registry.blurFor(-1, 0.7), 0.7);
    assert.equal(registry.blurFor(undefined, 0.45), 0.45);
    assert.equal(registry.blurFor(0, 0.7), 0);
    assert.equal(registry.blurFor(0.3, 0.7), 0.3);
    assert.equal(registry.blurFor(4, 0.7), 1);
});

// ------------------------------------------------------- config / catalog

test('validator keeps known styles/tones and resets bad values', () => {
    const v = raw => plain(validator.validate(raw, defaults));
    assert.deepEqual(v({}), defaults);
    const good = v({ style: 'neon', tone: 'theme', blur: 0.4, showMedia: false });
    assert.equal(good.style, 'neon');
    assert.equal(good.tone, 'theme');
    assert.equal(good.blur, 0.4);
    assert.equal(good.showMedia, false);
    const bad = v({ style: 'vaporwave', tone: 'sepia', blur: 7 });
    assert.equal(bad.style, 'glass');
    assert.equal(bad.tone, 'style');
    assert.equal(bad.blur, -1);
    assert.equal(v({ blur: -1 }).blur, -1);
});

test('the catalog enum is read from the registry', () => {
    assert.deepEqual(plain(enums.lockStyles()), plain(registry.ids()));
    assert.deepEqual(plain(enums.LOCK_TONES), ['style', 'theme', 'light', 'dark']);
});

// ---------------------------------------------------------------- layout

const screen = (arrangement, extra = {}) => layout.place(Object.assign({
    arrangement, clockSide: 'left', atTop: false, width: 1920, height: 1080, margin: 54,
    clockW: 600, clockH: 260, clusterW: 420, clusterH: 120, statusH: 36
}, extra));
const overlaps = (p, c) => {
    const a = { x: p.clockX, y: p.clockY, w: c.clockW ?? 600, h: c.clockH ?? 260 };
    const b = { x: p.clusterX, y: p.clusterY, w: c.clusterW ?? 420, h: c.clusterH ?? 120 };
    return a.x < b.x + b.w && b.x < a.x + a.w && a.y < b.y + b.h && b.y < a.y + a.h;
};

test('every arrangement keeps clock and cluster apart and on screen, both positions', () => {
    for (const arrangement of layout.ARRANGEMENTS) {
        for (const atTop of [false, true]) {
            for (const [width, height] of [[1920, 1080], [2560, 1440], [1280, 800], [1080, 1920]]) {
                const ctx = { atTop, width, height, margin: Math.max(32, height * 0.05) };
                const p = screen(arrangement, ctx);
                const tag = `${arrangement} ${atTop ? 'top' : 'bottom'} ${width}x${height}`;
                assert.ok(!overlaps(p, {}), `${tag}: no overlap`);
                for (const [x, w] of [[p.clockX, 600], [p.clusterX, 420]])
                    assert.ok(x >= 0 && x + w <= width, `${tag}: inside horizontally`);
                assert.ok(p.clusterY >= 0 && p.clusterY + 120 <= height, `${tag}: cluster inside`);
            }
        }
    }
});

test('position decides which edge the cluster sits on', () => {
    for (const arrangement of layout.ARRANGEMENTS) {
        const bottom = screen(arrangement);
        const top = screen(arrangement, { atTop: true });
        assert.ok(bottom.clusterY > top.clusterY, `${arrangement}`);
    }
    assert.ok(screen('stack').clusterY > screen('stack').clockY, 'stack: clock above the cluster');
    assert.ok(screen('center').clusterY > screen('center').clockY, 'center: clock first');
    assert.ok(screen('center', { atTop: true }).clockY > screen('center', { atTop: true }).clusterY, 'center top: cluster first');
});

test('split puts the clock on its side and the cluster on the other; narrow screens fall back to stack', () => {
    const left = screen('split');
    assert.ok(left.clockX < left.clusterX);
    const right = screen('split', { clockSide: 'right' });
    assert.ok(right.clockX > right.clusterX);
    const narrow = screen('split', { width: 900, clockW: 600 });
    assert.equal(narrow.arrangement, 'stack');
    assert.equal(screen('wat').arrangement, 'stack', 'unknown arrangement -> stack');
});

test('column aligns clock and cluster to the left margin', () => {
    const p = screen('column');
    assert.equal(p.clockX, p.clusterX);
    assert.ok(p.clockX < 200);
});
