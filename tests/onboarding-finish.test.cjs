// Onboarding summary helpers (modules/onboarding/FinishModel.js): which
// card a queued install belongs to, live install counts, display/keyboard
// lines and the installed AI entries.
const test = require('node:test');
const assert = require('node:assert');
const path = require('node:path');
const { loadLibrary } = require('./lib/qmljs.cjs');

const F = loadLibrary(path.join(__dirname, '..', 'modules/onboarding/FinishModel.js'));
const plain = v => JSON.parse(JSON.stringify(v));
const eq = (a, b, msg) => assert.deepStrictEqual(plain(a), plain(b), msg);

const CATALOG = {
    entries: [
        { id: 'claude-code', category: 'agents', name: 'Claude Code' },
        { id: 'nodejs', category: 'agents', name: 'Node.js', hidden: true },
        { id: 'ollama', category: 'localai', name: 'Ollama' },
        { id: 'cuda', category: 'gpu', name: 'CUDA' },
        { id: 'voice', category: 'gpu', name: 'Local voice' },
        { id: 'firefox', category: 'browsers', name: 'Firefox' },
        { id: 'steam', category: 'games', name: 'Steam' },
    ],
};

test('splitInstalls: apps, AI (agents, local AI, GPU) and voice', () => {
    eq(F.splitInstalls(['firefox', 'claude-code', 'voice', 'cuda', 'ollama', 'mystery'], CATALOG),
        { apps: ['firefox', 'mystery'], ai: ['claude-code', 'cuda', 'ollama'], voice: ['voice'] });
    eq(F.splitInstalls(null, null), { apps: [], ai: [], voice: [] });
});

test('installSummary: counts and the running percent', () => {
    const status = { firefox: { state: 'installed' }, steam: { state: 'missing' }, vesktop: { state: 'missing' }, x: { state: 'missing' } };
    const progress = {
        steam: { state: 'running', percent: 40 },
        vesktop: { state: 'running', percent: 60 },
        x: { state: 'failed', reason: 'network' },
    };
    eq(F.installSummary(['firefox', 'steam', 'vesktop', 'x'], status, progress),
        { total: 4, installed: 1, installing: 2, failed: 1, percent: 50 });
    eq(F.installSummary(['steam'], status, { steam: { state: 'queued', percent: 0 } }),
        { total: 1, installed: 0, installing: 1, failed: 0, percent: -1 }, 'queued: unknown percent');
    eq(F.installSummary(['steam'], status, { steam: { state: 'done', percent: 100 } }).installed, 1, 'done counts as installed');
    eq(F.installSummary([], {}, {}), { total: 0, installed: 0, installing: 0, failed: 0, percent: -1 });
});

test('displaysLine and layoutsLine', () => {
    assert.strictEqual(F.displaysLine([
        { name: 'DP-1', enabled: true, width: 2560, height: 1440, refresh: 164.98 },
        { name: 'HDMI-A-1', enabled: false, width: 1920, height: 1080, refresh: 60 },
        { name: 'eDP-1', width: 2256, height: 1504, refresh: 60 },
    ]), '2560×1440 · 165 Hz  +1');
    assert.strictEqual(F.displaysLine([{ width: 1920, height: 1080, refresh: 60 }]), '1920×1080 · 60 Hz');
    assert.strictEqual(F.displaysLine([]), '');
    assert.strictEqual(F.layoutsLine([{ layout: 'us', variant: '' }, { layout: 'de', variant: 'nodeadkeys' }, { layout: '' }]), 'US · DE(nodeadkeys)');
    assert.strictEqual(F.layoutsLine(null), '');
});

test('installedAi: installed agents and Ollama, never hidden helpers or GPU bits', () => {
    const status = { 'claude-code': { state: 'installed' }, nodejs: { state: 'installed' }, ollama: { state: 'installed' },
        cuda: { state: 'installed' }, voice: { state: 'installed' } };
    eq(F.installedAi(CATALOG, status), ['Claude Code', 'Ollama']);
    eq(F.installedAi(CATALOG, {}), []);
});
