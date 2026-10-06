const { test } = require('node:test');
const assert = require('node:assert/strict');
const path = require('node:path');
const { loadLibrary: loadQmlJs } = require('./lib/qmljs.cjs');

const loadLibrary = file => loadQmlJs(path.join(__dirname, file));

const plain = value => JSON.parse(JSON.stringify(value));
const Model = loadLibrary('../modules/services/activities/ActivityModel.js');
const Progress = loadLibrary('../modules/services/activities/NotificationProgress.js');
const Privacy = loadLibrary('../modules/services/activities/PrivacyDetect.js');
const Layout = loadLibrary('../modules/bar/activities/ActivityLayout.js');
const notchDefaults = plain(loadLibrary('../config/defaults/notch.js').data);
const validator = loadLibrary('../config/ConfigValidator.js');

// ── config ──────────────────────────────────────────────────────────────

test('defaults in notch.js match ActivityModel.DEFAULT_CONFIG', () => {
    assert.deepEqual(plain(Model.DEFAULT_CONFIG), notchDefaults.liveActivities);
});

test('normalizeConfig fills gaps and clamps maxVisible', () => {
    assert.deepEqual(plain(Model.normalizeConfig(undefined)), notchDefaults.liveActivities);
    const cfg = plain(Model.normalizeConfig({ enabled: false, maxVisible: 40, sources: { privacy: false } }));
    assert.equal(cfg.enabled, false);
    assert.equal(cfg.maxVisible, 8);
    assert.equal(cfg.sources.privacy, false);
    assert.equal(cfg.sources.recording, true);
    assert.equal(Model.normalizeConfig({ maxVisible: 'x' }).maxVisible, 4);
});

test('presentation: notch default, invalid falls back, off disables sources', () => {
    assert.equal(Model.normalizeConfig({}).presentation, 'notch');
    assert.equal(Model.normalizeConfig({ presentation: 'islands' }).presentation, 'islands');
    assert.equal(Model.normalizeConfig({ presentation: 'bogus' }).presentation, 'notch');
    assert.equal(Model.sourceEnabled({ presentation: 'off' }, 'recording'), false);
    assert.equal(validator.validate({ liveActivities: { presentation: 'bogus' } }, notchDefaults).liveActivities.presentation, 'notch');
    assert.equal(validator.validate({ liveActivities: { presentation: 'off' } }, notchDefaults).liveActivities.presentation, 'off');
});

test('downloads options keep endpoints/secrets as strings with defaults', () => {
    const d = plain(Model.normalizeConfig({ downloads: { aggregate: false, endpoints: { aria2: 'http://h:1/jsonrpc', extra: 5 } } }).downloads);
    assert.equal(d.aggregate, false);
    assert.equal(d.showSpeed, true);
    assert.equal(d.endpoints.aria2, 'http://h:1/jsonrpc');
    assert.equal(d.endpoints.qbittorrent, 'http://127.0.0.1:8080');
    assert.equal(d.endpoints.extra, '5');
    assert.equal(d.secrets.deluge, 'deluge');
});

test('sourceEnabled follows the master switch and per-source toggles', () => {
    assert.equal(Model.sourceEnabled(undefined, 'recording'), true);
    assert.equal(Model.sourceEnabled({ enabled: false }, 'recording'), false);
    assert.equal(Model.sourceEnabled({ sources: { timers: false } }, 'timers'), false);
    // third-party providers without a config key default to on
    assert.equal(Model.sourceEnabled({ sources: {} }, 'weatherAlerts'), true);
    assert.equal(Model.sourceEnabled({ sources: { weatherAlerts: false } }, 'weatherAlerts'), false);
});

test('validator clamps activities.maxVisible and keeps nested sources', () => {
    const out = validator.validate({ liveActivities: { maxVisible: 99, sources: { privacy: false } } }, notchDefaults);
    assert.equal(out.liveActivities.maxVisible, 8);
    assert.equal(out.liveActivities.sources.privacy, false);
    assert.equal(out.liveActivities.sources.recording, true);
    assert.equal(validator.validate({ liveActivities: { maxVisible: 0 } }, notchDefaults).liveActivities.maxVisible, 1);
});

// ── aggregation ─────────────────────────────────────────────────────────

