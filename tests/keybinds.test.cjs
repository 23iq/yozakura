// Keybinds: action catalog audit (translations, groups, Go parity), core
// bind registry, key names / keycaps, the recorder's Qt key mapping and
// BindModel (rows, search, grouping, conflicts, edits).
const test = require('node:test');
const assert = require('node:assert');
const fs = require('node:fs');
const path = require('node:path');
const { loadLibrary } = require('./lib/qmljs.cjs');

const repo = path.resolve(__dirname, '..');
const Actions = loadLibrary(path.join(repo, 'config/KeybindActions.js'));
const Core = loadLibrary(path.join(repo, 'config/CoreBinds.js'));
const CustomDefaults = loadLibrary(path.join(repo, 'config/CustomBindDefaults.js'));
const Keys = loadLibrary(path.join(repo, 'modules/keybinds/KeyNames.js'));
const Model = loadLibrary(path.join(repo, 'modules/keybinds/BindModel.js'));
const Brand = loadLibrary(path.join(repo, 'modules/globals/BrandActions.js'));
const langs = ['en', 'es', 'ru'].map(l => [l, JSON.parse(fs.readFileSync(path.join(repo, 'translations', l + '.json'), 'utf8'))]);
const app = Brand.appId;
// Libraries run in their own realm: compare plain copies.
const plain = v => JSON.parse(JSON.stringify(v));
const eq = (a, b, msg) => assert.deepStrictEqual(plain(a), plain(b), msg);

// --- Audit -------------------------------------------------------------------

test('every action has a translated label in every language', () => {
    for (const a of Actions.ACTION_CATALOG) {
        const key = Actions.labelKey(a.id);
        for (const [lang, table] of langs)
            assert.ok(table[key], `${a.id}: ${key} missing from ${lang}.json`);
    }
});

test('every action belongs to a known group', () => {
    const ids = Model.GROUPS.map(g => g.id);
    for (const a of Actions.ACTION_CATALOG)
        assert.ok(ids.includes(a.group), `${a.id}: group '${a.group}' is not in BindModel.GROUPS`);
});

test('groups and argument fields are translated', () => {
    const keys = Model.GROUPS.flatMap(g => [g.title, g.desc]);
    for (const a of Actions.ACTION_CATALOG)
        for (const f of a.args || []) keys.push(Actions.fieldLabelKey(f.key));
    for (const key of keys)
        for (const [lang, table] of langs)
            assert.ok(table[key], `${key} missing from ${lang}.json`);
});

