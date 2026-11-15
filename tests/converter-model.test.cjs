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
    assert.deepStrictEqual(plain(M.kindGroups(rows)), [{ kind: 'image', count: 2, target: '' }, { kind: 'audio', count: 1, target: 'mp3' }]);
    assert.deepStrictEqual(plain(M.commonTargets(rows, 'image').map(x => x.id)), ['webp', 'ico']);
    rows = M.setKindTarget(rows, 'image', 'webp');
    assert.deepStrictEqual(plain(rows.map(r => r.target)), ['webp', 'webp', 'mp3']);
    assert.deepStrictEqual(plain(M.kindGroups(rows)), [{ kind: 'image', count: 2, target: 'webp' }, { kind: 'audio', count: 1, target: 'mp3' }]);
    assert.deepStrictEqual(plain(M.entryKeys(M.addFiles(rows, [bad]))),
        ['h:image', 'r:/p/a.jpg', 'r:/p/b.png', 'h:audio', 'r:/p/c.flac', 'r:/p/x.bin']);
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
    // an event of a job no row holds changes nothing (even same path and target)
    assert.strictEqual(M.applyJob(rows, { id: 'old', path: '/p/a.jpg', to: 'png', state: 'done', output: '/p/a.png' }), rows);
    // the start reply hands the pending rows their jobs
    rows = M.attachJobs(rows, [{ id: 'c1', path: '/p/a.jpg', to: 'png', state: 'queued' },
        { id: 'c2', path: '/p/b.png', to: 'jpg', state: 'queued' }]);
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

test('stale jobs never take over a row; failed starts clear pending', () => {
    // convert, then the same file again: the old done job (replayed by the
    // backend) must not claim the new pending row
    let rows = M.addFiles([], [jpg]);
    rows = M.markPending(rows, M.startItems(rows));
    rows = M.applyJob(rows, { id: 'c7', path: '/p/a.jpg', to: 'png', state: 'done', output: '/p/a.png' });
    assert.strictEqual(rows[0].job.state, 'pending');
    rows = M.attachJobs(rows, [{ id: 'c9', path: '/p/a.jpg', to: 'png', state: 'queued' }]);
    rows = M.applyJob(rows, { id: 'c9', path: '/p/a.jpg', to: 'png', state: 'done', output: '/p/a (1).png' });
    assert.strictEqual(rows[0].job.output, '/p/a (1).png');
    // remove then re-add: the removed row's job no longer applies
    rows = M.addFiles(M.removeRow(rows, '/p/a.jpg'), [jpg]);
    assert.strictEqual(M.applyJob(rows, { id: 'c9', state: 'done' }), rows);
    assert.strictEqual(M.rowState(rows[0]), 'ready');
    rows = M.clearPending(M.markPending(rows, M.startItems(rows)));
    assert.strictEqual(M.rowState(rows[0]), 'ready');
});

test('file URIs are percent-encoded', () => {
    assert.strictEqual(M.fileUri('/a b/#c,d.png'), 'file:///a%20b/%23c%2Cd.png');
});

test('a pending row (start sent, no reply yet) is working, not editable', () => {
    let rows = M.addFiles([], [jpg, png]);
    rows = M.markPending(rows, [{ path: '/p/a.jpg', target: 'png' }]);
    assert.ok(!M.editable(rows[0]) && M.working(rows[0]));
    assert.ok(M.editable(rows[1]) && !M.working(rows[1]));
    // neither the row nor its kind header can change its target
    assert.strictEqual(M.setTarget(rows, '/p/a.jpg', 'webp')[0].target, 'png');
    assert.strictEqual(M.setTarget(rows, '/p/a.jpg', 'webp')[0].job.state, 'pending');
    const kind = M.setKindTarget(rows, 'image', 'webp');
    assert.deepStrictEqual(plain(kind.map(r => [r.target, r.job ? r.job.state : null])), [['png', 'pending'], ['webp', null]]);
    for (const s of ['queued', 'running'])
        assert.ok(M.working({ job: { state: s } }) && !M.editable({ job: { state: s } }));
    for (const s of ['done', 'failed', 'cancelled'])
        assert.ok(!M.working({ job: { state: s } }));
    assert.ok(!M.working(null) && M.editable(null));
});

