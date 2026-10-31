// Simple / All view (modules/settings/schema/Advanced.js): `advanced: true`
// entries hide in Simple and stay in place in All; search still finds them.
// Greyed rows explain themselves (modules/settings/DisabledReason.js).
const { test } = require('node:test');
const assert = require('node:assert/strict');
const path = require('node:path');
const { loadLibrary } = require('./lib/qmljs.cjs');

const repo = path.join(__dirname, '..');
const Advanced = loadLibrary(path.join(repo, 'modules/settings/schema/Advanced.js'));
const Reason = loadLibrary(path.join(repo, 'modules/settings/DisabledReason.js'));
const SchemaUtil = loadLibrary(path.join(repo, 'modules/settings/SchemaUtil.js'));
const Categories = loadLibrary(path.join(repo, 'modules/settings/schema/Categories.js'));
const tr = lang => require(`../translations/${lang}.json`);
const en = tr('en');
const plain = v => JSON.parse(JSON.stringify(v));

const cat = () => ({
    id: 'demo', icon: 'gear', title: 'prefs.cat.bar',
    sections: [
        { id: 'main', title: 't', entries: [{ key: 'bar.a', label: 'A' }, { key: 'bar.b', label: 'B', advanced: true }] },
        { id: 'hypr', compositor: 'hyprland', entries: [{ key: 'bar.c', label: 'C', advanced: true }] },
    ],
});
const all = Categories.categories;
const entries = () => SchemaUtil.flatten(all).map(x => x.entry);

test('Simple hides advanced entries, All and a search reveal show them', () => {
    const [a, b] = cat().sections[0].entries;
    assert.equal(Advanced.shown(a, false, {}), true);
    assert.equal(Advanced.shown(b, false, {}), false);
    assert.equal(Advanced.shown(b, true, {}), true);
    assert.equal(Advanced.shown(b, false, { 'bar.b': true }), true);
});

test('entries stay in their own section (no Advanced block)', () => {
    for (const c of all)
        for (const s of c.sections || [])
            assert.notEqual(s.id, 'advanced', c.id);
    const hit = SchemaUtil.search(SchemaUtil.buildSearchIndex(all, k => en[k] || k), 'Bar reveal strip', 5).find(r => r.entryId === 'bar.hoverRegionHeight');
    assert.ok(hit, 'search finds an advanced entry');
    assert.notEqual(hit.sectionId, 'advanced');
});

test('hiddenCount counts what Simple hides, through the page filter', () => {
    assert.equal(Advanced.hiddenCount(cat(), false, {}), 2);
    assert.equal(Advanced.hiddenCount(cat(), true, {}), 0);
    assert.equal(Advanced.hiddenCount(cat(), false, { 'bar.c': true }), 1);
    assert.equal(Advanced.hiddenCount(cat(), false, {}, (e, sec) => sec.compositor !== 'hyprland'), 1);
});

test('about a hundred expert rows are advanced, essentials are not', () => {
    const n = Advanced.advancedCount(all);
    assert.ok(n >= 95 && n <= 150, `${n} advanced rows`);
    const byKey = Object.fromEntries(entries().filter(e => e.key).map(e => [e.key, e]));
    for (const k of ['theme.language', 'notifications.presentation', 'notch.disableHoverExpansion', 'dock.enabled', 'theme.glass.enabled'])
        assert.ok(!byKey[k].advanced, k);
});

test('every signature feature is one row in Simple, its fine options in All', () => {
    const byKey = Object.fromEntries(entries().filter(e => e.key).map(e => [e.key, e]));
    const features = {
        'theme.lighting.mode': ['theme.lighting.angle', 'theme.lighting.strength', 'theme.lighting.lantern'],
        'workspaces.indicatorStyle': ['workspaces.branchBlossom', 'workspaces.branchColor', 'workspaces.branchPetalFall'],
        'bar.moduleOptions.sentence.verbosity': ['bar.moduleOptions.sentence.separator', 'bar.moduleOptions.sentence.typeface', 'bar.moduleOptions.sentence.fragments', 'bar.moduleOptions.sentence.priority', 'bar.moduleOptions.sentence.maxWidth'],
        'notifications.presentation': ['notifications.strips.edge', 'notifications.strips.material', 'notifications.strips.thread', 'notifications.strips.sway', 'notifications.strips.maxVisible'],
        'theme.language': [],
        'desktop.wallpaperMode': ['desktop.panoramaParallax'],
    };
    for (const [main, fine] of Object.entries(features)) {
        assert.ok(byKey[main] && !byKey[main].advanced, main);
        for (const k of fine)
            assert.equal(byKey[k].advanced, true, k);
    }
    assert.ok(byKey['theme.language'].options.some(o => o.value === 'device'), 'Device is a choice of Visual style');
});

test('a single switch is named and offered as the fix', () => {
    const index = Reason.entryIndex(all);
    const lookup = k => index[k] || null;
    const t = k => en[k] || k;
    const media = index['notch.mediaStyle'];
    const note = Reason.explain(media, k => (k === 'notch.disableHoverExpansion' ? true : undefined), lookup, t);
    assert.equal(note.text, 'Needs “Media panel” on');
    assert.deepEqual(plain({ key: note.fix.key, value: note.fix.value, on: note.fix.on }), { key: 'notch.disableHoverExpansion', value: false, on: true });
    assert.equal(Reason.explain(media, () => false, lookup, t), null, 'enabled: no note');
});

test('a condition no switch can fix uses the entry reason', () => {
    const index = Reason.entryIndex(all);
    const lookup = k => index[k] || null;
    const t = k => en[k] || k;
    const vals = { 'terminal.enabled': true, 'apps.theming.kitty': false };
    const note = Reason.explain(index['terminal.padding'], k => vals[k], lookup, t);
    assert.equal(note.fix, null);
    assert.equal(note.text, en['prefs.disabled.needs_kitty']);
    const off = Reason.explain(index['terminal.padding'], k => (k === 'terminal.enabled' ? false : vals[k]), lookup, t);
    assert.equal(off.fix.key, 'terminal.enabled', 'the first failing switch wins');
});

test('every greyable entry can say why, in every language', () => {
    const index = Reason.entryIndex(all);
    const lookup = k => index[k] || null;
    let n = 0;
    for (const e of entries()) {
        if (!e.enabledWhen)
            continue;
        n++;
        if (Reason.needsReason(e, lookup))
            assert.ok(e.reason, `${e.key || e.id} needs a reason`);
    }
    assert.ok(n >= 40, `${n} greyable entries`);
    const keys = ['prefs.disabled.needs_on', 'prefs.disabled.needs_off', 'prefs.disabled.generic', 'prefs.disabled.turn_on', 'prefs.disabled.turn_off',
        'prefs.view.all', 'prefs.view.show_all', 'prefs.view.more_hidden.other'];
    for (const lang of ['en', 'es', 'ru'])
        for (const k of keys)
            assert.ok(tr(lang)[k], `${lang} ${k}`);
});

test('inverted toggles are toggles', () => {
    const inverted = entries().filter(e => e.invert);
    assert.ok(inverted.some(e => e.key === 'notch.disableHoverExpansion'));
    for (const e of inverted)
        assert.equal(e.type, 'toggle', e.key);
});