test('aggregate sorts by priority then start time and drops invalid items', () => {
    const out = Model.aggregate([
        { source: 'timers', activities: [{ id: 't', priority: 50, startedAt: 5 }] },
        { source: 'privacy', activities: [{ id: 'mic', priority: 70, startedAt: 9 }, { id: 'cam', priority: 70, startedAt: 3 }, null, { label: 'no id' }] },
        { source: 'recording', activities: [{ id: 'rec', priority: 100, startedAt: 10 }] }
    ]);
    assert.deepEqual(plain(out.map(a => a.id)), ['rec', 'cam', 'mic', 't']);
    assert.equal(out[0].source, 'recording');
    assert.equal(out[3].progress, -1);
    assert.equal(out[3].category, 'task');
});

test('aggregate de-duplicates by id and by dedupKey (best one wins)', () => {
    const out = Model.aggregate([
        [{ id: 'a', priority: 10 }, { id: 'a', priority: 99 }],
        [{ id: 'x', priority: 30, dedupKey: 'capture:obs' }, { id: 'y', priority: 90, dedupKey: 'capture:obs' }]
    ]);
    assert.deepEqual(plain(out.map(a => [a.id, a.priority])), [['a', 99], ['y', 90]]);
});

test('aggregate accepts array-likes from JsonAdapter / QVariantList', () => {
    const listLike = { length: 1, 0: { id: 'q', priority: 1 } };
    assert.equal(Model.aggregate([{ source: 's', activities: listLike }]).length, 1);
});

test('progress is clamped to 0..1, negative means none', () => {
    const [a, b, c] = Model.aggregate([[{ id: 'a', progress: 3, priority: 3 }, { id: 'b', progress: -5, priority: 2 }, { id: 'c', progress: 0.25, priority: 1 }]]);
    assert.equal(a.progress, 1);
    assert.equal(b.progress, -1);
    assert.equal(c.progress, 0.25);
});

test('signature changes only with visible fields', () => {
    const base = Model.aggregate([[{ id: 'a', label: '00:01', startedAt: 1 }]]);
    const later = Model.aggregate([[{ id: 'a', label: '00:01', startedAt: 2 }]]);
    const ticked = Model.aggregate([[{ id: 'a', label: '00:02', startedAt: 1 }]]);
    assert.equal(Model.signature(base), Model.signature(later));
    assert.notEqual(Model.signature(base), Model.signature(ticked));
});

test('formatDuration', () => {
    assert.equal(Model.formatDuration(0), '00:00');
    assert.equal(Model.formatDuration(75), '01:15');
    assert.equal(Model.formatDuration(3725), '1:02:05');
});

// ── notification progress ───────────────────────────────────────────────

test('parseValue reads the value hint in any numeric form', () => {
    assert.equal(Progress.parseValue({ value: 42 }), 42);
    assert.equal(Progress.parseValue({ value: '7' }), 7);
    assert.equal(Progress.parseValue({ value: 150 }), 100);
    assert.equal(Progress.parseValue({ value: -3 }), 0);
    assert.equal(Progress.parseValue({}), null);
    assert.equal(Progress.parseValue({ value: 'abc' }), null);
    assert.equal(Progress.parseValue({ value: true }), null);
    assert.equal(Progress.parseValue(null), null);
});

test('parse keys synchronous updates per app+tag and skips OSD tags', () => {
    const a = Progress.parse({ id: 4, appName: 'curl', summary: 'Downloading', hints: { value: 10, 'x-canonical-private-synchronous': 'dl' } });
    assert.equal(a.key, 'sync:curl:dl');
    assert.equal(a.synchronous, true);
    const b = Progress.parse({ id: 5, appName: 'curl', hints: { value: 10, synchronous: 'dl' } });
    assert.equal(b.key, 'sync:curl:dl');
    const plainJob = Progress.parse({ id: 9, appName: 'Dolphin', hints: { value: 50 } });
    assert.equal(plainJob.key, 'id:9');
    assert.equal(Progress.parse({ id: 6, appName: 'pamixer', hints: { value: 40, 'x-canonical-private-synchronous': 'volume' } }), null);
    assert.equal(Progress.parse({ id: 7, appName: 'x', hints: { 'x-canonical-private-synchronous': 'dl' } }), null);
});

test('reduce keeps jobs until done + hold, then hides them', () => {
    const job = v => ({ key: 'id:1', value: v, synchronous: false });
    let r = Progress.reduce({}, [job(10)], 0);
    assert.equal(r.visible.length, 1);
    r = Progress.reduce(r.state, [job(100)], 1000);
    assert.equal(r.visible.length, 1, 'finished job lingers');
    r = Progress.reduce(r.state, [job(100)], 1000 + Progress.COMPLETE_HOLD_MS + 1);
    assert.equal(r.visible.length, 0, 'then disappears');
    assert.equal(Progress.needsTick(r.state, 1000 + Progress.COMPLETE_HOLD_MS + 1), true, 'stale timer still pending');
});

