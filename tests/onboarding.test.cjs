// Onboarding wizard: step registry (files, translations), detection probe
// parsing, keybind tour helpers, preset mini-preview looks and voice setup
// progress (modules/onboarding/*.js).
const test = require('node:test');
const assert = require('node:assert');
const fs = require('node:fs');
const path = require('node:path');
const { execFileSync } = require('node:child_process');
const { loadLibrary } = require('./lib/qmljs.cjs');

const repo = path.resolve(__dirname, '..');
const dir = path.join(repo, 'modules/onboarding');
const Steps = loadLibrary(path.join(dir, 'OnboardingSteps.js'));
const M = loadLibrary(path.join(dir, 'OnboardingModel.js'));
const Core = loadLibrary(path.join(repo, 'config/CoreBinds.js'));
const Brand = loadLibrary(path.join(repo, 'modules/globals/BrandActions.js'));
const langs = ['en', 'es', 'ru'].map(l => [l, JSON.parse(fs.readFileSync(path.join(repo, 'translations', l + '.json'), 'utf8'))]);
const plain = v => JSON.parse(JSON.stringify(v));
const eq = (a, b, msg) => assert.deepStrictEqual(plain(a), plain(b), msg);

test('every step has a component file, unique id and translated texts', () => {
    const ids = new Set();
    for (const s of Steps.STEPS) {
        assert.ok(!ids.has(s.id), 'duplicate step ' + s.id);
        ids.add(s.id);
        assert.ok(fs.existsSync(path.join(dir, s.component)), s.component);
        for (const [l, tr] of langs) {
            assert.ok(tr[s.title], `${l}: ${s.title}`);
            assert.ok(tr[s.subtitle], `${l}: ${s.subtitle}`);
        }
    }
    assert.strictEqual(Steps.STEPS[0].id, 'welcome');
    assert.strictEqual(Steps.STEPS[Steps.count() - 1].id, 'finish');
});

test('navigation clamps at both ends', () => {
    assert.strictEqual(Steps.prev(0), 0);
    assert.strictEqual(Steps.next(Steps.count() - 1), Steps.count() - 1);
    assert.strictEqual(Steps.next(0), 1);
    assert.ok(Steps.isFirst(0) && Steps.isLast(Steps.count() - 1));
    assert.strictEqual(Steps.indexOf('keybinds'), Steps.STEPS.findIndex(s => s.id === 'keybinds'));
    assert.strictEqual(Steps.indexOf('nope'), -1);
});

test('every onboarding.* key used in QML exists in every language', () => {
    const used = new Set();
    for (const f of fs.readdirSync(dir).filter(f => f.endsWith('.qml') || f.endsWith('.js'))) {
        const src = fs.readFileSync(path.join(dir, f), 'utf8');
        for (const m of src.matchAll(/"(onboarding\.[a-z0-9_.]*[a-z0-9_])"/g))
            used.add(m[1]);
    }
    assert.ok(used.size > 20);
    for (const [l, tr] of langs)
        for (const k of used)
            assert.ok(tr[k], `${l}: missing ${k}`);
});

test('the detection probe runs and its output parses', () => {
    // The data dir is $1, never part of the script.
    const script = M.detectScript();
    assert.ok(!script.includes('/nonexistent'));
    const out = execFileSync('bash', ['-c', script, 'detect', "/nonexistent/it's $(id)"], { encoding: 'utf8' });
    const d = M.parseDetect(out);
    assert.ok(d.complete);
    assert.strictEqual(d.whisper.installed, false);
    assert.ok(Array.isArray(plain(d.terminals)));
});

