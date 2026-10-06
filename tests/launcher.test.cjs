// Launcher provider logic: registry/routing, calculator, unit and currency
// conversion, command matching, file search helpers.
const test = require('node:test');
const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');
const { loadLibrary } = require('./lib/qmljs.cjs');

const DIR = path.join(__dirname, '..', 'modules/widgets/launcher');
const P = loadLibrary(path.join(DIR, 'Providers.js'));
const C = loadLibrary(path.join(DIR, 'Calc.js'));
const U = loadLibrary(path.join(DIR, 'Units.js'));
const M = loadLibrary(path.join(DIR, 'Commands.js'));
const F = loadLibrary(path.join(DIR, 'FileQuery.js'));
const PREFIX = loadLibrary(path.join(__dirname, '..', 'config/defaults/prefix.js')).data;
const REGISTRY = JSON.parse(fs.readFileSync(path.join(__dirname, '..', 'assets/commands/commands.json'), 'utf8')).commands;
const plain = v => JSON.parse(JSON.stringify(v));

test('every inline provider has a component file and a default order slot', () => {
    for (const p of P.PROVIDERS) {
        if (p.kind === 'inline') {
            assert.ok(fs.existsSync(path.join(DIR, p.file)), p.file);
            assert.ok(PREFIX.launcher.order.includes(p.id), p.id + ' in prefix.launcher.order');
        }
        if (p.prefix)
            assert.equal(typeof PREFIX[p.prefix], 'string', 'prefix.' + p.prefix + ' default');
    }
    assert.deepEqual(plain(P.ordered(PREFIX.launcher.order)), plain(PREFIX.launcher.order));
});

test('order: unknown ids dropped, new providers appended, move/enable', () => {
    assert.deepEqual(plain(P.ordered(['ai', 'bogus', 'apps'])).slice(0, 2), ['ai', 'apps']);
    assert.equal(P.ordered(['ai']).length, P.INLINE_IDS.length);
    assert.deepEqual(plain(P.move(['apps', 'ai'], 'ai', -1)).slice(0, 2), ['ai', 'apps']);
    assert.deepEqual(plain(P.setEnabled(['files'], 'files', true)), []);
    assert.deepEqual(plain(P.setEnabled([], 'files', false)), ['files']);
    assert.ok(!P.active(PREFIX.launcher.order, ['files']).includes('files'));
});

test('routing: prefixes win, word prefixes need a space, mixed otherwise', () => {
    const r = (t, dis) => plain(P.route(t, PREFIX, PREFIX.launcher.order, dis || []));
    assert.deepEqual(r('> preset neon'), { mode: 'prefix', providers: [{ id: 'commands', query: 'preset neon' }] });
    assert.deepEqual(r('?why is the sky blue'), { mode: 'prefix', providers: [{ id: 'ai', query: 'why is the sky blue' }] });
    assert.deepEqual(r('= 2+2').providers, [{ id: 'calculator', query: '2+2' }]);
    assert.deepEqual(r('ff notes').providers, [{ id: 'files', query: 'notes' }]);
    assert.deepEqual(r('ww sakura').providers, [{ id: 'wallpapers', query: 'sakura' }]);
    assert.deepEqual(r('@backup'), { mode: 'prefix', providers: [{ id: 'routines', query: 'backup' }] });
    assert.deepEqual(r('@').providers, [{ id: 'routines', query: '' }]);
    assert.equal(r('a@b.com').mode, 'mixed');
    assert.equal(r('@x', ['routines']).mode, 'mixed');
    assert.equal(r('ffmpeg').mode, 'mixed');
    assert.deepEqual(r('').providers.map(p => p.id), ['apps']);
    const mixed = r('firefox').providers.map(p => p.id);
    assert.deepEqual(mixed, ['routines', 'calculator', 'commands', 'apps', 'specials', 'files', 'ai']);
    assert.ok(!mixed.includes('wallpapers'));
    // a disabled provider's prefix is plain text
    assert.equal(r('> dnd', ['commands']).mode, 'mixed');
});

test('tab prefixes switch only on "<prefix> " exactly', () => {
    assert.equal(P.detectTab('cc ', PREFIX, []), 1);
    assert.equal(P.detectTab('ee ', PREFIX, []), 2);
    assert.equal(P.detectTab('cc x', PREFIX, []), 0);
    assert.equal(P.detectTab('cc ', PREFIX, ['clipboard']), 0);
    assert.ok(P.startsWithTabPrefix('nn hello', PREFIX));
    assert.equal(P.tabProvider(4).id, 'notes');
});

