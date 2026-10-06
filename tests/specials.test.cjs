// Special workspaces logic (modules/specials/Specials.js): safe Hyprland
// names (+ the Go parity fixture), templates, edits, window matching, the
// launch/move plan with its no-double-launch rule, adoption of late
// windows, rename migration, window rules and keybind rows.
const test = require('node:test');
const assert = require('node:assert');
const fs = require('node:fs');
const path = require('node:path');
const { loadLibrary } = require('./lib/qmljs.cjs');

const repo = path.resolve(__dirname, '..');
const S = loadLibrary(path.join(repo, 'modules/specials/Specials.js'));
const Model = loadLibrary(path.join(repo, 'modules/keybinds/BindModel.js'));
const Actions = loadLibrary(path.join(repo, 'config/KeybindActions.js'));
const plain = v => JSON.parse(JSON.stringify(v));
const eq = (a, b, msg) => assert.deepStrictEqual(plain(a), plain(b), msg);
const fixture = path.join(repo, 'tests/fixtures/special-names.json');

const tg = { id: 'telegram', name: 'Telegram', icon: 'telegram', accent: 'primary',
    toggle: { modifiers: ['SUPER'], key: 'S' }, send: { modifiers: ['SUPER', 'ALT'], key: 'S' },
    apps: [{ id: 'org.telegram.desktop', match: 'org.telegram.desktop', command: 'Telegram', ifRunning: 'nothing' }] };

test('names are sanitized for Hyprland and stay readable', () => {
    assert.strictEqual(S.sanitizeName('  My Chat  '), 'My-Chat');
    assert.strictEqual(S.sanitizeName('a,b:c[d]'), 'a-b-c-d');
    assert.strictEqual(S.sanitizeName('Разработка'), 'Разработка');
    assert.strictEqual(S.sanitizeName('$(rm -rf ~)'), 'rm-rf');
    assert.strictEqual(S.sanitizeName('---'), '');
    assert.strictEqual(Array.from(S.sanitizeName('x'.repeat(50))).length, S.MAX_NAME);
});

test('the Go sanitizer matches (parity fixture)', () => {
    const cases = JSON.parse(fs.readFileSync(fixture, 'utf8'));
    for (const c of cases)
        assert.strictEqual(S.sanitizeName(c.in), c.out, JSON.stringify(c.in));
});

test('Hyprland names are unique and fall back for empty names', () => {
    const names = S.hyprNames([{ id: 'a', name: 'Chat' }, { id: 'b', name: 'chat' }, { id: 'c', name: '' }]);
    eq(names, { a: 'Chat', b: 'chat-2', c: 'special-3' });
    assert.strictEqual(S.byHyprName([tg], 'special:Telegram').id, 'telegram');
});

test('templates: custom ones are "Special N", installed apps are suggested', () => {
    const tr = (k, n) => k === 'specials.default_name' ? 'Special ' + n : 'Chat';
    const avail = id => id === 'vesktop' ? { id: 'vesktop.desktop', name: 'Vesktop', icon: 'vesktop', execString: 'vesktop %U', startupClass: 'vesktop' } : null;
    const chat = S.create([], 'chat', tr, avail);
    assert.strictEqual(chat.name, 'Chat');
    assert.strictEqual(chat.id, 'chat');
    eq(chat.apps.map(a => [a.id, a.match, a.command]), [['vesktop', 'vesktop', 'vesktop']]);
    const one = S.create([chat], 'custom', tr, avail);
    assert.strictEqual(one.name, 'Special 1');
    const two = S.create([chat, one], 'custom', tr, avail);
    assert.strictEqual(two.name, 'Special 2');
    assert.notStrictEqual(two.id, one.id);
    // A second chat template does not clash with the first.
    assert.strictEqual(S.create([chat], 'chat', tr, avail).name, 'Special 1');
});

test('desktop entries become apps (field codes stripped)', () => {
    eq(S.appFromEntry({ id: 'org.telegram.desktop.desktop', name: 'Telegram', icon: 'telegram', execString: 'Telegram -- %u', startupClass: '' }),
        { id: 'org.telegram.desktop', name: 'Telegram', icon: 'telegram', match: 'org.telegram.desktop', command: 'Telegram --', ifRunning: 'nothing', rule: false });
    assert.strictEqual(S.stripFieldCodes('app --x=100%% %F'), 'app --x=100%');
});

