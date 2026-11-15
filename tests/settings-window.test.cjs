// What the settings window shows: the important entries are rows of the
// tab's cards (SchemaUtil.inCards); entries and sections flagged `advanced`
// (and folded expert blocks) are rows of the tab's folded More settings
// card (SchemaUtil.moreGroups). Every entry is reachable and searchable.
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
// the rows of the tabs' cards (the budgets below count these)
const windowItems = () => SchemaUtil.flatten(all).filter(x => SchemaUtil.inCards(x.entry, x.section));

test('advanced entries, advanced sections and folded blocks are rows of the More card', () => {
    const c = cat();
    const cards = SchemaUtil.flatten([c]).filter(x => SchemaUtil.inCards(x.entry, x.section)).map(x => x.entry.key);
    assert.deepEqual(plain(cards), ['bar.a']);
    const more = SchemaUtil.moreGroups(c).map(g => [g.section.id, g.entries.map(e => e.key)]);
    assert.deepEqual(plain(more), [['main', ['bar.b']], ['expert', ['bar.c']], ['fold', ['bar.d']]]);
    // every entry is reachable: in a card or in the More card, never both
    for (const x of SchemaUtil.flatten([c]))
        assert.ok(SchemaUtil.inWindow(x.entry, x.section) && SchemaUtil.inCards(x.entry, x.section) !== SchemaUtil.isAdvanced(x.entry, x.section), x.entry.key);
});

test('the window search finds card rows and the More card rows (a card row first)', () => {
    const index = SchemaUtil.buildSearchIndex([cat()], k => k);
    const items = index.filter(i => i.entryId);
    assert.deepEqual(plain(items.map(i => [i.entryId, i.advanced])), [['bar.a', false], ['bar.b', true], ['bar.c', true], ['bar.d', true]]);
    const real = SchemaUtil.buildSearchIndex(all, k => en[k] || k);
    const hit = SchemaUtil.search(real, 'Bar reveal strip', 5).find(r => r.entryId === 'bar.hoverRegionHeight');
    assert.ok(hit && hit.advanced === true, 'an advanced entry is found, marked for the More card');
    assert.ok(SchemaUtil.search(real, 'clock face', 5).some(r => r.entryId === 'bar.moduleOptions.clock.face'), 'a card row is found');
    // equal matches: the card row ranks over the More card's
    const twin = [{ entryId: 'a', label: 'Gap', haystack: 'gap', advanced: true }, { entryId: 'b', label: 'Gap', haystack: 'gap' }];
    assert.equal(SchemaUtil.search(twin, 'gap', 2)[0].entryId, 'b');
});

test('Reset page touches every row of the page, the More card included', () => {
    const ctx = { compositor: 'hyprland', get: () => undefined };
    const keys = ResetModel.activeItems(cat(), ctx).map(it => it.entry.key);
    assert.deepEqual(plain(keys), ['bar.a', 'bar.b', 'bar.c', 'bar.d']);
});

test('every schema entry is reachable in the window and every labelled one is searchable', () => {
    const index = SchemaUtil.buildSearchIndex(all, k => en[k] || k);
    const found = new Set(index.filter(i => i.entryId).map(i => i.categoryId + '/' + i.entryId));
    let cards = 0, more = 0;
    for (const c of all) {
        // a hand-written page draws its own entries (Presets): not here
        if (c.page)
            continue;
        const inMore = new Set();
        for (const g of SchemaUtil.moreGroups(c))
            g.entries.forEach(e => inMore.add(e));
        for (const s of c.sections || [])
            for (const e of s.entries || []) {
                const id = SchemaUtil.entryId(e);
                // rendered by SettingsPage: a row of a card (SettingsSection
                // keeps inCards entries) or of the More card (moreGroups)
                const card = SchemaUtil.inCards(e, s);
                assert.ok(card !== inMore.has(e), `${c.id}/${id}: a card row or a More row, exactly one`);
                card ? cards++ : more++;
                if (e.label)
                    assert.ok(found.has(c.id + '/' + id), `${c.id}/${id}: searchable`);
            }
    }
    assert.ok(cards > 100 && more > 0, `${cards} card rows, ${more} More rows`);
});