test('hintPrefixes: enabled providers with a prefix, in hint order', () => {
    assert.deepEqual(plain(P.hintPrefixes(PREFIX, [])), ['cc', 'ee', '=', '?']);
    assert.deepEqual(plain(P.hintPrefixes(PREFIX, ['emoji'])), ['cc', '=', '?']);
    assert.deepEqual(plain(P.hintPrefixes(Object.assign({}, PREFIX, { ai: '' }), [])), ['cc', 'ee', '=']);
    assert.deepEqual(plain(P.hintPrefixes(PREFIX, [], ['files', 'bogus'])), ['ff']);
    assert.deepEqual(plain(P.hintPrefixes(null, [])), []);
});

test('calculator', () => {
    const cases = { '12*7': 84, '12x7': 84, '2^10': 1024, '-3^2': -9, '2^-1': 0.5, '(1+2)*3': 9, 'sqrt(16)+1': 5,
        '10%': 0.1, '5!': 120, 'log2(8)': 3, '7 mod 3': 1, '3 ÷ 4': 0.75, '2pi': 2 * Math.PI, 'max(1, 4, 2)': 4 };
    for (const [e, v] of Object.entries(cases))
        assert.ok(Math.abs(C.evaluate(e) - v) < 1e-9, e);
    for (const e of ['hello', '1/0', '2+', '', 'alert(1)', 'constructor'])
        assert.equal(C.evaluate(e), null, e);
    assert.ok(C.looksLikeMath('12*7'));
    assert.ok(!C.looksLikeMath('42'));
    assert.ok(!C.looksLikeMath('firefox'));
    assert.equal(C.format(1234567.5), '1 234 567.5');
    assert.equal(C.format(0.1 + 0.2), '0.3');
    assert.equal(C.plain(0.1 + 0.2), '0.3');
});

test('units and currency', () => {
    const rates = { USD: 1, EUR: 0.9, RUB: 90 };
    const near = (q, v, kind) => {
        const r = U.convert(q, rates);
        assert.ok(r, q);
        assert.ok(Math.abs(r.value - v) < 1e-6 * Math.max(1, Math.abs(v)), q + ' = ' + r.value);
        if (kind) assert.equal(r.kind, kind);
    };
    near('5 kg in lb', 11.0231131092, 'unit');
    near('72 f to c', 22.2222222222);
    near('0 c in k', 273.15);
    near('5 in in cm', 12.7);
    near('3.5 gib as mb', 3758.096384);
    near('10 km/h to mph', 6.2137119224);
    near('2*3 kg in g', 6000);
    near('100 usd in rub', 9000, 'currency');
    near('$100 in eur', 90);
    near('100€ to usd', 111.1111111111);
    assert.equal(U.convert('5 kg in usd', rates), null);
    assert.equal(U.convert('100 usd in xyz', rates), null);
    assert.equal(U.convert('hello world', rates), null);
});

test('bundled fallback currency table is usable', () => {
    const fb = JSON.parse(fs.readFileSync(path.join(__dirname, '..', 'assets/launcher/currency-fallback.json'), 'utf8'));
    assert.equal(fb.rates.USD, 1);
    assert.ok(U.convert('100 usd in rub', fb.rates).value > 0);
});

test('commands: registry entries are well formed', () => {
    const ids = new Set();
    for (const c of REGISTRY) {
        assert.ok(/^[a-z][a-z0-9-]*$/.test(c.id), c.id);
        assert.ok(!ids.has(c.id), 'duplicate ' + c.id);
        ids.add(c.id);
        assert.ok(c.title && c.icon && c.run, c.id);
        assert.ok(M.plan(c, c.arg && c.arg.values ? c.arg.values[0] : '1'), c.id + ' plan');
    }
});

