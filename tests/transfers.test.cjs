const { test } = require('node:test');
const assert = require('node:assert/strict');
const fs = require('node:fs');
const vm = require('node:vm');
const path = require('node:path');

function loadLibrary(file) {
    const ctx = {};
    vm.runInNewContext(fs.readFileSync(path.join(__dirname, file), 'utf8').replace(/^\.pragma library\s*/, ''), ctx);
    return ctx;
}

const plain = value => JSON.parse(JSON.stringify(value));
const T = loadLibrary('../modules/services/activities/TransferModel.js');
const MB = 1024 * 1024;

const tr = (o) => Object.assign({ processed: -1, total: -1, rate: -1, state: 'running', kind: 'download', startedAt: 1 }, o);

test('formatBytes / formatRate / formatSizes / formatPercent', () => {
    assert.equal(T.formatBytes(0), '0 B');
    assert.equal(T.formatBytes(1023), '1023 B');
    assert.equal(T.formatBytes(1536), '1.5 KB');
    assert.equal(T.formatBytes(340 * MB), '340 MB');
    assert.equal(T.formatBytes(1.25 * 1024 * MB), '1.3 GB');
    assert.equal(T.formatBytes(-1), '');
    assert.equal(T.formatRate(2.5 * MB), '2.5 MB/s');
    assert.equal(T.formatRate(-1), '');
    assert.equal(T.formatSizes(340 * MB, 720 * MB), '340 MB / 720 MB');
    assert.equal(T.formatSizes(340 * MB, -1), '340 MB');
    assert.equal(T.formatSizes(-1, -1), '');
    assert.equal(T.formatPercent(0.474), '47%');
    assert.equal(T.formatPercent(-1), '');
});

test('formatEta', () => {
    assert.equal(T.formatEta(9), '9s');
    assert.equal(T.formatEta(75), '1m 15s');
    assert.equal(T.formatEta(3725), '1h 2m');
    assert.equal(T.formatEta(3 * 86400 + 7200), '3d 2h');
    assert.equal(T.formatEta(-1), '');
});

test('elideMiddle keeps both ends', () => {
    assert.equal(T.elideMiddle('short.iso', 20), 'short.iso');
    const e = T.elideMiddle('archlinux-2026.10.01-x86_64.iso', 16);
    assert.equal(e.length, 16);
    assert.ok(e.startsWith('archlin') && e.endsWith('x86_64.iso'.slice(-8)), e);
});

test('progress and eta per transfer', () => {
    assert.equal(T.progress(tr({ processed: 50, total: 200 })), 0.25);
    assert.equal(T.progress(tr({ processed: 50 })), -1);
    assert.equal(T.progress(tr({ state: 'done' })), 1);
    assert.equal(T.eta(tr({ processed: 100 * MB, total: 200 * MB, rate: 10 * MB })), 10);
    assert.equal(T.eta(tr({ processed: 1, total: 2, rate: 1, state: 'paused' })), -1);
});

test('dedupe: Firefox .part + progress notification are one download', () => {
    const list = T.dedupe([
        tr({ id: 'browserDownloads:a', source: 'browserDownloads', app: 'Firefox', title: 'ubuntu.iso', path: '/home/u/Downloads/ubuntu.iso.part', processed: 10 * MB, rate: MB }),
        tr({ id: 'notificationProgress:sync:Firefox:dl', source: 'notificationProgress', app: 'Firefox', title: 'ubuntu.iso', detail: 'Downloading', processed: 30, total: 100 })
    ]);
    assert.equal(list.length, 1);
    assert.equal(list[0].source, 'browserDownloads', 'the richer source wins');
});

test('dedupe: notification mentioning the file name in its text', () => {
    const list = T.dedupe([
        tr({ id: 'notificationProgress:1', source: 'notificationProgress', title: 'Copying', detail: 'Copying holiday-photos.tar to /mnt', processed: 1, total: 4 }),
        tr({ id: 'fileOps:9', source: 'fileOps', title: 'holiday-photos.tar', kind: 'copy', processed: 1, total: 4 })
    ]);
    assert.equal(list.length, 1);
    assert.equal(list[0].source, 'fileOps');
});

test('dedupe keeps different files, drops invalid entries and sorts by start', () => {
    const list = T.dedupe([
        tr({ id: 'terminal:2', source: 'terminal', title: 'b.tar', startedAt: 5 }),
        tr({ id: 'terminal:1', source: 'terminal', title: 'a.tar', startedAt: 2 }),
        null,
        { title: 'no id' },
        tr({ id: 'terminal:1', source: 'terminal', title: 'a.tar', startedAt: 2 })
    ]);
    assert.deepEqual(plain(list.map(t => t.id)), ['terminal:1', 'terminal:2']);
});

test('dedupe: crdownload/opdownload suffixes match the final name', () => {
    assert.equal(T.fileKey({ path: '/d/Setup.EXE.crdownload' }), 'setup.exe');
    assert.equal(T.fileKey({ title: 'video.mp4.part' }), 'video.mp4');
    assert.equal(T.fileKey({ path: '/d/x.zip.opdownload' }), 'x.zip');
});

