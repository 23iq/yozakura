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
