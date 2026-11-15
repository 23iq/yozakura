// Live previews (modules/components/preview, modules/settings/live): the
// override lens real shell parts read, and the settings-side helpers.
const { test } = require('node:test');
const assert = require('node:assert/strict');
const path = require('node:path');

const qmljs = require('./lib/qmljs.cjs');
const lib = file => qmljs.loadLibrary(path.join(__dirname, '..', file));
const plain = v => JSON.parse(JSON.stringify(v));

const Preview = lib('modules/components/preview/Preview.js');
const Keys = lib('modules/settings/live/LiveKeys.js');
const Patch = lib('modules/settings/live/LivePatch.js');
const Modules = lib('modules/bar/BarModuleRegistry.js');

test('pick: the live value unless the preview overrides the key', () => {
    assert.equal(Preview.pick(null, 'workspaces.indicatorStyle', 'pill'), 'pill');
    assert.equal(Preview.pick(undefined, 'a', 1), 1);
    const ctx = { overrides: { 'workspaces.indicatorStyle': 'branch', 'dock.enabled': false } };
    assert.equal(Preview.pick(ctx, 'workspaces.indicatorStyle', 'pill'), 'branch');
    // a falsy override still wins
    assert.equal(Preview.pick(ctx, 'dock.enabled', true), false);
    assert.equal(Preview.pick(ctx, 'workspaces.numeralStyle', 'arabic'), 'arabic');
    assert.equal(Preview.pick({}, 'x', 3), 3);
});

test('sample: the context\'s data for a key, else the live value', () => {
    assert.equal(Preview.sample(null, 'launcher.query', 'live'), 'live');
    const ctx = { overrides: { 'launcher.query': 'no' }, samples: { 'launcher.query': 'fi', 'dashboard.tab': 0 } };
    assert.equal(Preview.sample(ctx, 'launcher.query', ''), 'fi');
    // a falsy sample still wins; overrides are not samples
    assert.equal(Preview.sample(ctx, 'dashboard.tab', 2), 0);
    assert.equal(Preview.sample({ overrides: { a: 1 } }, 'a', 5), 5);
    assert.equal(Preview.sample({}, 'x', 3), 3);
});

test('on: a part is a preview when it has a context', () => {
    assert.equal(Preview.on(null), false);
    assert.equal(Preview.on(undefined), false);
    assert.equal(Preview.on({ overrides: {} }), true);
});

test('sample: the context\'s sample, else the live service value', () => {
    const live = { trackTitle: 'live' };
    assert.equal(Preview.sample(null, 'player', live), live);
    assert.equal(Preview.sample({ overrides: {} }, 'player', live), live);
    const track = { trackTitle: 'Hanami Night' };
    const ctx = { samples: { player: track, notifications: [], activities: null } };
    assert.equal(Preview.sample(ctx, 'player', live), track);
    // "none" is a sample too: an empty list or null wins over the session
    assert.deepEqual(Preview.sample(ctx, 'notifications', [{ id: 1 }]), []);
    assert.equal(Preview.sample(ctx, 'activities', [{ id: 1 }]), null);
    assert.equal(Preview.sample(ctx, 'levels', 7), 7);
});

test('withValue copies the overrides with one more key', () => {
    const base = { a: 1 };
    const out = Preview.withValue(base, 'b', 2);
    assert.deepEqual(plain(out), { a: 1, b: 2 });
    assert.deepEqual(base, { a: 1 });
    assert.deepEqual(plain(Preview.withValue(null, 'k', 'v')), { k: 'v' });
});

test('every bar module has spot keys and a card (a new one needs nothing)', () => {
    for (const id of Modules.ids()) {
        const keys = Keys.moduleKeys(id);
        assert.ok(Array.isArray(keys) && keys.length > 0, id);
        assert.ok(['clock', 'workspaces', 'layout'].includes(Keys.sectionOf(id)), id);
    }
    assert.deepEqual(plain(Keys.moduleKeys('weather')), ['bar.moduleOptions.weather']);
    assert.equal(Keys.sectionOf('clock'), 'clock');
    assert.equal(Keys.sectionOf('workspaces'), 'workspaces');
    assert.equal(Keys.sectionOf('systray'), 'layout');
});

test('only: a bar holding just these modules', () => {
    const p = plain(Patch.only('workspaces'));
    assert.deepEqual(p.groups.start, ['workspaces']);
    for (const g of ['center', 'end', 'drawer', 'gapStart', 'gapEnd'])
        assert.deepEqual(p.groups[g], [], g);
    assert.deepEqual(plain(Patch.only(['launcher', 'clock'])).groups.start, ['launcher', 'clock']);
});

test('sample: a few of your modules, each in its group', () => {
    const p = plain(Patch.sample({
        start: ['launcher', '__sep__', 'workspaces', 'pin'],
        center: ['clock', 'media'],
        end: ['systray', 'battery', 'power']
    }));
    assert.deepEqual(p.groups.start, ['launcher', 'workspaces']);
    assert.deepEqual(p.groups.center, ['clock']);
    assert.deepEqual(p.groups.end, ['battery', 'power']);
    assert.deepEqual(plain(Patch.sample(null)).groups.start, []);
    assert.deepEqual(plain(Patch.style('islands')), { style: 'islands' });
});