test('backend errors map to translation keys by their code, never by the message', () => {
    const info = (c, e, a) => plain(M.errorInfo(c, e, a));
    assert.deepStrictEqual(info('clipboard_no_file', 'no file on the clipboard'),
        { key: 'clipboard_no_file', args: [], text: 'no file on the clipboard' });
    assert.deepStrictEqual(info('clipboard_empty', 'x').key, 'clipboard_empty');
    assert.deepStrictEqual(info('clipboard_unavailable', 'x').key, 'clipboard_unavailable');
    assert.deepStrictEqual(info('unknown_method', 'unknown method: convert.paste').key, 'unknown_method');
    assert.deepStrictEqual(info('out_dir', 'output folder /x y does not exist', ['/x y']),
        { key: 'out_dir', args: ['/x y'], text: 'output folder /x y does not exist' });
    assert.deepStrictEqual(info('tool_missing', 'm', ['MP3', 'ffmpeg']).args, ['MP3', 'ffmpeg']);
    // the English message alone (an old daemon) is shown as it is
    assert.deepStrictEqual(info('', 'cannot write to /ro'), { key: '', args: [], text: 'cannot write to /ro' });
    // a tool's or parser's own words stay as they are
    assert.deepStrictEqual(info('tool_failed', "Unknown encoder 'libmp3lame'"),
        { key: '', args: [], text: "Unknown encoder 'libmp3lame'" });
    assert.deepStrictEqual(info('bad_input', 'YAML: line 2').key, '');
    assert.deepStrictEqual(info(null, null), { key: '', args: [], text: '' });
    // probe rows: their code, unknown_format without one
    assert.strictEqual(M.errorKey('folder'), 'folder');
    assert.strictEqual(M.errorKey(undefined), 'unknown_format');
    const fs = require('node:fs');
    const codes = ['not_found', 'folder', 'not_regular', 'unknown_format', 'unknown_target', 'unsupported', 'tool_missing',
        'too_large', 'timeout', 'cancelled', 'no_output', 'crashed', 'no_write', 'exists', 'out_dir', 'stopping',
        'clipboard_empty', 'clipboard_unavailable', 'clipboard_no_file', 'bad_request', 'unknown_job', 'unknown_method', 'other'];
    const dir = path.join(__dirname, '..', 'translations');
    for (const file of fs.readdirSync(dir).filter(f => f.endsWith('.json') && f !== 'languages.json')) {
        const tr = JSON.parse(fs.readFileSync(path.join(dir, file), 'utf8'));
        for (const k of codes)
            assert.ok(tr['converter.error.' + k], `converter.error.${k} missing in ${file}`);
        for (const k of ['done', 'saved', 'failed', 'reason'])
            assert.ok(tr['notify.convert.' + k], `notify.convert.${k} missing in ${file}`);
    }
});

test('a hide next to an output change is an output loss, not a close', () => {
    assert.ok(M.outputLoss(10000, 9800, 1500)); // the output went, then the hide
    assert.ok(M.outputLoss(10000, 11200, 1500)); // the hide came first
    assert.ok(!M.outputLoss(10000, 5000, 1500)); // an old change: the user closed it
    assert.ok(!M.outputLoss(10000, 0, 1500)); // no output change since start
});

test('start requests are told apart by their batch token', () => {
    let rows = M.addFiles([], [jpg, png]);
    rows = M.markPending(rows, [{ path: '/p/a.jpg', target: 'png' }], 1);
    rows = M.markPending(rows, [{ path: '/p/b.png', target: 'jpg' }], 2);
    // request 1 failed: only its row goes back to ready
    const failed = M.clearPending(rows, 1);
    assert.deepStrictEqual(plain(failed.map(M.rowState)), ['ready', 'pending']);
    // a reply attaches only to its own request's rows (same path and target)
    const j = { id: 'c1', path: '/p/b.png', to: 'jpg', state: 'queued' };
    assert.strictEqual(M.attachJobs(rows, [j], 1)[1].job.state, 'pending');
    assert.strictEqual(M.attachJobs(rows, [j], 2)[1].job.id, 'c1');
    // removed and added again while request 1 was pending: request 2's row
    let again = M.addFiles(M.removeRow(rows, '/p/a.jpg'), [jpg]);
    again = M.markPending(again, [{ path: '/p/a.jpg', target: 'png' }], 3);
    const old = { id: 'c0', path: '/p/a.jpg', to: 'png', state: 'queued' };
    assert.strictEqual(M.attachJobs(again, [old], 1).find(r => r.path === '/p/a.jpg').job.state, 'pending');
});

test('the raise token is unique and finds only its window', () => {
    const a = M.raiseToken('yozakura', 5);
    assert.ok(a.indexOf('yozakura-converter-5-') === 0);
    const clients = [{ title: 'Converter', address: 'x' }, { title: a, address: 'y' }];
    assert.strictEqual(M.windowTitled(clients, a).address, 'y');
    assert.strictEqual(M.windowTitled(clients, ''), null);
    assert.strictEqual(M.windowTitled(null, a), null);
});
