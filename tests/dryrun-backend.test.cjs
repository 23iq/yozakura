// Dry-run backend mock (modules/services/DryRunBackend.js): which methods are
// intercepted, the journal lines they produce, the fake display session
// timeline, fake installs (progress, fail list, cancel) and the read overlays.
const test = require('node:test');
const assert = require('node:assert');
const path = require('node:path');
const { loadLibrary } = require('./lib/qmljs.cjs');

const D = loadLibrary(path.join(__dirname, '..', 'modules/services/DryRunBackend.js'));
const M = loadLibrary(path.join(__dirname, '..', 'modules/services/DryRunMethods.js'));
const plain = v => JSON.parse(JSON.stringify(v));
const eq = (a, b, msg) => assert.deepStrictEqual(plain(a), plain(b), msg);

test('mutating methods are intercepted, reads pass through', () => {
    for (const m of ['displays.apply', 'displays.keep', 'displays.revert', 'displays.moveConflicts',
        'keyboard.apply', 'keyboard.next', 'extras.install', 'extras.cancel', 'extras.upgradeAndRetry',
        'extras.ollamaPull', 'extras.setLoginShell', 'term.apply', 'exclusive.enable', 'exclusive.restore',
        'preset.load', 'wallpaper.set', 'apphooks.apply', 'apphooks.revert', 'apphooks.ensure',
        'config.write', 'config.patch', 'config.stateSet', 'config.statesSet',
        'compositor.write', 'compositor.dispatch', 'compositor.eval'])
        assert.ok(D.isMutating(m), m);
    for (const m of ['displays.list', 'displays.conflicts', 'keyboard.catalog',
        'extras.catalog', 'extras.status', 'extras.log', 'term.presets', 'term.preview', 'term.status',
        'exclusive.status', 'exclusive.plan', 'config.statesGet', 'compositor.state', 'providers.ollama.probe',
        'weather.get', 'clipboard.getContent'])
        assert.ok(!D.isMutating(m), m);
    // compositor.dispatch: daemon CLI queries are reads, the rest mutates
    for (const args of [['layout', 'list'], ['system', 'get-compositor'], ['monitor', 'status']])
        assert.ok(!D.isMutating('compositor.dispatch', { args }), args.join(' '));
    for (const args of [['layout', 'set', 'dwindle'], ['system', 'execute', 'kitty'], []])
        assert.ok(D.isMutating('compositor.dispatch', { args }), args.join(' '));
    // fail closed: anything not known as a read is mocked
    for (const m of ['nightlight.set', 'usage.record', 'config.read', 'brand.new', 'list', '', 'x.listing',
        'keystore.list', 'keystore.get', 'displays.identify'])
        assert.ok(D.isMutating(m), m);
    // dispatch queries: a yozd noun first, no option anywhere
    for (const args of [['-c', 'list'], ['layout', 'list', '-c', '/tmp/x.toml'], ['bogus', 'list'], ['layout', 'list', 5]])
        assert.ok(D.isMutating('compositor.dispatch', { args }), JSON.stringify(args));
});

test('identify is local, keys stay away, refresh is stripped', () => {
    const s = D.create([]);
    D.overlay(s, 'displays.list', [{ name: 'DP-1' }, { name: 'HDMI-A-1' }]);
    const r = D.handle(s, 'displays.identify', {}, 0);
    eq([r.line, r.events], [null, [{ service: 'displays.identify', data: { outputs: [{ name: 'DP-1', index: 1 }, { name: 'HDMI-A-1', index: 2 }] }, line: null }]]);
    eq(D.handle(s, 'keystore.list', {}, 0).result, [], 'no key is set');
    eq(D.handle(s, 'keystore.set', { provider: 'openai', api_key: 'sk-secret' }, 0).line, 'save the API key of openai', 'the key is never journaled');
    eq(D.readParams('extras.status', { refresh: true }), {});
    eq(D.readParams('extras.catalog', { a: 1 }), { a: 1 });
});

test('unknown methods: mocked with an empty answer and journaled', () => {
    const s = D.create([]);
    const r = D.handle(s, 'nightlight.set', { on: true }, 0);
    eq([r.result, r.error, r.line, r.events], [{}, null, 'unmocked call nightlight.set', []]);
    eq(M.line('apphooks.ensure', {}, s), null, 'quiet ones stay quiet');
});

