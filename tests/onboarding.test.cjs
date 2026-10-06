// Onboarding wizard: step registry (files, translations), detection probe
// parsing, keybind tour helpers, preset mini-preview looks and the Ollama
// pull chips (modules/onboarding/*.js).
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

test('the registry is the 8-step flow, in order, with existing icons', () => {
    eq(Steps.STEPS.map(s => s.id), ['welcome', 'displays', 'look', 'terminal', 'apps', 'ai', 'keybinds', 'finish']);
    const icons = fs.readFileSync(path.join(repo, 'modules/theme/Icons.qml'), 'utf8');
    for (const s of Steps.STEPS) {
        assert.ok(new RegExp('property string ' + s.icon + ':').test(icons), 'no icon ' + s.icon);
        assert.strictEqual(s.optional, undefined, 'the unused optional field is gone');
    }
    eq(Steps.STEPS.filter(s => s.hero).map(s => s.id), ['welcome', 'finish']);
    for (const old of ['StepPreset.qml', 'StepWallpaper.qml', 'StepSystem.qml', 'StepSpecials.qml'])
        assert.ok(!fs.existsSync(path.join(dir, old)), old + ' was folded into the new steps');
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
            assert.ok(tr[k] || tr[k + '.other'], `${l}: missing ${k}`); // I18n.tn keys: <key>.other
});

test('the detection probe runs and its output parses', () => {
    const out = execFileSync('bash', ['-c', M.detectScript(), 'detect'], { encoding: 'utf8' });
    const d = M.parseDetect(out);
    assert.ok(d.complete);
    assert.ok(Array.isArray(plain(d.terminals)));
});

test('parseDetect keeps known terminals in preference order', () => {
    const d = M.parseDetect('term=foot\nterm=kitty\nterm=evilterm\nterm=kitty\nagent=claude:/usr/bin/claude\ngarbage\ndone=1\n');
    eq(d, { terminals: ['kitty', 'foot'], complete: true });
    assert.strictEqual(M.parseDetect('').complete, false);
});

test('diagonalInches: from the physical size, empty when unknown', () => {
    assert.strictEqual(M.diagonalInches({ physical_width_mm: 597, physical_height_mm: 336 }), 27);
    assert.strictEqual(M.diagonalInches({ physical_width_mm: 344, physical_height_mm: 194 }), 15.5);
    assert.strictEqual(M.diagonalInches({ physical_width_mm: 0, physical_height_mm: 0 }), 0);
    assert.strictEqual(M.diagonalInches(null), 0);
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

test('pullState: Ollama model chips follow their pull job', () => {
    eq(M.OLLAMA_MODELS.map(m => m.id), ['llama3.2', 'qwen2.5-coder', 'gemma3']);
    eq(M.pullState(null, false), { state: 'idle', percent: -1 });
    eq(M.pullState(null, true), { state: 'pulling', percent: -1 }, 'asked for, no event yet');
    eq(M.pullState({ state: 'queued', percent: 0 }, true), { state: 'pulling', percent: -1 });
    eq(M.pullState({ state: 'running', percent: 42 }, true), { state: 'pulling', percent: 42 });
    eq(M.pullState({ state: 'done', percent: 100 }, true), { state: 'done', percent: 100 });
    eq(M.pullState({ state: 'failed', percent: 10 }, true), { state: 'failed', percent: -1 });
    eq(M.pullState({ state: 'cancelled', percent: 10 }, true), { state: 'idle', percent: -1 });
    eq(M.pullState(null, false, true), { state: 'done', percent: 100 }, 'pulled before');
    eq(M.pulledModels({ models: [{ id: 'llama3.2:latest' }, { id: 'gemma3:4b' }] }), ['llama3.2', 'gemma3']);
    eq(M.pulledModels(null), []);
});
