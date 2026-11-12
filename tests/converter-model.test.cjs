'use strict';
// Converter window logic (modules/converter/ConverterModel.js): rows from
// probe results, target changes per row and per kind, picker sections,
// row states, job events, sizes and dropped / chosen paths.
const test = require('node:test');
const assert = require('node:assert');
const path = require('node:path');
const { loadLibrary } = require('./lib/qmljs.cjs');

const M = loadLibrary(path.join(__dirname, '..', 'modules/converter/ConverterModel.js'));
const plain = v => JSON.parse(JSON.stringify(v));

const t = (id, kind, extra) => Object.assign({ id, label: id.toUpperCase(), kind, available: true, popular: false, lossy: false }, extra || {});
const jpg = {
    path: '/p/a.jpg', name: 'a.jpg', size: 2048, kind: 'image', format: 'jpg', default: 'png',
    targets: [t('png', 'image', { popular: true }), t('webp', 'image', { popular: true, lossy: true }), t('ico', 'image'), t('pdf', 'document', { popular: true })],
};
const png = Object.assign({}, jpg, { path: '/p/b.png', name: 'b.png', format: 'png', default: 'jpg',
    targets: [t('jpg', 'image', { popular: true, lossy: true }), t('webp', 'image', { popular: true, lossy: true }), t('ico', 'image')] });
const flac = { path: '/p/c.flac', name: 'c.flac', size: 10, kind: 'audio', format: 'flac', default: 'mp3',
    targets: [t('mp3', 'audio', { popular: true, lossy: true, available: false, needs: 'ffmpeg' }), t('wav', 'audio', { popular: true })] };
const bad = { path: '/p/x.bin', name: 'x.bin', targets: [], error: 'unknown format' };

test('added files propose the default target, once per path', () => {
    let rows = M.addFiles([], [jpg, flac, bad]);
    rows = M.addFiles(rows, [jpg]);
    assert.deepStrictEqual(plain(rows.map(r => [r.path, r.target])), [['/p/a.jpg', 'png'], ['/p/c.flac', 'mp3'], ['/p/x.bin', '']]);
    assert.deepStrictEqual(plain(rows.map(M.rowState)), ['ready', 'unavailable', 'invalid']);
});

test('a row target changes only to one of its targets', () => {
    let rows = M.addFiles([], [jpg]);
    rows = M.setTarget(rows, '/p/a.jpg', 'webp');
    assert.strictEqual(rows[0].target, 'webp');
    rows = M.setTarget(rows, '/p/a.jpg', 'mp3');
    assert.strictEqual(rows[0].target, 'webp');
});

test('a kind header changes every row of that kind', () => {
    let rows = M.addFiles([], [jpg, png, flac]);
    assert.deepStrictEqual(plain(M.kindGroups(rows)), [{ kind: 'image', count: 2, target: '' }]);
    assert.deepStrictEqual(plain(M.commonTargets(rows, 'image').map(x => x.id)), ['webp', 'ico']);
    rows = M.setKindTarget(rows, 'image', 'webp');
    assert.deepStrictEqual(plain(rows.map(r => r.target)), ['webp', 'webp', 'mp3']);
    assert.deepStrictEqual(plain(M.kindGroups(rows)), [{ kind: 'image', count: 2, target: 'webp' }]);
});

test('picker: popular first, then the rest by kind', () => {
    const s = M.pickerSections(jpg.targets);
    assert.deepStrictEqual(plain(s.map(x => [x.kind, x.popular, x.items.map(i => i.id)])),
        [['', true, ['png', 'webp', 'pdf']], ['image', false, ['ico']]]);
});

test('start, pending, jobs, retry', () => {
    let rows = M.addFiles([], [jpg, flac, png]);
    assert.ok(M.needsQuality(M.setTarget(rows, '/p/a.jpg', 'webp')));
    assert.ok(!M.needsQuality(rows.slice(0, 1)));
    const items = M.startItems(rows);
    assert.deepStrictEqual(plain(items), [{ path: '/p/a.jpg', target: 'png' }, { path: '/p/b.png', target: 'jpg' }]);
    rows = M.markPending(rows, items);
    assert.ok(M.busy(rows));
    assert.strictEqual(M.startable(rows).length, 0);
    // an event before the start reply finds its row by path and target
    rows = M.applyJob(rows, { id: 'c1', path: '/p/a.jpg', to: 'png', state: 'running', progress: 0.5 });
    assert.strictEqual(M.rowState(rows[0]), 'running');
    rows = M.applyJob(rows, { id: 'c1', path: '/p/a.jpg', to: 'png', state: 'done', progress: 1, output: '/p/a.png' });
    rows = M.applyJob(rows, { id: 'c2', path: '/p/b.png', to: 'jpg', state: 'failed', error: 'boom' });
    assert.deepStrictEqual(plain(rows.map(M.rowState)), ['done', 'unavailable', 'failed']);
    assert.ok(!M.busy(rows));
    // a done row keeps its target; a failed one can retry
    assert.strictEqual(M.setTarget(rows, '/p/a.jpg', 'webp')[0].job.state, 'done');
    assert.deepStrictEqual(plain(M.startItems(rows)), [{ path: '/p/b.png', target: 'jpg' }]);
    // changing a failed row's target clears its error
    assert.strictEqual(M.rowState(M.setTarget(rows, '/p/b.png', 'ico')[2]), 'ready');
    // unknown job events change nothing
    assert.strictEqual(M.applyJob(rows, { id: 'zz', path: '/elsewhere', to: 'png', state: 'done' }), rows);
    assert.strictEqual(M.removeRow(rows, '/p/a.jpg').length, 2);
});

test('sizes, paths, thumbnails, kinds', () => {
    assert.strictEqual(M.formatSize(0), '0 B');
    assert.strictEqual(M.formatSize(512), '512 B');
    assert.strictEqual(M.formatSize(1536), '1.5 KB');
    assert.strictEqual(M.formatSize(50 * 1024 * 1024), '50 MB');
    assert.deepStrictEqual(plain(M.localPaths(['file:///home/me/a%20b.png', 'https://x/y', 'file://localhost/tmp/c.mp3'])),
        ['/home/me/a b.png', '/tmp/c.mp3']);
    assert.deepStrictEqual(plain(M.chooserPaths('/a/b.png\n/c d.mp3\n\nnot a path')), ['/a/b.png', '/c d.mp3']);
    assert.ok(M.hasThumb(jpg) && !M.hasThumb(flac));
    assert.strictEqual(M.dirOf('/p/a.jpg'), '/p');
    assert.strictEqual(M.baseName('/p/a.jpg'), 'a.jpg');
    assert.strictEqual(M.kindInfo('audio').icon, 'fileAudio');
    assert.strictEqual(M.kindInfo('nope').icon, 'file');
});

test('every kind has an icon in Icons.qml and a translated label', () => {
    const fs = require('node:fs');
    const icons = fs.readFileSync(path.join(__dirname, '..', 'modules/theme/Icons.qml'), 'utf8');
    for (const lang of ['en', 'es', 'ru']) {
        const tr = JSON.parse(fs.readFileSync(path.join(__dirname, '..', 'translations', lang + '.json'), 'utf8'));
        for (const k of M.KINDS.concat([M.kindInfo('')])) {
            assert.ok(tr[k.label], `${k.label} missing in ${lang}`);
            assert.ok(new RegExp(`property string ${k.icon}:`).test(icons), k.icon);
        }
    }
});