test('re-sent synchronous notifications: the newest one wins', () => {
    const e = (id, value) => ({ key: 'sync:Firefox:dl', id, value, synchronous: true });
    const r = Progress.reduce({}, [e(3, 15), e(4, 45), e(5, 75)], 0);
    assert.equal(r.visible.length, 1);
    assert.equal(r.visible[0].value, 75);
    assert.equal(r.visible[0].id, 5);
    const r2 = Progress.reduce({}, [e(9, 90), e(4, 45)], 0);
    assert.equal(r2.visible[0].value, 90, 'order of the tracked list does not matter');
});

test('reduce drops closed notifications and stale jobs', () => {
    let r = Progress.reduce({}, [{ key: 'a', value: 5, synchronous: true }], 0);
    r = Progress.reduce(r.state, [{ key: 'a', value: 5, synchronous: true }], Progress.SYNC_STALE_MS + 1);
    assert.equal(r.visible.length, 0, 'synchronous job that stopped updating expires');
    r = Progress.reduce(r.state, [], Progress.SYNC_STALE_MS + 2);
    assert.deepEqual(plain(r.state), {}, 'closed notification forgotten');
    r = Progress.reduce({}, [{ key: 'b', value: 5 }], 0);
    r = Progress.reduce(r.state, [{ key: 'b', value: 6 }], Progress.STALE_MS - 1);
    r = Progress.reduce(r.state, [{ key: 'b', value: 6 }], Progress.STALE_MS + 10);
    assert.equal(r.visible.length, 1, 'updates refresh the stale clock');
    assert.equal(Progress.needsTick({}, 0), false);
});

// ── privacy ─────────────────────────────────────────────────────────────

const nodes = [
    { id: 93, mediaClass: 'Audio/Source', nodeName: 'alsa_input.usb-mic' },
    { id: 34, mediaClass: 'Audio/Source/Virtual', nodeName: 'easyeffects_source' },
    { id: 94, mediaClass: 'Audio/Sink', nodeName: 'alsa_output.headset' },
    { id: 185, mediaClass: 'Stream/Input/Audio', nodeName: 'cava', captureSink: true },
    { id: 200, mediaClass: 'Stream/Input/Audio', appName: 'Firefox', binary: 'firefox' },
    { id: 201, mediaClass: 'Stream/Input/Audio', appName: 'WEBRTC VoiceEngine', binary: 'discord' },
    { id: 300, mediaClass: 'Video/Source', nodeName: 'v4l2_input.pci-cam', deviceApi: 'v4l2' },
    { id: 301, mediaClass: 'Stream/Input/Video', appName: 'Zoom', binary: 'zoom' },
    { id: 400, mediaClass: 'Video/Source', nodeName: 'xdph-streaming-1' },
    { id: 401, mediaClass: 'Stream/Input/Video', appName: 'OBS', binary: 'obs' },
    { id: 402, mediaClass: 'Stream/Input/Video', binary: 'gpu-screen-recorder' },
    { id: 500, mediaClass: 'Stream/Input/Audio', appName: 'PulseAudio Volume Control', binary: 'pavucontrol' }
];

test('monitor capture (cava) is not microphone use', () => {
    assert.deepEqual(plain(Privacy.detect(nodes, [{ source: 94, target: 185, active: true }])), []);
});

test('detect mic, camera and screen sharing with app names', () => {
    const links = [
        { source: 93, target: 200, active: true },
        { source: 34, target: 201, active: true },
        { source: 300, target: 301, active: true },
        { source: 400, target: 401, active: true },
        { source: 93, target: 500, active: true }
    ];
    const out = plain(Privacy.detect(nodes, links));
    assert.deepEqual(out.map(d => d.kind), ['screen', 'camera', 'mic']);
    assert.deepEqual(out[0].apps, ['OBS']);
    assert.deepEqual(out[1].apps, ['Zoom']);
    assert.deepEqual(out[2].apps, ['Firefox', 'Discord'], 'generic WebRTC names fall back to the binary; mixers ignored');
});

test('paused links and excluded recorders are ignored', () => {
    assert.deepEqual(plain(Privacy.detect(nodes, [{ source: 93, target: 200, active: false }])), []);
    const links = [{ source: 400, target: 402, active: true }];
    assert.equal(Privacy.detect(nodes, links).length, 1);
    assert.equal(Privacy.detect(nodes, links, { excludeScreen: ['gpu-screen-recorder'] }).length, 0);
});