test('journal lines', () => {
    const s = D.create([]);
    D.overlay(s, 'displays.list', [
        { name: 'DP-1', width: 2560, height: 1440, refresh: 60, scale: 1, enabled: true, x: 0, y: 0 },
        { name: 'HDMI-A-1', width: 1920, height: 1080, refresh: 144, scale: 1, enabled: true, x: 2560, y: 0 }]);
    const line = (m, p) => D.handle(s, m, p, 0).line;
    eq(line('displays.apply', { outputs: [
        { name: 'DP-1', width: 2560, height: 1440, refresh: 165, scale: 1, enabled: true, x: 0, y: 0 },
        { name: 'HDMI-A-1', width: 1920, height: 1080, refresh: 144, scale: 1, enabled: true, x: 2560, y: 0 }] }),
        'apply display DP-1 2560x1440@165', 'only the changed monitor');
    eq(line('displays.apply', { outputs: [{ name: 'X', width: 1920, height: 1080, refresh: 59.951, scale: 1.25, enabled: true }] }),
        'apply display X 1920x1080@59.95 scale 1.25', 'unknown monitor: listed, scale shown');
    eq(line('keyboard.apply', { layouts: [{ layout: 'us', variant: '' }, { layout: 'ru', variant: 'phonetic' }], switchBind: 'alt_shift', options: [] }),
        'set keyboard us,ru(phonetic) alt_shift');
    eq(line('keyboard.apply', { layouts: [{ layout: 'us' }], switchBind: '', options: ['caps:escape'] }),
        'set keyboard us caps:escape');
    eq(line('extras.install', { ids: ['firefox', 'steam'] }), 'install firefox, steam');
    eq(line('extras.setLoginShell', { shell: '/usr/bin/fish' }), 'set login shell /usr/bin/fish');
    eq(line('extras.ollamaPull', { model: 'llama3.2' }), 'pull ollama model llama3.2');
    eq(line('exclusive.enable', {}), 'make exclusive');
    eq(line('preset.load', { name: 'Neon Tokyo' }), 'apply preset Neon Tokyo');
    eq(line('wallpaper.set', { path: '/w/a.png' }), 'set wallpaper /w/a.png');
    eq(line('compositor.dispatch', { args: ['monitor', 'focus', '1'] }), 'compositor monitor focus 1');
    eq(line('config.stateSet', { key: 'onboarding', value: {} }), null, 'state writes are kept, not journaled');
});

test('display session: 15 s countdown, kept or reverted', () => {
    const s = D.create([]);
    const r = D.handle(s, 'displays.apply', { outputs: [] }, 1000);
    eq(r.result.revertIn, 15);
    assert.ok(r.result.session);
    const ticks = D.due(s, 1000 + 3000);
    eq(ticks.map(e => e.data.remaining), [14, 13, 12], 'one tick per second');
    assert.ok(ticks.every(e => e.service === 'displays.session' && e.data.state === 'pending'));
    const end = D.due(s, 1000 + 15000);
    eq(end[end.length - 1].data, { session: r.result.session, state: 'reverted', remaining: 0, live: true });
    assert.match(end[end.length - 1].line, /reverted/);
    eq(D.due(s, 99999), [], 'nothing after the timeout');

    const k = D.handle(s, 'displays.apply', { outputs: [] }, 0);
    const kept = D.handle(s, 'displays.keep', { session: k.result.session }, 2000);
    eq(kept.events.map(e => e.data.state), ['kept']);
    eq(kept.line, 'keep display change');
    eq(D.due(s, 99999), [], 'keep stops the countdown');

    const v = D.handle(s, 'displays.apply', { outputs: [] }, 0);
    const rev = D.handle(s, 'displays.revert', { session: v.result.session }, 2000);
    eq(rev.events.map(e => e.data.state), ['reverted']);
    eq(D.due(s, 99999), []);
});