test('summarize: bytes-weighted progress, summed rate, eta', () => {
    const s = T.summarize([
        tr({ processed: 100 * MB, total: 400 * MB, rate: 2 * MB }),
        tr({ processed: 300 * MB, total: 400 * MB, rate: 2 * MB })
    ]);
    assert.equal(s.count, 2);
    assert.equal(s.active, 2);
    assert.equal(s.progress, 0.5);
    assert.equal(s.rate, 4 * MB);
    assert.equal(s.eta, 100);
    assert.equal(s.indeterminate, false);
});

test('summarize: unknown totals fall back to the mean of known progress', () => {
    const s = T.summarize([tr({ processed: 50, total: 100 }), tr({ processed: 10 })]);
    assert.equal(s.progress, 0.5);
    assert.equal(s.eta, -1);
    const none = T.summarize([tr({ processed: 10 })]);
    assert.equal(none.progress, -1);
    assert.equal(none.indeterminate, true);
});

test('summarize: states and finished items', () => {
    assert.equal(T.summarize([tr({ state: 'paused' }), tr({ state: 'failed' })]).state, 'failed');
    const done = T.summarize([tr({ state: 'done', processed: 5, total: 5 })]);
    assert.equal(done.active, 0);
    assert.equal(done.progress, 1);
    assert.equal(done.state, 'done');
    assert.equal(T.summarize([]).progress, -1);
});

test('percent units: never shown as bytes, not mixed into byte totals', () => {
    const items = T.dedupe([
        tr({ id: 'notificationProgress:a', source: 'notificationProgress', title: 'a.zip', processed: 50, total: 100, units: 'percent' }),
        tr({ id: 'terminal:b', source: 'terminal', title: 'b.iso', processed: 100 * MB, total: 400 * MB })
    ]);
    assert.equal(T.formatTransferSizes(items.find(t => t.units === 'percent')), '');
    assert.equal(T.formatTransferSizes(items.find(t => t.units === 'bytes')), '100 MB / 400 MB');
    const s = T.summarize(items);
    assert.equal(s.total, 400 * MB, 'percent item excluded from byte sums');
    assert.equal(s.progress, (0.5 + 0.25) / 2, 'mixed units fall back to the mean');
});

test('toActivities: one aggregated island, or one per transfer', () => {
    const items = T.dedupe([
        tr({ id: 'a:1', source: 'terminal', title: 'a.iso', processed: 100 * MB, total: 400 * MB, startedAt: 1 }),
        tr({ id: 'b:1', source: 'steam', title: 'Game', processed: 300 * MB, total: 400 * MB, startedAt: 2 })
    ]);
    const agg = plain(T.toActivities(items, { aggregate: true, icon: 'D', title: 'Downloads' }));
    assert.equal(agg.length, 1);
    assert.equal(agg[0].id, 'downloads');
    assert.equal(agg[0].label, '2 · 50%');
    assert.equal(agg[0].progress, 0.5);
    const each = plain(T.toActivities(items, { aggregate: false }));
    assert.deepEqual(each.map(a => a.label), ['25%', '75%']);
    const single = plain(T.toActivities([items[0]], { aggregate: true }));
    assert.equal(single[0].id, 'downloads', 'a single download keeps the stable id');
    assert.equal(single[0].label, '25%');
    const indet = plain(T.toActivities(T.dedupe([tr({ id: 'p:1', source: 'packages', title: 'Updating system' })]), { aggregate: true }));
    assert.equal(indet[0].progress, -1);
    assert.equal(T.toActivities([], {}).length, 0);
    const failed = plain(T.toActivities(T.dedupe([tr({ id: 'f:1', title: 'x', state: 'failed' })]), { aggregate: true }));
    assert.equal(failed[0].color, 'error');
});

test('indeterminate downloads show bytes and speed in the collapsed label', () => {
    const one = plain(T.toActivities(T.dedupe([tr({ id: 'b:1', source: 'browserDownloads', title: 'x.bin', processed: 38 * MB, rate: 4.2 * MB })]), { aggregate: true }));
    assert.equal(one[0].label, '38 MB · 4.2 MB/s');
    const noRate = plain(T.toActivities(T.dedupe([tr({ id: 'b:1', title: 'x.bin', processed: 38 * MB })]), { aggregate: true }));
    assert.equal(noRate[0].label, '38 MB');
    const paused = plain(T.toActivities(T.dedupe([tr({ id: 'b:1', title: 'x.bin', processed: 38 * MB, rate: 2 * MB, state: 'paused' })]), { aggregate: true }));
    assert.equal(paused[0].label, '38 MB', 'no speed while stalled');
    const nothing = plain(T.toActivities(T.dedupe([tr({ id: 'p:1', title: 'Updating system' })]), { aggregate: true }));
    assert.equal(nothing[0].label, 'Updati… system', 'no bytes: elided title');
    const two = T.dedupe([
        tr({ id: 'b:1', title: 'a.bin', processed: 38 * MB, rate: 4.2 * MB }),
        tr({ id: 't:1', title: 'b.tar', processed: 38 * MB, rate: 3.1 * MB })
    ]);
    assert.equal(plain(T.toActivities(two, { aggregate: true }))[0].label, '2 · 7.3 MB/s');
    const twoNoRate = T.dedupe([tr({ id: 'b:1', title: 'a.bin', processed: 40 * MB }), tr({ id: 't:1', title: 'b.tar', processed: 36 * MB })]);
    assert.equal(plain(T.toActivities(twoNoRate, { aggregate: true }))[0].label, '2 · 76 MB');
});