test('edits return new lists', () => {
    let l = [S.normalize(tg)];
    l = S.withApp(l, 'telegram', { id: 'x', match: 'x', command: 'x' });
    assert.strictEqual(l[0].apps.length, 2);
    l = S.withApp(l, 'telegram', { id: 'x', match: 'x', command: 'x' });
    assert.strictEqual(l[0].apps.length, 2, 'duplicate app ignored');
    l = S.withAppPatch(l, 'telegram', 1, { ifRunning: 'move', rule: true });
    assert.strictEqual(l[0].apps[1].ifRunning, 'move');
    l = S.withAppPatch(l, 'telegram', 1, { ifRunning: 'bogus' });
    assert.strictEqual(l[0].apps[1].ifRunning, 'nothing');
    l = S.withoutApp(l, 'telegram', 1);
    assert.strictEqual(l[0].apps.length, 1);
    l = S.withItem(l, 'telegram', { name: 'TG' });
    assert.strictEqual(l[0].name, 'TG');
    assert.strictEqual(S.withoutItem(l, 'telegram').length, 0);
    eq(S.problems([{ id: 'a', name: 'X Y' }, { id: 'b', name: 'x-y' }, { id: 'c', name: ' ' }]),
        [{ id: 'b', kind: 'duplicate', other: 'a' }, { id: 'c', kind: 'empty' }]);
});

test('windows: special from numeric id or name, class regex matching', () => {
    const wss = [{ id: -98, name: 'special:Telegram' }, { id: 1, name: '1' }];
    assert.strictEqual(S.windowSpecial({ workspace: { id: -98, name: '-98' } }, wss), 'Telegram');
    assert.strictEqual(S.windowSpecial({ workspace: { id: 0, name: 'special:Dev' } }, wss), 'Dev');
    assert.strictEqual(S.windowSpecial({ workspace: { id: 1, name: '1' } }, wss), '');
    assert.ok(S.classMatches('org.telegram.desktop', 'org.Telegram.Desktop'));
    assert.ok(S.classMatches('discord|vesktop', 'vesktop'));
    assert.ok(!S.classMatches('disc', 'discord'), 'anchored');
    assert.ok(!S.classMatches('(', 'x'), 'bad regex is no match');
    eq(S.counts(S.windowsOf([{ address: 'a', class: 'x', workspace: { id: -98 } }, { address: 'b', class: 'y', workspace: { id: 1 } }], wss)), { Telegram: 1 });
});

test('plan: launch when missing, never twice while pending, move per option', () => {
    const item = S.normalize(tg);
    eq(S.plan(item, 'Telegram', [], {}, 1000).map(a => a.kind), ['launch']);
    const key = S.appKey('telegram', item.apps[0]);
    eq(S.plan(item, 'Telegram', [], { [key]: { deadline: 5000 } }, 1000), [], 'pending: no second launch');
    eq(S.plan(item, 'Telegram', [], { [key]: { deadline: 500 } }, 1000).length, 1, 'expired pending relaunches');
    const elsewhere = [{ address: '0x1', class: 'org.telegram.desktop', special: '' }];
    eq(S.plan(item, 'Telegram', elsewhere, {}, 1000), [], 'running elsewhere + nothing: untouched');
    item.apps[0].ifRunning = 'move';
    eq(S.plan(item, 'Telegram', elsewhere, {}, 1000), [{ kind: 'move', address: '0x1' }]);
    eq(S.plan(item, 'Telegram', [{ address: '0x1', class: 'org.telegram.desktop', special: 'Telegram' }], {}, 1000), [], 'already inside');
});

test('adopt: late windows of a launched app are moved in, once', () => {
    const pending = { 'telegram/tg': { deadline: 9000, name: 'Telegram', match: 'tg', known: ['0xold'] } };
    eq(S.adopt(pending, [{ address: '0xold', class: 'tg', special: '' }], 1000), { moves: [], done: [] });
    eq(S.adopt(pending, [{ address: '0xnew', class: 'tg', special: '' }], 1000), { moves: [{ address: '0xnew', name: 'Telegram' }], done: ['telegram/tg'] });
    eq(S.adopt(pending, [{ address: '0xnew', class: 'tg', special: 'Telegram' }], 1000), { moves: [], done: ['telegram/tg'] });
    eq(S.adopt(pending, [], 10000), { moves: [], done: ['telegram/tg'] }, 'timeout clears');
});