test('install: progress 0 -> 100 over ~4 s, then installed', () => {
    const s = D.create([]);
    D.overlay(s, 'extras.status', { firefox: { state: 'missing' }, git: { state: 'installed' } });
    const r = D.handle(s, 'extras.install', { ids: ['firefox'] }, 0);
    eq(r.result.jobs.length, 1);
    const job = r.result.jobs[0].id;
    eq(r.events.map(e => [e.service, e.data.state]), [['extras.progress', 'queued']]);
    const evs = D.due(s, 4000);
    const prog = evs.filter(e => e.service === 'extras.progress');
    const pct = prog.map(e => e.data.percent);
    assert.ok(pct.every((p, i) => i === 0 || p >= pct[i - 1]), 'monotonic');
    eq(prog[prog.length - 1].data.state, 'done');
    eq(pct[pct.length - 1], 100);
    assert.ok(prog.every(e => e.data.job === job && e.data.entries[0] === 'firefox'));
    const st = evs.find(e => e.service === 'extras.status');
    eq(st.data.firefox.state, 'installed');
    eq(st.data.git.state, 'installed', 'the rest of the detection is kept');
    eq(D.overlay(s, 'extras.status', { firefox: { state: 'missing' } }).firefox.state, 'installed',
        'a later real detection still shows it installed');
    eq(D.overlayEvent(s, 'extras.status', { firefox: { state: 'missing' } }).firefox.state, 'installed');
});

test('fail list: those ids fail with reason network', () => {
    const s = D.create(['steam']);
    const r = D.handle(s, 'extras.install', { ids: ['firefox', 'steam'] }, 0);
    eq(r.result.jobs.map(j => j.entries), [['firefox'], ['steam']]);
    const last = {};
    D.due(s, 5000).filter(e => e.service === 'extras.progress').forEach(e => last[e.data.entries[0]] = e.data);
    eq(last.firefox.state, 'done');
    eq([last.steam.state, last.steam.reason], ['failed', 'network']);
    assert.strictEqual(D.overlay(s, 'extras.status', {}).steam, undefined, 'a failed id is not marked installed');
});

test('cancel stops a fake job', () => {
    const s = D.create([]);
    const job = D.handle(s, 'extras.install', { ids: ['a'] }, 0).result.jobs[0].id;
    D.due(s, 1000);
    const c = D.handle(s, 'extras.cancel', { job }, 1000);
    eq(c.events.map(e => [e.data.state, e.data.kind, e.data.entries]), [['cancelled', 'system', ['a']]], 'the job kind and entries');
    eq(D.due(s, 9999), []);
    assert.strictEqual(D.overlay(s, 'extras.status', {}).a, undefined);
});

test('ollama pull, login shell and upgrade-and-retry are fake jobs too', () => {
    const s = D.create([]);
    const failed = D.handle(s, 'extras.install', { ids: ['steam'] }, 0).result.jobs[0].id;
    D.due(s, 5000);
    const up = D.handle(s, 'extras.upgradeAndRetry', { job: failed }, 5000);
    eq([up.result.jobs[0].kind, up.result.jobs[0].entries, up.events[0].data.state], ['upgrade', ['steam'], 'queued']);
    const upEnd = D.due(s, 10000);
    eq(upEnd[upEnd.length - 1].data.state, 'done');
    const r = D.handle(s, 'extras.ollamaPull', { model: 'qwen' }, 0);
    eq(r.result.jobs[0].kind, 'ollama');
    const evs = D.due(s, 5000);
    eq(evs[evs.length - 1].data.state, 'done');
    D.handle(s, 'extras.setLoginShell', { shell: '/usr/bin/fish' }, 0);
    D.due(s, 5000);
    eq(D.overlay(s, 'term.status', { fishIsLoginShell: false }).fishIsLoginShell, true);
});

test('exclusive mode flips an in-memory status', () => {
    const s = D.create([]);
    eq(D.overlay(s, 'exclusive.status', { active: false, compositor: 'hyprland' }).active, false);
    const r = D.handle(s, 'exclusive.enable', {}, 0);
    eq([r.result.active, r.error], [true, null]);
    eq(D.overlay(s, 'exclusive.status', { active: false, compositor: 'hyprland' }).active, true);
    D.handle(s, 'exclusive.restore', {}, 0);
    eq(D.overlay(s, 'exclusive.status', { active: false }).active, false);
});

test('reads without an overlay are returned untouched', () => {
    const s = D.create([]);
    const v = { a: 1 };
    assert.strictEqual(D.overlay(s, 'keyboard.catalog', v), v);
    assert.strictEqual(D.overlayEvent(s, 'keyboard.layout', v), v);
    assert.ok(!D.hasPending(s));
    D.handle(s, 'displays.apply', { outputs: [] }, 0);
    assert.ok(D.hasPending(s));
});