const Samples = lib('modules/settings/live/LiveSamples.js');

test('island samples: one state each, nothing of the session', () => {
    const ids = plain(Samples.STATES.map(s => s.id));
    assert.deepEqual(ids, ['rest', 'media', 'notification', 'timer']);
    Samples.STATES.forEach(s => assert.match(s.label, /^prefs\.notch\.state\./));
    const timer = { id: 'timer:preview', category: 'task', indicator: 'ring', label: '16:20' };
    const rest = plain(Samples.island('rest', 1e6, '', timer));
    assert.equal(rest.player, null);
    assert.deepEqual(rest.notifications, []);
    assert.deepEqual(rest.activities, []);
    assert.equal(rest.focusedTitle, '');
    const media = plain(Samples.island('media', 1e6, 'file:///art.png', timer));
    assert.equal(media.player.trackTitle, 'Hanami Night');
    assert.equal(media.player.trackArtUrl, 'file:///art.png');
    assert.equal(media.player.isPlaying, true);
    const note = plain(Samples.island('notification', 1e6, '', timer));
    assert.equal(note.notifications.length, 1);
    assert.equal(note.notifications[0].time, 1e6 - 60000);
    const t = plain(Samples.island('timer', 1e6, '', timer));
    assert.equal(t.activities.length, 1);
    // the activity keeps the provider's shape and names its source
    assert.equal(t.activities[0].source, 'timers');
    assert.equal(t.activities[0].label, '16:20');
    assert.deepEqual(plain(Samples.island('timer', 1e6, '', null)).activities, []);
});

test('notification samples: one message, or three of the app when grouped', () => {
    assert.equal(Samples.messages(5e6, false).length, 1);
    const grouped = Samples.messages(5e6, true);
    assert.equal(grouped.length, 3);
    // the newest last, every one of the same app
    assert.ok(grouped[2].time > grouped[0].time);
    assert.ok(grouped.every(n => n.appName === 'Telegram'));
    const g = plain(Samples.group(5e6, true));
    assert.equal(g.notifications.length, 3);
    assert.equal(g.time, 5e6 - 60000);
    const all = plain(Samples.groups(5e6, false));
    assert.deepEqual(Object.keys(all).sort(), ['Calendar', 'Telegram']);
    assert.ok(all.Telegram.time > all.Calendar.time);
});

test('the OSD and timer samples', () => {
    assert.deepEqual(plain(Samples.osd()), { kind: 'volume', value: 0.62, shown: true });
    const t = plain(Samples.timer(1e6));
    assert.ok(t.leftMs < t.totalMs && t.state === 'running');
});

test('the words a sample shows are translated (English without a translator)', () => {
    const tr = k => '[' + k + ']';
    const msg = plain(Samples.messages(5e6, false, tr))[0];
    assert.equal(msg.body, '[prefs.notif.sample.dinner]');
    assert.deepEqual(msg.actions.map(a => a.text), ['[prefs.notif.sample.reply]', '[prefs.notif.sample.read]']);
    const cal = plain(Samples.groups(5e6, false, tr)).Calendar.notifications[0];
    assert.equal(cal.summary, '[prefs.notif.sample.reminder]');
    assert.equal(plain(Samples.timer(1e6, tr)).name, '[focus.timer_name]');
    assert.equal(plain(Samples.island('notification', 5e6, '', null, tr)).notifications[0].body, '[prefs.notif.sample.dinner]');
    assert.equal(plain(Samples.messages(5e6, false))[0].actions[0].text, 'Reply');
    // every key exists in every language
    const fs = require('node:fs');
    const keys = Object.keys(Samples.TEXT);
    for (const lang of ['en', 'es', 'ru']) {
        const d = JSON.parse(fs.readFileSync(path.join(__dirname, '..', 'translations', lang + '.json'), 'utf8'));
        for (const k of keys) assert.ok(k in d, `${lang}: ${k}`);
    }
});

// The dashboard on a Settings stage is open while the real one is closed:
// what it loads only while open follows the dashboard's own isVisible.
test('the dashboard preview loads its wallpaper thumbnails (isVisible, not GlobalStates)', () => {
    const fs = require('node:fs');
    const read = f => fs.readFileSync(path.join(__dirname, '..', f), 'utf8');
    assert.match(read('modules/widgets/dashboard/Dashboard.qml'), /WallpapersTab \{\s*dashboardShown: root\.isVisible/);
    const cell = read('modules/widgets/dashboard/wallpapers/WallpaperGridCell.qml');
    assert.match(cell, /cell\.tab\.dashboardShown/);
    assert.doesNotMatch(cell, /GlobalStates\.dashboardOpen/);
});
