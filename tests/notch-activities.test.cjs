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
const N = loadLibrary('../modules/widgets/defaultview/activities/NotchActivities.js');
const T = loadLibrary('../modules/services/activities/TransferModel.js');

const act = (id, o) => Object.assign({ id, source: 'x', indicator: 'glyph', label: '', detail: '' }, o);

test('segment: top item plus a badge for the rest', () => {
    assert.equal(N.segment([], 'leading'), null);
    const s = plain(N.segment([act('downloads', { indicator: 'ring' }), act('timer:0', { indicator: 'ring' }), act('t2')], 'leading'));
    assert.equal(s.item.id, 'downloads');
    assert.deepEqual(s.extras, []);
    assert.equal(s.badge, 2);
});

test('segment: trailing shows up to 3 privacy kinds as glyphs before badging', () => {
    const list = [act('recording', { indicator: 'dot' }), act('privacy:screen'), act('privacy:camera'), act('privacy:mic')];
    const s = plain(N.segment(list, 'trailing', 3));
    assert.equal(s.item.id, 'recording');
    assert.deepEqual(s.extras.map(a => a.id), ['privacy:screen', 'privacy:camera']);
    assert.equal(s.badge, 1);
    assert.equal(plain(N.segment(list.slice(1), 'trailing', 3)).badge, 0);
});

test('hasLabel: glyph privacy items are icon-only', () => {
    assert.equal(N.hasLabel(act('m')), false);
    assert.equal(N.hasLabel(act('r', { indicator: 'dot', label: '02:13' })), true);
    assert.equal(N.hasLabel(act('d', { indicator: 'ring', label: '' })), false);
});

test('widthTemplate is stable while numbers tick', () => {
    assert.equal(N.widthTemplate('18:42'), N.widthTemplate('00:07'));
    assert.equal(N.widthTemplate('5%'), N.widthTemplate('100%'));
    assert.equal(N.widthTemplate('2 · 47%'), '0 · 000%');
    assert.equal(N.widthTemplate('1:02:05'), '0:00:00');
    assert.equal(N.widthTemplate('✓'), '✓');
});

test('activityText per source', () => {
    const labels = { recording: 'Screen Recording' };
    assert.deepEqual(plain(N.activityText(act('recording', { source: 'recording', label: '02:13', detail: 'Click to stop' }), labels)), { primary: 'Screen Recording', secondary: '02:13' });
    assert.deepEqual(plain(N.activityText(act('timer:0', { source: 'timers', label: '18:42', detail: 'Focus' }), labels)), { primary: 'Focus', secondary: '18:42' });
    assert.deepEqual(plain(N.activityText(act('privacy:mic', { source: 'privacy', label: 'Firefox +1', detail: 'Microphone · Firefox, Discord' }), labels)), { primary: 'Microphone', secondary: 'Firefox, Discord' });
});

test('rows: activities first, transfers grouped by source with headers', () => {
    const r = plain(N.rows(
        [act('recording', { source: 'recording' }), act('downloads', { source: 'downloads' }), act('timer:0', { source: 'timers' })],
        [
            { id: 'steam:1', source: 'steam', app: 'Steam' },
            { id: 'browserDownloads:a', source: 'browserDownloads', app: 'Firefox' },
            { id: 'steam:2', source: 'steam', app: 'Steam' },
            { id: 'browserDownloads:b', source: 'browserDownloads', app: 'Chromium' }
        ]));
    assert.deepEqual(r.map(x => x.key), ['a:recording', 'a:timer:0', 'h:steam', 't:steam:1', 't:steam:2', 'h:browserDownloads', 't:browserDownloads:a', 't:browserDownloads:b']);
    assert.equal(r[2].label, 'Steam');
    assert.equal(r[2].count, 2);
    assert.equal(r[5].label, 'Firefox · Chromium');
    assert.equal(N.keys(N.rows([], [])), '');
});

test('transferStatus: sizes, speed, eta and states', () => {
    const MB = 1024 * 1024;
    const base = { processed: 340 * MB, total: 720 * MB, rate: 2 * MB, state: 'running', units: 'bytes' };
    const labels = { left: 'left', paused: 'Paused', queued: 'Queued', failed: 'Failed', done: 'Done' };
    const run = plain(N.transferStatus(base, T, true, labels));
    assert.equal(run.left, '340 MB / 720 MB · 2.0 MB/s');
    assert.equal(run.right, '3m 10s left');
    assert.equal(plain(N.transferStatus(base, T, false, labels)).left, '340 MB / 720 MB');
    assert.deepEqual(plain(N.transferStatus(Object.assign({}, base, { state: 'failed' }), T, true, labels)), { left: '340 MB / 720 MB', right: 'Failed', tone: 'error' });
    assert.equal(plain(N.transferStatus(Object.assign({}, base, { state: 'done' }), T, true, labels)).tone, 'done');
    const pct = plain(N.transferStatus({ processed: 42, total: 100, rate: -1, state: 'running', units: 'percent' }, T, true, labels));
    assert.equal(pct.left, '42%');
    assert.equal(pct.right, '');
    const unknown = plain(N.transferStatus({ processed: -1, total: -1, rate: -1, state: 'running', units: 'bytes', detail: 'Updating system' }, T, true, labels));
    assert.equal(unknown.left, 'Updating system');
});