test('camera users from /dev/video* are merged and filtered', () => {
    const users = Privacy.parseCameraUsers('123 chromium\n124 chromium\n55 pipewire\n--');
    assert.deepEqual(plain(users), ['chromium', 'pipewire', '--']);
    const out = plain(Privacy.detect(nodes, [], { cameraUsers: ['chromium', 'pipewire'] }));
    assert.deepEqual(out, [{ kind: 'camera', apps: ['Chromium'], streams: [] }]);
    assert.equal(Privacy.appsLabel(['A', 'B', 'C']), 'A +2');
    assert.equal(Privacy.appsLabel([]), '');
});

// ── layout ──────────────────────────────────────────────────────────────

test('placement follows bar style, bar edge and notch theme', () => {
    const p = o => plain(Layout.placement(Object.assign({ barEnabled: true, barPosition: 'top', notchPosition: 'top', notchTheme: 'default', barStyle: 'islands' }, o)));
    assert.equal(p({}).mode, 'tab');
    assert.equal(p({ barStyle: 'classic' }).mode, 'pill');
    assert.equal(p({ barStyle: 'classic', notchTheme: 'island' }).mode, 'pill');
    assert.equal(p({ notchTheme: 'island' }).mode, 'floating');
    assert.equal(p({ barPosition: 'left', barStyle: 'classic' }).mode, 'tab', 'vertical bars leave the notch edge free');
    assert.equal(p({ barPosition: 'top', notchPosition: 'bottom', barStyle: 'classic' }).edge, 'bottom');
    assert.equal(p({ barEnabled: false, barStyle: 'classic' }).mode, 'tab');
});

const items = (...specs) => specs.map(([id, category, width]) => ({ id, category, width }));

test('privacy goes right, tasks left, nearest the notch first', () => {
    const r = plain(Layout.distribute(items(['rec', 'privacy', 80], ['mic', 'privacy', 90], ['timer', 'task', 70]), { leftSpace: 500, rightSpace: 500, spacing: 6, maxVisible: 4, overflowWidth: 40 }));
    assert.deepEqual(r, { left: ['timer'], right: ['rec', 'mic'], overflow: null });
});

test('a full side spills to the other before overflowing', () => {
    const r = plain(Layout.distribute(items(['a', 'privacy', 100], ['b', 'privacy', 100]), { leftSpace: 300, rightSpace: 150, spacing: 6, maxVisible: 4, overflowWidth: 40 }));
    assert.deepEqual(r, { left: ['b'], right: ['a'], overflow: null });
});

test('more than maxVisible collapses the rest into +N', () => {
    const list = items(['a', 'privacy', 50], ['b', 'privacy', 50], ['c', 'task', 50], ['d', 'task', 50], ['e', 'task', 50], ['f', 'task', 50]);
    const r = plain(Layout.distribute(list, { leftSpace: 1000, rightSpace: 1000, spacing: 4, maxVisible: 4, overflowWidth: 40 }));
    assert.deepEqual(r.left, ['c', 'd']);
    assert.deepEqual(r.right, ['a', 'b']);
    assert.deepEqual(r.overflow.ids, ['e', 'f']);
});

test('no room for +N drops the lowest-priority island into it', () => {
    const list = items(['a', 'privacy', 100], ['b', 'task', 100], ['c', 'task', 100]);
    const r = plain(Layout.distribute(list, { leftSpace: 100, rightSpace: 100, spacing: 4, maxVisible: 4, overflowWidth: 40 }));
    assert.deepEqual(r.right, ['a']);
    assert.deepEqual(r.left, []);
    assert.deepEqual(r.overflow, { side: 'left', ids: ['b', 'c'] });
});

test('nothing fits at all renders nothing', () => {
    const r = plain(Layout.distribute(items(['a', 'privacy', 100]), { leftSpace: 10, rightSpace: 10, spacing: 4, maxVisible: 4, overflowWidth: 40 }));
    assert.deepEqual(r, { left: [], right: [], overflow: null });
});

test('positions stack outward from the notch', () => {
    const res = { left: ['t1', 't2'], right: ['p1'], overflow: { side: 'right', ids: ['x'] } };
    const pos = plain(Layout.positions(res, { t1: 50, t2: 30, p1: 40 }, 1000, 1400, 8, 6, 20));
    assert.deepEqual(pos, { t1: 942, t2: 906, p1: 1408, __overflow: 1454 });
});