test('the window stays small: about 150 rows when every page is curated', () => {
    const n = windowItems().length;
    // Bar and Look are curated (phase 1); the rest still awaits its page
    // conversion (modules/settings/AGENTS.md, CONVERTING A PAGE).
    assert.ok(n < 345, `${n} window rows`);
    // `part` entries edit one part of a composite value another row also edits
    const of = id => windowItems().filter(x => x.category.id === id && !x.entry.part).length;
    // (conditional rows included: the several-bars editor, the frame and sheet options)
    assert.ok(of('bar') + of('layout') <= 30, `Bar: ${of('bar') + of('layout')} rows`);
    assert.ok(of('appearance') + of('icons-type') <= 29, `Look: ${of('appearance') + of('icons-type')} rows`);
});

test('every converted page keeps its row budget', () => {
    // window rows per tab (every row of the scrolling page; `part`
    // entries not counted), a little room over what each page has now:
    // a page that grows past it is re-curated (`advanced`: its More card),
    // not squeezed in
    const BUDGET = {
        'icons-type': 7, 'wallpapers': 12, 'notch': 17, 'dock': 16,
        'overview': 6, 'launcher': 9, 'desktop': 13, 'lockscreen': 9, 'notifications': 18,
        'menus': 10, 'dashboard': 9, 'specials': 3, 'windows': 13,
        'terminal': 11, 'input': 4, 'system': 6, 'voice': 17, 'timers': 20,
        'routines': 2, 'updates': 4, 'power': 8, 'network': 3, 'bluetooth': 3,
        'sound': 4, 'effects': 3, 'ai': 42, 'ai-providers': 18, 'ai-code': 18,
        'presets': 2,
    };
    const of = id => windowItems().filter(x => x.category.id === id && !x.entry.part).length;
    for (const [id, max] of Object.entries(BUDGET))
        assert.ok(of(id) <= max, `${id}: ${of(id)} rows (budget ${max})`);
    // every tab with a `row` has a budget here
    for (const c of all)
        if ((c.row || []).length > 0 && !['bar', 'appearance', 'extras', 'mods'].includes(c.id))
            assert.ok(c.id in BUDGET, `${c.id} has a row budget`);
    assert.ok(windowItems().length < 345, `${windowItems().length} window rows in all`);
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
    // Look is not a desktop page: no miniature (settings-page-unique.test.cjs)
    assert.equal(Categories.byId('appearance').stage, undefined);
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

test('a card row only waits on keys some row of the window edits (nothing becomes unreachable)', () => {
    const edited = new Set();
    for (const c of Categories.categories)
        for (const s of c.sections || [])
            for (const e of s.entries || [])
                if (SchemaUtil.inWindow(e, s))
                    [e.key].concat(e.keys || []).filter(Boolean).forEach(k => edited.add(k));
    const covered = k => {
        for (let q = k; q; q = q.lastIndexOf('.') > 0 ? q.slice(0, q.lastIndexOf('.')) : '')
            if (edited.has(q))
                return true;
        return false;
    };
    const keysOf = (c, out) => {
        if (!c)
            return out;
        if (Array.isArray(c))
            c.forEach(x => keysOf(x, out));
        else {
            if (c.key)
                out.push(c.key);
            (c.all || []).concat(c.any || []).forEach(x => keysOf(x, out));
            keysOf(c.not, out);
        }
        return out;
    };
    for (const c of Categories.categories)
        for (const s of c.sections || [])
            for (const e of s.entries || []) {
                if (!SchemaUtil.inWindow(e, s))
                    continue;
                for (const k of keysOf(e.visibleWhen, []))
                    assert.ok(covered(k), `${c.id} ${e.key || e.id} waits on ${k}, which no window row edits`);
            }
});