test('rename migrates the windows of the old name', () => {
    eq(S.renames({ a: 'Chat', b: 'Dev' }, { a: 'Talk', b: 'Dev' }), [{ from: 'Chat', to: 'Talk' }]);
    eq(S.windowsOn([{ address: '1', special: 'Chat' }, { address: '2', special: '' }], 'Chat'), ['1']);
});

test('window rules only for apps with rule on', () => {
    const items = [Object.assign({}, tg, { apps: [{ match: 'tg', rule: true }, { match: 'x' }] })];
    eq(S.windowRules(items), [{ match: 'class:^(tg)$', workspace: 'special:Telegram silent' }]);
});

test('bind rows join the keybinds model (cheatsheet, conflicts, TOML)', () => {
    const rows = S.bindRows([tg, { id: 'dev', name: 'Dev', toggle: { modifiers: ['SUPER'], key: 'C' } }]);
    eq(rows.map(r => r.uid), ['special:telegram:toggle', 'special:telegram:send', 'special:dev:toggle']);
    for (const r of rows)
        assert.ok(Actions.getActionById(r.actions[0].id), r.actions[0].id + ' is catalogued');
    eq(Actions.resolveAction(rows[0].actions[0]), { dispatcher: 'togglespecialworkspace', argument: 'Telegram', flags: '' });
    eq(Actions.resolveAction(rows[1].actions[0]), { dispatcher: 'movetoworkspacesilent', argument: 'special:Telegram', flags: '' });
    const all = Model.buildRows({ root: {}, custom: [{ name: 'x', keys: [{ modifiers: ['SUPER'], key: 'S' }], actions: [{ id: 'command.run', args: { command: 'x' } }] }], disabled: [], specials: rows });
    const special = all.find(r => r.uid === 'special:telegram:toggle');
    assert.ok(special && special.kind === 'special');
    const conflicts = Model.findConflicts(all, []);
    assert.ok(conflicts['special:telegram:toggle'], 'clash with a custom bind is reported');
    eq(S.compositorBinds([tg])[0], { name: 'Telegram', enabled: true, keys: [{ modifiers: ['SUPER'], key: 'S' }], actions: [{ id: 'workspace.toggle-special-named', args: { name: 'Telegram' } }] });
});

test('only Hyprland is supported', () => {
    assert.ok(S.supported('hyprland'));
    assert.ok(!S.supported('niri'));
    assert.ok(!S.supported(''));
});

test('launcher search ranks exact, prefix, word and substring matches', () => {
    const items = [{ id: 'a', name: 'My Telegram' }, { id: 'b', name: 'Tele' }, { id: 'c', name: 'Hotel' }, { id: 'd', name: 'Dev' }];
    eq(S.search(items, 'tele').map(i => i.id), ['b', 'a']);
    eq(S.search(items, 'tel').map(i => i.id), ['b', 'a', 'c']);
    eq(S.search(items, '  '), []);
    eq(S.search(items, 'my-tel').map(i => i.id), ['a'], 'Hyprland name matches too');
});

test('visible clients follow an open special over the active workspace', () => {
    const clients = [
        { address: 'a', workspace: { id: 1 } },
        { address: 'b', workspace: { id: -98 } },
        { address: 'c', workspace: { id: -97, name: 'special:Dev' } },
        { address: 'd', workspace: { id: 2 } },
    ];
    const workspaces = [{ id: -98, name: 'special:Telegram' }];
    eq(S.visibleClients(clients, workspaces, 1, '').map(c => c.address), ['a']);
    eq(S.visibleClients(clients, workspaces, 1, 'Telegram').map(c => c.address), ['b']);
    eq(S.visibleClients(clients, workspaces, 1, 'Dev').map(c => c.address), ['c']);
    eq(S.visibleClients(clients, workspaces, 1, 'Empty'), [], 'an empty special shows nothing');
});