test('commands: matching and arguments', () => {
    const reg = REGISTRY.map(c => Object.assign({ label: c.id }, c));
    const presets = ['Neon Tokyo', 'Yozakura Night', 'Sumi-e'];
    const ids = (q, mixed) => plain(M.match(reg, q, presets, mixed).map(r => r.cmd.id + '(' + r.arg + ')' + (r.check.ok ? '' : '!')));
    assert.deepEqual(ids('preset neon'), ['preset(Neon Tokyo)']);
    assert.deepEqual(ids('preset'), ['preset(Neon Tokyo)', 'preset(Yozakura Night)', 'preset(Sumi-e)']);
    assert.deepEqual(ids('preset zzz'), ['preset(zzz)!']);
    assert.deepEqual(ids('wallpaper'), ['wallpaper(random)', 'wallpaper(next)', 'wallpaper(previous)']);
    assert.deepEqual(ids('dnd'), ['dnd()']);
    assert.deepEqual(ids('random wallpaper'), ['wallpaper(random)']);
    assert.deepEqual(ids('glass 0.6'), ['glass(0.6)']);
    assert.deepEqual(ids('glass 3'), ['glass(3)!']);
    assert.equal(ids('').length, reg.length);
    // mixed searches: strong matches only, runnable only
    assert.deepEqual(ids('dnd', true), ['dnd()']);
    assert.deepEqual(ids('firefox', true), []);
    assert.deepEqual(ids('', true), []);
    assert.deepEqual(plain(M.plan(reg.find(c => c.id === 'glass'), '0.6')), { kind: 'config', key: 'theme.glass.amount', value: 0.6 });
    assert.deepEqual(plain(M.plan(reg.find(c => c.id === 'theme'), 'light')), { kind: 'config', key: 'theme.lightMode', value: true });
    assert.deepEqual(plain(M.plan(reg.find(c => c.id === 'preset'), 'Neon Tokyo')), { kind: 'cli', argv: ['preset', 'apply', 'Neon Tokyo'] });
    assert.deepEqual(plain(M.plan(reg.find(c => c.id === 'wallpaper'), 'next')), { kind: 'ui', value: 'wallpaper-next' });
    assert.equal(M.completion('>', reg.find(c => c.id === 'preset'), ''), '>preset ');
});

test('file search: backend choice, command, parsing', () => {
    assert.equal(F.backend('auto', { fd: 'fd', plocate: true }), 'fd');
    assert.equal(F.backend('plocate', { fd: 'fd', plocate: true }), 'plocate');
    assert.equal(F.backend('fd', { plocate: true }), 'plocate');
    assert.equal(F.backend('auto', {}), '');
    // The query, home and excludes are argv, never part of the script.
    const cmd = plain(F.command('fd', "it's $(id)", '/home/u', ['.git'], 10, { fd: 'fdfind' }));
    assert.deepEqual(cmd.slice(0, 2), ['sh', '-c']);
    assert.ok(!cmd[2].includes("it's") && !cmd[2].includes('/home/u') && !cmd[2].includes('.git'), cmd[2]);
    assert.deepEqual(cmd.slice(3), ['file-search', 'fdfind', '50', "it's $(id)", '/home/u', '--exclude', '.git']);
    assert.equal(F.command('fd', '  ', '/home/u', [], 10, {}), null);
    const loc = plain(F.command('plocate', 'x', '/home/u', [], 10, {}));
    assert.ok(!loc[2].includes('/home/u'), loc[2]);
    assert.deepEqual(loc.slice(3), ['file-search', '200', 'x', '/home/u/', '40']);
    const out = ['f\t/home/u/src/proj/notes.md', 'd\t/home/u/notes', 'f\t/etc/notes', 'f\t/home/u/.git/notes',
        'f\t/home/u/a/b/c/my-notes.txt', 'garbage'].join('\n');
    const res = plain(F.parse(out, 'notes', '/home/u', ['.git'], 10));
    assert.deepEqual(res.map(f => f.path), ['/home/u/notes', '/home/u/src/proj/notes.md', '/home/u/a/b/c/my-notes.txt']);
    assert.equal(res[0].isDir, true);
    assert.equal(F.pretty('/home/u/src', '/home/u'), '~/src');
    assert.equal(F.iconName({ name: 'a.png', isDir: false }), 'image');
    assert.equal(F.iconName({ name: 'x', isDir: true }), 'folder');
});

test('routines first by default; an untouched old default order is migrated, a custom one kept', () => {
    assert.equal(P.ordered(PREFIX.launcher.order)[0], 'routines');
    const old = ['calculator', 'commands', 'timers', 'apps', 'specials', 'routines', 'wallpapers', 'files', 'ai'];
    assert.deepEqual(plain(P.ordered(old)), plain(PREFIX.launcher.order));
    const older = old.filter(id => id !== 'routines');
    assert.equal(P.ordered(older)[0], 'routines');
    const custom = ['apps', 'calculator', 'commands', 'timers', 'specials', 'routines', 'wallpapers', 'files', 'ai'];
    assert.deepEqual(plain(P.ordered(custom)), custom);
    assert.equal(P.ordered(['ai', 'routines', 'apps']).indexOf('routines'), 1);
});