test('the Go catalog has exactly the JS action ids', () => {
    const go = fs.readFileSync(path.join(repo, 'backend/pkg/svc/compositor/actions.go'), 'utf8');
    const body = go.slice(go.indexOf('var catalog = []ActionSpec{'));
    const goIds = new Set();
    for (const m of body.matchAll(/\{ID: (?:brand\.Action\("([\w-]+)"\)|"([\w.-]+)")/g))
        goIds.add(m[1] ? app + '.' + m[1] : m[2]);
    const jsIds = new Set(Actions.ACTION_CATALOG.map(a => a.id));
    eq([...jsIds].filter(i => !goIds.has(i)), [], 'missing from actions.go');
    eq([...goIds].filter(i => !jsIds.has(i)), [], 'missing from KeybindActions.js');
});

test('core binds: unique paths, catalog actions, adapter entries, Go order', () => {
    const paths = Core.BINDS.map(Core.path);
    assert.strictEqual(new Set(paths).size, paths.length);
    const qml = fs.readFileSync(path.join(repo, 'config/adapters/KeybindsAdapter.qml'), 'utf8');
    const toml = fs.readFileSync(path.join(repo, 'backend/pkg/svc/compositor/toml.go'), 'utf8');
    for (const e of Core.BINDS) {
        assert.ok(Actions.getActionById(Core.actionId(e)), `${Core.path(e)}: unknown action ${Core.actionId(e)}`);
        assert.ok(new RegExp(`property JsonObject ${e.name}: JsonObject`).test(qml), `${Core.path(e)}: no JsonObject in KeybindsAdapter.qml`);
        assert.ok(toml.includes(`"${e.name}"`), `${Core.path(e)}: not in the toml.go bind order`);
    }
});

// Fresh binds.json: core binds (hold binds included) and the default custom
// binds must not share a combo, or Hyprland fires both actions.
test('default binds: every combo is unique', () => {
    const seen = {};
    const add = (label, mods, key) => {
        const id = Keys.comboId(mods, key);
        assert.ok(!seen[id], `${label} and ${seen[id]} share ${Keys.comboText(mods, key)}`);
        seen[id] = label;
    };
    for (const e of Core.BINDS) add('core ' + Core.path(e), e.modifiers, e.key);
    for (const b of CustomDefaults.binds())
        for (const k of b.keys) add('custom ' + b.name, k.modifiers, k.key);
});

test('new defaults: Super+Q closes, Super+T opens the terminal, tmux on Super+Alt+T', () => {
    const byCombo = {};
    for (const b of CustomDefaults.binds()) byCombo[Keys.comboId(b.keys[0].modifiers, b.keys[0].key)] = b;
    const q = byCombo[Keys.comboId(['SUPER'], 'Q')], t = byCombo[Keys.comboId(['SUPER'], 'T')];
    eq(Actions.normalizeCustomBinds([q]).binds[0].actions[0].id, 'window.close');
    eq(Actions.normalizeCustomBinds([t]).binds[0].actions[0].id, app + '.terminal');
    const tmux = Core.byPath('tmux');
    eq([tmux.modifiers, tmux.key], [['SUPER', 'ALT'], 'T']);
});

test('the cheatsheet bind defaults to Super + /', () => {
    const e = Core.byPath('system.keybinds');
    eq([e.modifiers, e.key, Core.actionId(e)], [['SUPER'], 'SLASH', app + '.keybinds']);
    const clash = Core.BINDS.filter(b => b !== e && Keys.comboId(b.modifiers, b.key) === Keys.comboId(e.modifiers, e.key));
    eq(clash, []);
});

// --- Key names / keycaps ---------------------------------------------------------

test('combo ids ignore case, modifier order and aliases', () => {
    assert.strictEqual(Keys.comboId(['SHIFT', 'SUPER'], 'return'), Keys.comboId(['MOD4', 'shift'], 'Return'));
    assert.strictEqual(Keys.comboId(['CONTROL'], 'ESC'), Keys.comboId(['CTRL'], 'ESCAPE'));
    assert.strictEqual(Keys.comboId(['SUPER'], 'PERIOD'), Keys.comboId(['SUPER'], 'period'));
    assert.strictEqual(Keys.comboId(['SUPER'], 'Super_L'), Keys.comboId([], 'Super_L'));
    assert.strictEqual(Keys.comboId(['SUPER'], 'Prior'), Keys.comboId(['SUPER'], 'Page_Up'));
    assert.notStrictEqual(Keys.comboId(['SUPER'], 'S'), Keys.comboId(['SUPER', 'SHIFT'], 'S'));
    assert.strictEqual(Keys.comboId(['SUPER'], ''), '');
});

test('Hyprland modmask decodes to modifiers', () => {
    eq(Keys.modsFromMask(76), ['SUPER', 'CTRL', 'ALT']);
    eq(Keys.modsFromMask(65), ['SUPER', 'SHIFT']);
    eq(Keys.modsFromMask(0), []);
});

test('key hints: Super as text, glyph keys keep their icon', () => {
    eq(Keys.hints(['SUPER', 'SHIFT'], 'S'), [{ text: 'Super', icon: '' }, { text: 'Shift', icon: '' }, { text: 'S', icon: '' }]);
    eq(Keys.hints([], 'Up').map(h => h.text === '' && h.icon !== ''), [true]);
    eq(Keys.hints(['SUPER'], 'Super_L'), [{ text: 'Super', icon: '' }]);
});

test('keycaps: the Super key is the app glyph, a lone Super shows once', () => {
    eq(Keys.caps(['SUPER', 'SHIFT'], 'S').map(c => c.kind + ':' + c.text), ['super:', 'text:Shift', 'text:S']);
    eq(Keys.caps(['SUPER'], 'Super_L').map(c => c.kind), ['super']);
    eq(Keys.caps(['SHIFT', 'CTRL', 'SUPER'], 'a').map(c => c.text), ['', 'Ctrl', 'Shift', 'A']);
});

test('keycaps: arrows, enter, mouse and media keys are glyphs', () => {
    const icon = k => Keys.keycap(k).kind === 'icon' ? Keys.keycap(k).icon : null;
    assert.strictEqual(icon('Up'), 'arrowUp');
    assert.strictEqual(icon('left'), 'arrowLeft');
    assert.strictEqual(icon('Return'), 'keyReturn');
    assert.strictEqual(icon('ENTER'), 'keyReturn');
    assert.strictEqual(icon('mouse:272'), 'mouseLeftClick');
    assert.strictEqual(icon('mouse:273'), 'mouseRightClick');
    assert.strictEqual(icon('mouse_down'), 'mouseScroll');
    assert.strictEqual(Keys.keycap('mouse_up').text, '↑');
    assert.strictEqual(icon('XF86AudioRaiseVolume'), 'speakerHigh');
    assert.strictEqual(icon('XF86AudioNext'), 'next');
    assert.strictEqual(icon('mouse:276'), 'mouse');
});

test('keycaps: short labels for named keys, switches and the rest', () => {
    const text = k => Keys.keycap(k).text;
    assert.strictEqual(text('ESCAPE'), 'Esc');
    assert.strictEqual(text('TAB'), 'Tab');
    assert.strictEqual(text('SPACE'), 'Space');
    assert.strictEqual(text('PERIOD'), '.');
    assert.strictEqual(text('SLASH'), '/');
    assert.strictEqual(text('Page_Down'), 'PgDn');
    assert.strictEqual(text('k'), 'K');
    assert.strictEqual(text('F5'), 'F5');
    assert.strictEqual(text('switch:Lid Switch'), 'Lid');
    assert.strictEqual(text('switch:on:Lid Switch'), 'Lid on');
    assert.strictEqual(text('XF86Launch1'), 'Launch1');
    assert.strictEqual(Keys.comboText(['SUPER', 'SHIFT'], 'S'), 'Super + Shift + S');
});

test('every keycap icon exists in Icons.qml', () => {
    const icons = fs.readFileSync(path.join(repo, 'modules/theme/Icons.qml'), 'utf8');
    const names = new Set(Object.values(Keys.ICON_KEYS).concat(['mouse']));
    for (const g of Model.GROUPS) names.add(g.icon);
    for (const n of names)
        assert.ok(new RegExp(`readonly property string ${n}:`).test(icons), `Icons.${n} missing`);
});

test('recorder: Qt key events map to Hyprland names', () => {
    assert.strictEqual(Keys.keyFromQt(0x41, 'a'), 'A');
    assert.strictEqual(Keys.keyFromQt(0x31, '1'), '1');
    assert.strictEqual(Keys.keyFromQt(0x21, '!'), '1', 'shifted digit binds the digit');
    assert.strictEqual(Keys.keyFromQt(0x3f, '?'), 'SLASH');
    assert.strictEqual(Keys.keyFromQt(0x2e, '.'), 'PERIOD');
    assert.strictEqual(Keys.keyFromQt(0x01000004, '\r'), 'Return');
    assert.strictEqual(Keys.keyFromQt(0x01000013, ''), 'Up');
    assert.strictEqual(Keys.keyFromQt(0x01000034, ''), 'F5');
    assert.strictEqual(Keys.keyFromQt(0x01000072, ''), 'XF86AudioRaiseVolume');
    assert.strictEqual(Keys.keyFromQt(0x20, ' '), 'SPACE');
    assert.strictEqual(Keys.keyFromQt(0x01001234, ''), '');
    assert.strictEqual(Keys.qtModifierKey(0x01000053), 'SUPER');
    assert.strictEqual(Keys.qtModifierKey(0x01000021), 'CTRL');
    assert.strictEqual(Keys.qtModifierKey(0x41), '');
    eq(Keys.modsFromQt(0x10000000 | 0x02000000), ['SUPER', 'SHIFT']);
    assert.strictEqual(Keys.mouseKey(2), 'mouse:273');
});

// --- BindModel ---------------------------------------------------------------

function data(custom, extra) {
    const root = {};
    for (const e of Core.BINDS) {
        const holder = e.section ? (root[e.section] = root[e.section] || {}) : root;
        holder[e.name] = Core.defaultBind(e);
    }
    return Object.assign({ root, custom: custom || [], disabled: [] }, extra || {});
}

const cmd = (name, mods, key, extra) => Object.assign({
    name, keys: [{ modifiers: mods, key }], actions: [{ id: 'command.run', args: { command: name }, layouts: [] }], enabled: true,
}, extra || {});

test('rows: core binds then custom ones, grouped by action', () => {
    const rows = Model.buildRows(data([cmd('Terminal', ['SUPER'], 'Return')]));
    assert.strictEqual(rows.length, Core.BINDS.length + 1);
    const launcher = rows.find(r => r.uid === 'core:launcher');
    assert.strictEqual(launcher.group, 'shell');
    assert.strictEqual(rows.find(r => r.uid === 'core:system.screenshot').group, 'screenshots');
    assert.strictEqual(rows.find(r => r.uid === 'core:voiceAi').group, 'ai');
    const term = rows.find(r => r.uid === 'custom:0');
    assert.strictEqual(term.group, 'apps');
    assert.strictEqual(Model.title(term), 'Terminal');
    // legacy {dispatcher} actions are mapped to catalog ids
    const legacy = Model.buildRows(data([{ name: '', keys: [{ modifiers: ['SUPER'], key: 'C' }], actions: [{ dispatcher: 'killactive', argument: '', flags: '' }] }]));
    assert.strictEqual(legacy.at(-1).actions[0].id, 'window.close');
    assert.strictEqual(legacy.at(-1).group, 'windows');
});

test('titles use translations with the catalog label as fallback', () => {
    const rows = Model.buildRows(data([{ keys: [{ modifiers: ['SUPER'], key: '3' }], actions: [{ id: 'workspace.switch', args: { index: '3' } }] }]));
    const ws = rows.at(-1);
    assert.strictEqual(Model.title(ws), 'Switch Workspace · 3');
    assert.strictEqual(Model.title(ws, k => k === 'binds.action.workspace.switch' ? 'Ir al espacio' : k), 'Ir al espacio · 3');
});

test('search matches titles, combos and action ids; merging joins combos', () => {
    const rows = Model.buildRows(data([cmd('Browser', ['SUPER'], 'W'), cmd('Browser', ['SUPER'], 'B')]));
    eq(Model.filterRows(rows, 'brow').map(r => r.uid), ['custom:0', 'custom:1']);
    assert.ok(Model.filterRows(rows, 'super shift s').some(r => r.uid === 'core:system.screenshot'));
    assert.ok(Model.filterRows(rows, 'workspace').length > 0, 'matches the overview action label');
    assert.strictEqual(Model.filterRows(rows, 'zzz nothing').length, 0);
    const merged = Model.mergeRows(Model.filterRows(rows, 'browser'));
    assert.strictEqual(merged.length, 1);
    eq(merged[0].uids, ['custom:0', 'custom:1']);
    eq(merged[0].keys.map(k => k.key), ['W', 'B']);
});

test('grouping keeps GROUPS order; columns balance the height', () => {
    const groups = Model.grouped(Model.buildRows(data()));
    const order = Model.GROUPS.map(g => g.id);
    const ids = groups.map(g => g.group.id);
    eq(ids, order.filter(id => ids.includes(id)));
    const fake = [10, 2, 3, 9, 1].map((n, i) => ({ group: { id: 'g' + i }, rows: new Array(n) }));
    const cols = Model.columns(fake, 2);
    assert.strictEqual(cols.length, 2);
    const h = c => c.reduce((s, g) => s + g.rows.length + 2, 0);
    assert.ok(Math.abs(h(cols[0]) - h(cols[1])) <= 10);
    assert.strictEqual(Model.columns(fake, 9).length, 5, 'no empty columns');
});

test('conflicts: two enabled binds on one combo', () => {
    const rows = Model.buildRows(data([cmd('Files', ['SUPER'], 'd')]));
    const c = Model.findConflicts(rows, []);
    eq(c['custom:0'].map(x => x.uid), ['core:dashboard']);
    eq(c['core:dashboard'].map(x => x.uid), ['custom:0']);
    assert.strictEqual(c['core:launcher'], undefined);
});

test('conflicts: disabled binds and disjoint layouts do not clash', () => {
    const off = Model.buildRows(data([cmd('Files', ['SUPER'], 'D', { enabled: false })]));
    eq(Model.findConflicts(off, []), {});
    const coreOff = Model.buildRows(data([cmd('Files', ['SUPER'], 'D')], { disabled: ['dashboard'] }));
    eq(Model.findConflicts(coreOff, []), {});
    const lay = (layouts, key) => ({ name: 'x', keys: [{ modifiers: ['SUPER'], key }], actions: [{ id: 'scrolling.promote', args: {}, layouts }], enabled: true });
    const disjoint = Model.buildRows(data([lay(['scrolling'], 'H'), lay(['dwindle'], 'H')]));
    eq(Model.findConflicts(disjoint, []), {});
    const shared = Model.buildRows(data([lay(['scrolling'], 'H'), lay([], 'h')]));
    assert.ok(Model.findConflicts(shared, [])['custom:0']);
});

test('conflicts: compositor-native binds (hyprctl binds -j)', () => {
    const rows = Model.buildRows(data([cmd('Terminal', ['SUPER'], 'Return')]));
    const hypr = [
        // the user's own compositor config (has a description)
        { modmask: 64, key: 'D', has_description: true, description: 'Workspace: Discord', submap: '' },
        // what the shell itself rendered: no description, as many as ours
        { modmask: 64, key: 'Return', has_description: false, description: '', dispatcher: 'exec', arg: 'kitty', submap: '' },
        // an extra undescribed bind on the same combo is native too
        { modmask: 64, key: 'Return', has_description: false, description: '', dispatcher: 'exec', arg: 'foot', submap: '' },
        // other submaps never clash
        { modmask: 64, key: 'N', has_description: true, description: 'resize mode', submap: 'resize' },
        // the launcher (release bind) and the voice hold binds are ours
        { modmask: 64, key: 'Super_L', release: true, has_description: false, submap: '' },
        { modmask: 64, key: 'M', has_description: false, submap: '' },
        { modmask: 64, key: 'M', release: true, has_description: false, submap: '' },
    ];
    const native = Model.nativeBinds(hypr, rows);
    eq(native.map(n => n.text), ['Workspace: Discord', 'exec foot']);
    const c = Model.findConflicts(rows, native);
    eq(c['core:dashboard'], [{ kind: 'native', text: 'Workspace: Discord', combo: 'SUPER|d' }]);
    assert.strictEqual(c['custom:0'][0].text, 'exec foot');
    assert.strictEqual(c['core:launcher'], undefined);
    assert.strictEqual(c['core:voiceAi'], undefined);
    assert.strictEqual(c['core:notes'], undefined);
    eq(Model.rowsUsing(rows, ['SUPER'], 'd', 'custom:0').map(r => r.uid), ['core:dashboard']);
});

test('edits: custom list and disabled core binds are copied, not mutated', () => {
    const list = [cmd('A', ['SUPER'], 'A'), cmd('B', ['SUPER'], 'B')];
    const renamed = Model.withCustom(list, 1, { name: 'Bee', enabled: false });
    assert.strictEqual(list[1].name, 'B');
    assert.strictEqual(renamed[1].name, 'Bee');
    assert.strictEqual(renamed[1].enabled, false);
    eq(Model.withoutCustom(list, 0).map(b => b.name), ['B']);
    const added = Model.withAddedCustom(list, Model.newCustom('window.close'));
    assert.strictEqual(added.length, 3);
    eq(added[2].actions[0], { id: 'window.close', args: {}, layouts: [] });
    eq(Model.withDisabled(['launcher'], 'system.tools', false), ['launcher', 'system.tools']);
    eq(Model.withDisabled(['launcher', 'system.tools'], 'launcher', true), ['system.tools']);
});

test('core binds know when they differ from the default', () => {
    const rows = Model.buildRows(data());
    assert.strictEqual(rows.some(r => Model.isCoreModified(r)), false);
    const d = data();
    d.root.system.lockscreen.key = 'Delete';
    assert.ok(Model.isCoreModified(Model.buildRows(d).find(r => r.uid === 'core:system.lockscreen')));
    const off = Model.buildRows(data([], { disabled: ['tmux'] }));
    assert.ok(Model.isCoreModified(off.find(r => r.uid === 'core:tmux')));
});

test('fullscreen: Super+F maximizes, Super+Alt+F goes fullscreen', () => {
    const byCombo = {};
    for (const b of Actions.normalizeCustomBinds(CustomDefaults.binds()).binds) byCombo[Keys.comboId(b.keys[0].modifiers, b.keys[0].key)] = b.actions[0];
    eq(byCombo[Keys.comboId(['SUPER'], 'F')].id, 'window.maximize');
    eq(byCombo[Keys.comboId(['SUPER', 'ALT'], 'F')].id, 'window.fullscreen');
    eq(Actions.actionFromLegacy('fullscreen', '1', '').id, 'window.maximize');
    eq(Actions.actionFromLegacy('fullscreen', '0', '').id, 'window.fullscreen');
});

test('addNewDefaults appends missing defaults on free combos only', () => {
    const ids = ['window.fullscreen', 'window.maximize'];
    const close = { name: 'Close', keys: [{ modifiers: ['SUPER'], key: 'Q' }], actions: [{ id: 'window.close', args: {}, layouts: [] }], enabled: true };
    const r = Actions.addNewDefaults([close], CustomDefaults.binds(), ids);
    eq(r.changed, true);
    eq(r.binds.map(b => b.actions[0].id), ['window.close', 'window.maximize', 'window.fullscreen']);
    // Already bound action, or a taken combo: nothing is added.
    eq(Actions.addNewDefaults(r.binds, CustomDefaults.binds(), ids).changed, false);
    const onF = { name: 'Mine', keys: [{ modifiers: ['SUPER'], key: 'f' }], actions: [{ id: 'window.close', args: {}, layouts: [] }], enabled: true };
    eq(Actions.addNewDefaults([onF], CustomDefaults.binds(), ids).binds.map(b => b.actions[0].id), ['window.close', 'window.fullscreen']);
});

// --- Open app ------------------------------------------------------------------

const appBind = (app, mods, key, extra) => Object.assign({
    name: '', keys: [{ modifiers: mods, key }], actions: [{ id: 'apps.launch', args: { app }, layouts: [] }], enabled: true,
}, extra || {});

test('apps.launch renders `<app> launch <desktop id>`, quoted only when needed', () => {
    const exec = app => Actions.resolveAction({ id: 'apps.launch', args: { app } });
    eq(exec('firefox'), { dispatcher: 'exec', argument: `${app} launch firefox`, flags: '' });
    assert.strictEqual(exec(' org.gnome.Nautilus.desktop ').argument, `${app} launch org.gnome.Nautilus`);
    assert.strictEqual(exec("it's; rm -rf ~").argument, `${app} launch 'it'\\''s; rm -rf ~'`);
    assert.strictEqual(exec('').argument, '', 'no app: nothing to run');
    eq(Actions.defaultArgs('apps.launch'), { app: '' });
    eq(Actions.getActionFields('apps.launch').map(f => f.kind), ['app']);
    eq(Actions.actionFromLegacy('exec', `${app} launch firefox`, ''), { id: 'apps.launch', args: { app: 'firefox' } });
});

test('the Go renderer quotes desktop ids like the JS one', () => {
    const go = fs.readFileSync(path.join(repo, 'backend/pkg/svc/compositor/actions.go'), 'utf8');
    const js = fs.readFileSync(path.join(repo, 'config/KeybindActions.js'), 'utf8');
    const goRe = /plainWord = regexp\.MustCompile\(`([^`]+)`\)/.exec(go)[1];
    const jsRe = /return \/(\^[^/]+\$)\/\.test\(s\)/.exec(js)[1];
    assert.strictEqual(goRe, jsRe);
});

test('app binds: the row shows the installed app, else its id', () => {
    const lookup = id => (id === 'firefox' ? { name: 'Firefox', icon: 'firefox' } : null);
    const rows = Model.withApps(Model.buildRows(data([appBind('firefox', ['SUPER'], 'B'), appBind('gone', ['SUPER'], 'G')])), lookup);
    const [ff, gone] = rows.slice(-2);
    assert.strictEqual(ff.group, 'apps');
    assert.strictEqual(Model.title(ff), 'Firefox');
    eq(Model.appOf(ff), { id: 'firefox', name: 'Firefox', icon: 'firefox' });
    assert.strictEqual(Model.title(gone), 'Open App · gone');
    eq(Model.filterRows(rows, 'firefox').map(r => r.uid), [ff.uid]);
    assert.strictEqual(Model.appOf(rows[0]), null);
    // display fields never reach binds.json
    eq(Model.customBind('', ff.keys, ff.actions).actions[0], { id: 'apps.launch', args: { app: 'firefox' }, layouts: [] });
});

test('a new custom bind opens an app; Advanced is only for the rare parts', () => {
    eq(Model.newCustom().actions[0], { id: 'apps.launch', args: { app: '' }, layouts: [] });
    const rows = Model.buildRows(data([
        appBind('firefox', ['SUPER'], 'B'),
        appBind('firefox', ['SUPER'], 'B', { keys: [{ modifiers: ['SUPER'], key: 'B' }, { modifiers: ['ALT'], key: 'B' }] }),
        { name: 'x', keys: [{ modifiers: ['SUPER'], key: 'H' }], actions: [{ id: 'scrolling.promote', args: {}, layouts: ['scrolling'] }], enabled: true },
        { name: 'raw', keys: [{ modifiers: ['SUPER'], key: 'J' }], actions: [{ id: 'legacy.dispatcher', args: { dispatcher: 'pin' } }], enabled: true },
    ]));
    eq(rows.slice(-4).map(Model.isAdvanced), [false, true, true, true]);
    assert.strictEqual(Model.isAdvanced(rows[0]), false, 'core binds have no advanced part');
});

test('conflicts never drop a bind: both stay with their own combo', () => {
    const list = [appBind('firefox', ['SUPER'], 'B'), appBind('kitty', ['SUPER'], 'K')];
    const moved = Model.withCustom(list, 1, { keys: [{ modifiers: ['SUPER'], key: 'b' }] });
    eq(moved.map(b => b.actions[0].args.app), ['firefox', 'kitty']);
    eq(moved.map(b => b.keys[0].key), ['B', 'b']);
    const c = Model.findConflicts(Model.buildRows(data(moved)), []);
    eq(Object.keys(c).sort(), ['custom:0', 'custom:1']);
});

// --- Groups follow the action ----------------------------------------------------

test('groups: apps first, layout controls and raw dispatchers have their own', () => {
    eq(Model.GROUPS.map(g => g.id), ['apps', 'windows', 'layout', 'workspaces', 'shell', 'ai', 'utilities', 'screenshots', 'media', 'system', 'other']);
    for (const id of ['scrolling.promote', 'scrolling.resize-column', 'monocle.focus'])
        assert.strictEqual(Actions.groupOf(id), 'layout', id);
    assert.strictEqual(Actions.groupOf('brightness.up'), 'system');
    assert.strictEqual(Actions.groupOf('window.fullscreen'), 'windows');
    assert.strictEqual(Actions.groupOf('legacy.dispatcher'), 'other');
});

test('a command or raw dispatcher is grouped by what it runs', () => {
    const run = command => Model.actionGroup({ id: 'command.run', args: { command } });
    const raw = (dispatcher, argument) => Model.actionGroup({ id: 'legacy.dispatcher', args: { dispatcher, argument: argument || '', flags: '' } });
    assert.strictEqual(run(`${app} run config`), 'shell', 'the settings panel command');
    assert.strictEqual(run(`${app} run screenshot`), 'screenshots', 'a catalog command keeps its group');
    assert.strictEqual(run(`${app} reload`), 'shell');
    assert.strictEqual(run(`${app} launch firefox`), 'apps');
    assert.strictEqual(run(Actions.getActionById('brightness.up').argument), 'system');
    assert.strictEqual(run('wpctl set-mute @DEFAULT_AUDIO_SOURCE@ toggle'), 'media');
    assert.strictEqual(run("~/bin/launch_first_available.sh 'pavucontrol-qt' 'pavucontrol'"), 'media');
    assert.strictEqual(run('grim -g "$(slurp)" - | wl-copy'), 'screenshots');
    assert.strictEqual(run('loginctl lock-session'), 'system');
    assert.strictEqual(run("~/bin/launch_first_available.sh 'firefox' 'brave'"), 'apps');
    assert.strictEqual(run(''), 'apps');
    assert.strictEqual(raw('layoutmsg', 'center'), 'layout');
    assert.strictEqual(raw('movetoworkspace', '3'), 'workspaces');
    assert.strictEqual(raw('pin'), 'windows');
    assert.strictEqual(raw('exec', 'playerctl next'), 'media');
    assert.strictEqual(raw('somethingnew'), 'other');
    // rows take their first action's group, wherever they were added
    const rows = Model.buildRows(data([
        { name: 'Center', keys: [{ modifiers: ['SUPER'], key: 'C' }], actions: [{ id: 'legacy.dispatcher', args: { dispatcher: 'layoutmsg', argument: 'center', flags: '' } }], enabled: true },
        cmd('Mic', ['SUPER', 'ALT'], 'M', { actions: [{ id: 'command.run', args: { command: 'wpctl set-mute @DEFAULT_AUDIO_SOURCE@ toggle' }, layouts: [] }] }),
        cmd('Power', ['CTRL', 'ALT'], 'Delete', { actions: [{ id: 'command.run', args: { command: `${app} run powermenu` }, layouts: [] }] }),
    ]));
    eq(rows.slice(-3).map(r => r.group), ['layout', 'media', 'shell']);
});

// --- Search ------------------------------------------------------------------------

test('search: key combos, names, actions and apps', () => {
    const lookup = id => (id === 'firefox' ? { name: 'Firefox', icon: 'firefox' } : null);
    const rows = Model.withApps(Model.buildRows(data([
        appBind('firefox', ['SUPER'], 'B'),
        cmd('Files', ['SUPER'], 'E'),
        cmd('Files (shifted)', ['SUPER', 'SHIFT'], 'E'),
        cmd('Terminal', ['CTRL', 'ALT'], 'T'),
    ])), lookup);
    const uids = q => Model.filterRows(rows, q).map(r => r.uid);
    // "super e" is exactly Super+E, however it is typed
    eq(uids('super e'), ['custom:1']);
    eq(uids('Super + E'), ['custom:1']);
    eq(uids('win+e'), ['custom:1']);
    eq(uids('ctrl alt t'), ['custom:3']);
    eq(uids('alt ctrl t'), ['custom:3'], 'modifier order does not matter');
    // only modifiers: every bind using them
    assert.ok(uids('super shift').includes('custom:2'));
    assert.ok(!uids('super shift').includes('custom:1'));
    // no exact combo: binds with more modifiers
    eq(uids('shift e'), ['custom:2']);
    // a "key query" without hits falls back to text ("control" is a modifier name)
    eq(uids('control center'), []);
    // names, action labels, app names and ids
    eq(uids('firefox'), ['custom:0']);
    eq(uids('fire'), ['custom:0']);
    assert.ok(uids('screenshot').includes('core:system.screenshot'));
    assert.ok(uids('open app').includes('custom:0'));
    // a one or two letter word matches the start of a word, not any letter
    assert.ok(!uids('e').includes('core:dashboard'), 'not every bind with an "e" in it');
    assert.ok(uids('e').includes('custom:1'), 'the E key');
    eq(uids('   '), rows.map(r => r.uid));
});

test('action picker: apps first, then actions by group, every word matches', () => {
    const opts = Actions.getActionOptions().map(o => Object.assign({}, o, { text: o.label }));
    const apps = [{ id: 'apps.launch', app: 'firefox', text: 'Open Firefox', group: '_apps' }];
    const all = Model.pickerOptions(opts, apps, '');
    assert.strictEqual(all.length, opts.length, 'no query: every action, no apps');
    assert.strictEqual(all[0].group, 'apps', 'apps group first');
    const order = Model.GROUPS.map(g => g.id);
    const idx = all.map(o => order.indexOf(o.group));
    eq(idx, idx.slice().sort((a, b) => a - b), 'in GROUPS order');
    const fs = Model.pickerOptions(opts, [], 'fullscreen');
    eq(fs.map(o => o.id), ['window.fullscreen']);
    eq(Model.pickerOptions(opts, apps, 'firefox').map(o => o.app || o.id), ['firefox']);
    assert.ok(Model.pickerOptions(opts, [], 'toggle float').some(o => o.id === 'window.toggle-float'));
    assert.ok(!Model.pickerOptions(opts, [], 'switch').some(o => o.id === 'legacy.dispatcher'), 'raw dispatcher is hidden');
});

test('a new bind needs keys, an action and its fields before saving', () => {
    const k = [{ modifiers: ['SUPER'], key: 'B' }];
    assert.strictEqual(Model.missingPart([{ modifiers: ['SUPER'], key: '' }], []), 'keys');
    assert.strictEqual(Model.missingPart(k, []), 'action');
    assert.strictEqual(Model.missingPart(k, [{ id: 'apps.launch', args: { app: '' } }]), 'app');
    assert.strictEqual(Model.missingPart(k, [{ id: 'command.run', args: { command: '  ' } }]), 'command');
    assert.strictEqual(Model.missingPart(k, [{ id: 'apps.launch', args: { app: 'firefox' } }]), '');
    assert.strictEqual(Model.missingPart(k, [{ id: 'window.close', args: {} }]), '');
    assert.strictEqual(Model.missingPart(k, [{ id: 'workspace.switch', args: Actions.defaultArgs('workspace.switch') }]), '');
    assert.strictEqual(Model.missingPart(k, [{ id: 'legacy.dispatcher', args: { dispatcher: 'pin', argument: '', flags: '' } }]), '');
});

// --- Utilities group: slots and default binds ---------------------------------

test('utilities: slot actions show as unassigned rows until a bind runs them', () => {
    const slots = Actions.ACTION_CATALOG.filter(a => a.slot).map(a => a.id);
    for (const name of ['timer-input', 'quick-note', 'timers', 'stopwatch-toggle', 'focus-toggle', 'timer-stop'])
        assert.ok(slots.includes(app + '.' + name), name);
    assert.ok(!slots.includes('utilities.routine'), 'routines get one slot each (RoutineSlots.js), not a generic one');
    const rows = Model.buildRows({ root: {}, custom: [], disabled: [] });
    const free = plain(Model.slotRows(rows));
    eq(free.map(r => r.actions[0].id), slots);
    for (const r of free) {
        assert.strictEqual(r.kind, 'slot');
        assert.strictEqual(r.group, 'utilities');
        eq(r.keys, [{ modifiers: [], key: '' }]);
    }
    // A custom bind running the stopwatch takes its slot away
    const bound = Model.buildRows({ root: {}, custom: [{ name: '', keys: [{ modifiers: ['SUPER'], key: 'W' }], actions: [{ id: app + '.stopwatch-toggle', args: {}, layouts: [] }], enabled: true }], disabled: [] });
    const left = plain(Model.slotRows(bound)).map(r => r.actions[0].id);
    assert.ok(!left.includes(app + '.stopwatch-toggle'));
    assert.strictEqual(left.length, slots.length - 1);
    // Empty keys never conflict
    eq(plain(Model.findConflicts(free.concat(free), [])), {});
});

test('utilities: SUPER+SHIFT+T and SUPER+SHIFT+N are defaults only because no core bind uses them', () => {
    const core = Core.BINDS.map(e => Keys.comboId(e.modifiers, e.key));
    const defaults = plain(CustomDefaults.binds());
    for (const [name, key] of [['timer-input', 'T'], ['quick-note', 'N']]) {
        const combo = Keys.comboId(['SUPER', 'SHIFT'], key);
        assert.ok(!core.includes(combo), `${combo} is a core bind`);
        const d = defaults.find(b => b.actions[0].argument === app + ' run ' + name);
        assert.ok(d, name + ' default');
        assert.strictEqual(Keys.comboId(d.keys[0].modifiers, d.keys[0].key), combo);
    }
    // The migration adds them only when the combo is free
    const taken = [{ name: 'Mine', keys: [{ modifiers: ['SUPER', 'SHIFT'], key: 'T' }], actions: [{ id: 'command.run', args: { command: 'foot' }, layouts: [] }], enabled: true }];
    const added = plain(Actions.addNewDefaults(taken, CustomDefaults.binds(), [app + '.timer-input', app + '.quick-note']));
    eq(added.binds.slice(1).map(b => b.actions[0].id), [app + '.quick-note']);
});

test('utilities: parametrised actions run the shell command', () => {
    eq(plain(Actions.resolveAction({ id: 'utilities.timer', args: { spec: '10m tea' } })), { dispatcher: 'exec', argument: app + " run 'timer:10m tea'", flags: '' });
    eq(plain(Actions.resolveAction({ id: 'utilities.timer', args: { spec: '' } })).argument, '');
    eq(plain(Actions.resolveAction({ id: 'utilities.routine', args: { routine: 'morning' } })).argument, app + " run 'routine:morning'");
    assert.ok(!Actions.getActionById('utilities.routine').hidden, 'routines are bindable');
    assert.strictEqual(Actions.getActionById('utilities.routine').args[0].kind, 'routine');
});
