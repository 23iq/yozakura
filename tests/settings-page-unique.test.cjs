// One setting is one row in one place: on every page of the settings window
// no key is rendered twice and no two rows share a label (in every language,
// with the default config and with the states that show conditional rows).
// Only the pages whose subject is the desktop draw it on their stage.
const { test } = require('node:test');
const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');
const { loadLibrary } = require('./lib/qmljs.cjs');

const repo = path.join(__dirname, '..');
const SchemaUtil = loadLibrary(path.join(repo, 'modules/settings/SchemaUtil.js'));
const Registry = loadLibrary(path.join(repo, 'modules/settings/Registry.js'));
const Categories = loadLibrary(path.join(repo, 'modules/settings/schema/Categories.js'));
const LANGS = ['en', 'es', 'ru'].map(l => [l, require(`../translations/${l}.json`)]);

const defaults = {};
for (const f of fs.readdirSync(path.join(repo, 'config/defaults')))
    if (f.endsWith('.js'))
        defaults[f.slice(0, -3)] = JSON.parse(JSON.stringify(loadLibrary(path.join(repo, 'config/defaults', f)).data || null));

const getter = over => k => {
    if (k in over)
        return over[k];
    let v = defaults[k.split('.')[0]];
    for (const p of k.split('.').slice(1))
        v = v == null ? undefined : v[p];
    return v;
};

// the default config, several bars, the island off, a card host for the
// timers panel, floating notifications: each shows rows the others hide
const STATES = [
    {},
    { 'bar.panels': [{ id: 'a' }, { id: 'b' }] },
    { 'notch.enabled': false },
    { 'layout.panels.host': 'card', 'notifications.presentation': 'corner' },
];

// window rows of a page shown in state `get` (null: every window row)
function rows(cat, get) {
    const out = [];
    for (const s of cat.sections || [])
        for (const e of s.entries || [])
            if (SchemaUtil.inWindow(e, s) && (!get || SchemaUtil.evalCondition(e.visibleWhen, get)))
                out.push({ e, s });
    return out;
}

test('no key is rendered twice on a page', () => {
    for (const state of STATES) {
        const get = getter(state);
        for (const cat of Categories.categories) {
            const seen = {};
            for (const { e, s } of rows(cat, get)) {
                if (!e.key)
                    continue;
                assert.ok(!(e.key in seen), `${cat.id}: ${e.key} in ${seen[e.key]} and ${s.id} (${JSON.stringify(state)})`);
                seen[e.key] = s.id;
            }
        }
    }
});

test('no two rows of a page share a label, in every language', () => {
    for (const [lang, tr] of LANGS)
        for (const state of STATES) {
            const get = getter(state);
            for (const cat of Categories.categories) {
                const seen = {};
                for (const { e } of rows(cat, get)) {
                    if (!e.label)
                        continue;
                    const label = (tr[e.label] || e.label).toLowerCase();
                    const id = e.key || e.id;
                    assert.ok(!(label in seen), `${lang} ${cat.id}: "${label}" is ${seen[label]} and ${id}`);
                    seen[label] = id;
                }
            }
        }
});

test('each Opens-in row lives on the page of what opens', () => {
    const owner = {};
    for (const cat of Categories.categories)
        for (const { e } of rows(cat, null))
            if (e.key)
                if (!(owner[e.key] || []).includes(cat.id))
                    (owner[e.key] = owner[e.key] || []).push(cat.id);
    const want = {
        'layout.launcher.host': 'launcher',
        'layout.dashboard.host': 'dashboard',
        'layout.cheatsheet.host': 'input',
        'layout.aiquick.host': 'ai',
        'layout.panels.host': 'timers',
        'layout.sheet.side': 'menus',
    };
    for (const [key, page] of Object.entries(want))
        assert.deepEqual(owner[key], [page], key);
    // "Where things open" is gone; its old id opens the Bar
    assert.equal(Categories.byId('layout'), null);
    assert.equal(Categories.resolve('layout').id, 'bar');
});

// The desktop (a wallpaper miniature) is the subject of these tabs only.
const DESKTOP = ['bar', 'notch', 'dock', 'desktop', 'lockscreen', 'notifications', 'menus', 'windows', 'wallpapers'];

test('only the desktop pages have a desktop stage; the others a plain stage', () => {
    assert.deepEqual(Object.keys(Registry.DESKTOP_STAGES).sort(), [...DESKTOP].sort());
    for (const cat of Categories.categories) {
        if (!cat.stage)
            continue;
        if (DESKTOP.includes(cat.id))
            assert.equal(cat.stage, Registry.DESKTOP_STAGES[cat.id], cat.id);
        else
            assert.ok(Registry.PLAIN_STAGES.includes(cat.stage), `${cat.id}: ${cat.stage} is a desktop stage on a page that is not about the desktop`);
    }
    // a plain stage is drawn on the card fill, never on the wallpaper
    for (const band of Registry.PLAIN_STAGES) {
        const src = fs.readFileSync(path.join(repo, 'modules/settings', Registry.STAGES[band]), 'utf8');
        assert.ok(!/ScreenMini|ScreenBackdrop|stage\.wallpaper/.test(src.replace(/\/\/.*$/gm, '')), `${band} draws the desktop`);
    }
});
