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
