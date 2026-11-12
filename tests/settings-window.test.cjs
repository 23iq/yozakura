// What the settings window shows (SchemaUtil.inWindow): entries and sections
// flagged `advanced` (and folded expert blocks) are not rows of the window
// and not found by its search, but stay in the schema (catalog, CLI, MCP).
// Greyed rows explain themselves (modules/settings/DisabledReason.js).
const { test } = require('node:test');
const assert = require('node:assert/strict');
const path = require('node:path');
const { loadLibrary } = require('./lib/qmljs.cjs');

const repo = path.join(__dirname, '..');
const Reason = loadLibrary(path.join(repo, 'modules/settings/DisabledReason.js'));
const SchemaUtil = loadLibrary(path.join(repo, 'modules/settings/SchemaUtil.js'));
const ResetModel = loadLibrary(path.join(repo, 'modules/settings/ResetModel.js'));
const Registry = loadLibrary(path.join(repo, 'modules/settings/Registry.js'));
const Categories = loadLibrary(path.join(repo, 'modules/settings/schema/Categories.js'));
const tr = lang => require(`../translations/${lang}.json`);
const en = tr('en');
const plain = v => JSON.parse(JSON.stringify(v));

const cat = () => ({
    id: 'demo', icon: 'gear', title: 'prefs.cat.bar',
    sections: [
        { id: 'main', title: 't', entries: [{ key: 'bar.a', label: 'A' }, { key: 'bar.b', label: 'B', advanced: true }] },
        { id: 'expert', title: 't', advanced: true, entries: [{ key: 'bar.c', label: 'C' }] },
        { id: 'fold', title: 't', collapsible: true, collapsed: true, entries: [{ key: 'bar.d', label: 'D' }] },
    ],
});
const all = Categories.categories;
const entries = () => SchemaUtil.flatten(all).map(x => x.entry);
const windowItems = () => SchemaUtil.flatten(all).filter(x => SchemaUtil.inWindow(x.entry, x.section));

test('advanced entries, advanced sections and folded blocks are not in the window', () => {
    const c = cat();
    const shown = SchemaUtil.flatten([c]).filter(x => SchemaUtil.inWindow(x.entry, x.section)).map(x => x.entry.key);
    assert.deepEqual(plain(shown), ['bar.a']);
});

test('the window search finds window rows only; the schema keeps every entry', () => {
    const index = SchemaUtil.buildSearchIndex([cat()], k => k);
    const keys = index.filter(i => i.entryId).map(i => i.entryId);
    assert.deepEqual(plain(keys), ['bar.a']);
    const real = SchemaUtil.buildSearchIndex(all, k => en[k] || k);
    assert.ok(!SchemaUtil.search(real, 'Bar reveal strip', 5).some(r => r.entryId === 'bar.hoverRegionHeight'), 'an out-of-window entry is not found');
    assert.ok(SchemaUtil.search(real, 'clock face', 5).some(r => r.entryId === 'bar.moduleOptions.clock.face'), 'a window row is found');
    assert.ok(entries().some(e => e.key === 'bar.hoverRegionHeight'), 'the entry stays in the schema (catalog)');
});

test('Reset page touches window rows only', () => {
    const ctx = { compositor: 'hyprland', get: () => undefined };
    const keys = ResetModel.activeItems(cat(), ctx).map(it => it.entry.key);
    assert.deepEqual(plain(keys), ['bar.a']);
});

test('the window stays small: about 150 rows when every page is curated', () => {
    const n = windowItems().length;
    // Bar and Look are curated (phase 1); the rest still awaits its page
    // conversion (modules/settings/AGENTS.md, CONVERTING A PAGE).
    assert.ok(n < 342, `${n} window rows`);
    const of = id => windowItems().filter(x => x.category.id === id).length;
    // (conditional rows included: the several-bars editor, the frame and sheet options)
    assert.ok(of('bar') + of('layout') <= 30, `Bar: ${of('bar') + of('layout')} rows`);
    assert.ok(of('appearance') + of('icons-type') <= 24, `Look: ${of('appearance') + of('icons-type')} rows`);
});

test('a setting has one control in the window (Bar and Look)', () => {
    const seen = {};
    for (const x of windowItems()) {
        if (!['bar', 'layout', 'appearance', 'icons-type'].includes(x.category.id))
            continue;
        // `part`: an editor of one part of a composite value (the bars list
        // beside the stage, the selected bar's fields in a card)
        if (x.entry.part)
            continue;
        for (const k of SchemaUtil.entryKeys(x.entry)) {
            assert.ok(!seen[k], `${k} twice: ${seen[k]} and ${x.entry.key || x.entry.id}`);
            seen[k] = x.entry.key || x.entry.id;
        }
    }
    for (const k of ['theme.roundness', 'theme.glass.enabled', 'theme.glass.amount', 'compositor.motionProfile'])
        assert.ok(!seen[k], `${k} is the macro's, not a row of its own`);
});

test('picture cards have a registered thumb; stages are registered', () => {
    for (const x of windowItems()) {
        if (x.entry.display === 'cards')
            assert.ok(Registry.thumb(x.entry.thumb), `${x.entry.key}: thumb ${x.entry.thumb}`);
    }
    for (const c of all)
        if (c.stage)
            assert.ok(Registry.stage(c.stage), `${c.id}: stage ${c.stage}`);
    assert.equal(Categories.byId('bar').stage, 'BarStage');
    assert.equal(Categories.byId('appearance').stage, 'LookStage');
});

test('window labels are short and in sentence case (Bar and Look)', () => {
    for (const x of windowItems()) {
        if (!['bar', 'layout', 'appearance', 'icons-type'].includes(x.category.id))
            continue;
        const label = en[x.entry.label];
        assert.ok(label, `${x.entry.key || x.entry.id}: label`);
        const words = label.split(/\s+/);
        assert.ok(words.length <= 4, `${label}: at most four words`);
        assert.ok(!words.slice(1).some(w => /^[A-Z][a-z]/.test(w)), `${label}: sentence case`);
    }
});

test('every signature feature is one window row, its fine options out of the window', () => {
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
        'prefs.undo.changed', 'prefs.undo.undone', 'prefs.undo.redone', 'prefs.undo.undo', 'prefs.undo.redo', 'prefs.undo.reset_page'];
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