test('parseDetect keeps known terminals/agents in preference order', () => {
    const d = M.parseDetect('term=foot\nterm=kitty\nterm=evilterm\nterm=kitty\nagent=claude:/usr/bin/claude\nagent=rm:/bin/rm\n' +
        'agent=ollama:/usr/bin/ollama\nwhisper=bin\nwhisper=model\ngpu=cuda\ngarbage\ndone=1\n');
    eq(d.terminals, ['kitty', 'foot']);
    eq(d.agents, { claude: '/usr/bin/claude', ollama: '/usr/bin/ollama' });
    eq(d.whisper, { installed: true, model: true });
    assert.ok(d.cuda && d.complete);
    assert.strictEqual(M.parseDetect('').complete, false);
});

test('choices: current terminal and auto language always offered', () => {
    eq(M.terminalChoices(['kitty'], 'foot'), ['foot', 'kitty']);
    eq(M.terminalChoices(['kitty'], 'kitty'), ['kitty']);
    const l = M.languageChoices({ ru: 'Русский', en: 'English' });
    eq(l.map(x => x.code), ['auto', 'en', 'ru']);
});

test('tour: every task action is a core bind, keys come from enabled rows', () => {
    const coreActions = new Set(Core.BINDS.map(b => Core.defaultBind(b).action.id));
    for (const t of M.TOUR) {
        assert.ok(coreActions.has(Brand.action(t.action)), 'no core bind for ' + t.action);
        for (const [l, tr] of langs)
            assert.ok(tr[t.title] && tr[t.hint], `${l}: ${t.id}`);
    }
    const id = Brand.action('keybinds');
    const rows = [
        { enabled: false, keys: [{ modifiers: ['SUPER'], key: 'K' }], actions: [{ id }] },
        { enabled: true, keys: [], actions: [{ id }] },
        { enabled: true, keys: [{ modifiers: ['SUPER'], key: 'SLASH' }], actions: [{ id: 'x' }, { id }] }
    ];
    eq(M.findKeys(rows, id), { modifiers: ['SUPER'], key: 'SLASH' });
    assert.strictEqual(M.findKeys(rows, 'missing'), null);
    assert.ok(!M.tourDone({ cheatsheet: 'done' }));
    const all = {};
    M.TOUR.forEach((t, i) => { all[t.id] = i % 2 ? 'done' : 'skipped'; });
    assert.ok(M.tourDone(all));
});

test('presetLook reads bar/theme and falls back to current values', () => {
    const look = M.presetLook({ position: 'left', frameEnabled: true, layout: { style: 'islands' } }, { roundness: 0, oledMode: true }, {});
    eq(look, { position: 'left', style: 'islands', frame: true, roundness: 0, light: false, oled: true, font: '' });
    const fb = M.presetLook(null, null, { position: 'bottom', roundness: 8, light: true, style: 'classic' });
    assert.strictEqual(fb.position, 'bottom');
    assert.strictEqual(fb.roundness, 8);
    assert.ok(fb.light);
    assert.strictEqual(M.presetLook({ position: 'diagonal' }, {}, {}).position, 'top');
});

test('voice setup progress follows the script stages and never goes back', () => {
    let p = M.voiceProgress('\x1b[0;34m::\x1b[0m Cloning whisper.cpp v1.9.4', 0);
    assert.strictEqual(p.stage, 'fetch');
    assert.strictEqual(p.text, 'Cloning whisper.cpp v1.9.4');
    p = M.voiceProgress(':: Building (CUDA, 16 jobs; this takes a few minutes)', p.progress);
    assert.strictEqual(p.stage, 'build');
    const later = M.voiceProgress('-- some cmake noise', p.progress);
    assert.strictEqual(later.progress, p.progress);
    assert.strictEqual(M.voiceProgress(':: Done. Enable voice input in Settings', 0.7).progress, 1);
    // The script's own info lines match a stage.
    const script = fs.readFileSync(path.join(repo, 'scripts/voice_setup.sh'), 'utf8');
    for (const m of ['Cloning', 'Configuring', 'Building', 'Installed whisper', 'Downloading', 'Done.'])
        assert.ok(script.includes(m), 'voice_setup.sh no longer prints ' + m);
});
