// Model capability records (ModelInfo.js) and per-model effort choice
// (EffortPrefs.js).
const { test } = require('node:test');
const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');
const { loadLibrary } = require('./lib/qmljs.cjs');

const MI = loadLibrary(path.join(__dirname, '../modules/services/ai/ModelInfo.js'));
const EP = loadLibrary(path.join(__dirname, '../modules/services/ai/EffortPrefs.js'));
const table = JSON.parse(fs.readFileSync(path.join(__dirname, '../assets/ai/models.json'), 'utf8'));
const plain = v => JSON.parse(JSON.stringify(v));

test('lookup: longest prefix, vendor tables, :free, open models', () => {
    assert.equal(MI.lookup(table, 'openai', 'gpt-5-mini').prefix.startsWith('gpt-5'), true);
    assert.equal(MI.lookup(table, 'anthropic', 'claude-opus-4-5-20251101').prefix, 'claude-opus-4-5');
    assert.equal(MI.lookup(table, 'openrouter', 'anthropic/claude-sonnet-4.5').prefix, 'claude-sonnet-4');
    assert.equal(MI.lookup(table, 'openrouter', 'openai/gpt-oss-120b:free').prefix, 'gpt-oss');
    assert.equal(MI.lookup(table, 'openrouter', 'google/gemini-2.5-pro').contextWindow, 1048576);
    assert.equal(MI.lookup(table, 'openai', 'totally-unknown'), null);
    assert.equal(MI.lookup(null, 'openai', 'gpt-5'), null);
});

test('Ollama probe records', () => {
    const full = MI.fromOllama({ id: 'qwen3.5:9b', family: 'qwen35', contextLength: 262144, capabilities: ['completion', 'tools', 'vision', 'thinking'], detailed: true });
    assert.equal(full.tools, true);
    assert.equal(full.vision, true);
    assert.equal(full.reasoning, 'ollama_think');
    assert.equal(full.contextWindow, 262144);
    const chatOnly = MI.fromOllama({ id: 'gemma', capabilities: ['completion'], detailed: true });
    assert.equal(chatOnly.tools, false);
    assert.equal(chatOnly.reasoning, 'none');
    // /api/show failed: capabilities unknown, not "no tools"
    const unknown = MI.fromOllama({ id: 'x', capabilities: [], detailed: false });
    assert.equal(unknown.tools, undefined);
});

test('badges', () => {
    const kinds = info => Array.from(MI.badges(info)).map(b => b.kind);
    assert.deepEqual(kinds(MI.lookup(table, 'anthropic', 'claude-sonnet-4-5')), ['tools', 'vision', 'thinking', 'context']);
    assert.equal(MI.badges(MI.lookup(table, 'anthropic', 'claude-sonnet-4-5')).find(b => b.kind === 'context').text, '200k');
    assert.deepEqual(kinds({ tools: false, contextWindow: 8192 }), ['chatOnly', 'context']);
    assert.deepEqual(kinds(null), []);
});

test('effort per model: remembered > setting > auto (send nothing)', () => {
    const sonnet = { id: 'anthropic:claude-sonnet-4-5', kind: 'api', info: MI.lookup(table, 'anthropic', 'claude-sonnet-4-5') };
    const o3 = { id: 'openai:o3', kind: 'api', info: MI.lookup(table, 'openai', 'o3') };
    const plainModel = { id: 'openai:gpt-4o', kind: 'api', info: MI.lookup(table, 'openai', 'gpt-4o') };
    assert.deepEqual(plain(EP.httpLevels(sonnet)), ['off', 'low', 'medium', 'high', 'max']);
    assert.deepEqual(plain(EP.httpLevels(plainModel)), []);
    assert.equal(EP.httpLevel(sonnet, {}, 'auto'), '');
    assert.equal(EP.httpLevel(sonnet, {}, 'high'), 'high');
    assert.equal(EP.httpLevel(sonnet, { 'anthropic:claude-sonnet-4-5': 'low' }, 'high'), 'low');
    assert.equal(EP.httpLevel(sonnet, { 'anthropic:claude-sonnet-4-5': 'auto' }, 'high'), '');
    // unsupported levels resolve to the closest supported one
    assert.equal(EP.httpLevel(o3, {}, 'max'), 'high');
    assert.equal(EP.httpLevel(o3, {}, 'off'), '');
    assert.equal(EP.httpLevel(plainModel, {}, 'high'), '');
});

test('agent efforts come from the agent catalog, remembered per native model', () => {
    const catalog = { models: [{ id: 'gpt-5.5', isDefault: true, efforts: ['low', 'medium', 'high', 'xhigh'], defaultEffort: 'medium' }, { id: 'gpt-5.5-mini', efforts: ['low', 'high'] }] };
    assert.deepEqual(plain(EP.agentLevels(catalog, '')), ['low', 'medium', 'high', 'xhigh']);
    assert.deepEqual(plain(EP.agentLevels(catalog, 'gpt-5.5-mini')), ['low', 'high']);
    assert.equal(EP.agentDefault(catalog, ''), 'medium');
    const codex = { kind: 'agent', agent: 'codex', id: 'agent:codex' };
    assert.equal(EP.memoryKey(codex, ''), 'agent:codex/default');
    assert.equal(EP.memoryKey(codex, 'gpt-5.5'), 'agent:codex/gpt-5.5');
    let mem = EP.remember({}, 'agent:codex/gpt-5.5', 'xhigh');
    assert.equal(EP.remembered(mem, 'codex', 'gpt-5.5'), 'xhigh');
    assert.equal(EP.remembered(mem, 'codex', ''), null);
    mem = EP.remember(mem, 'agent:codex/default', '');
    assert.equal(EP.remembered(mem, 'codex', ''), '');
});

test('the model an agent will use is known before the first turn', () => {
    const codex = { models: [{ id: 'gpt-5.5', name: 'GPT-5.5', isDefault: true }, { id: 'gpt-5.5-mini', name: 'GPT-5.5 mini' }] };
    assert.equal(EP.agentModelLabel(codex, ''), 'GPT-5.5');
    assert.equal(EP.agentModelLabel(codex, 'gpt-5.5-mini'), 'GPT-5.5 mini');
    const claude = { models: [{ id: 'default', name: 'Default (recommended)', isDefault: true, resolved: 'Opus 5.5' }, { id: 'sonnet', name: 'Sonnet 5.5' }] };
    assert.equal(EP.agentModelLabel(claude, ''), 'Opus 5.5');
    assert.equal(EP.agentModelLabel(claude, 'default'), 'Opus 5.5');
    // a manual model id not in the catalog, and a catalog still loading
    assert.equal(EP.agentModelLabel(claude, 'claude-x'), 'claude-x');
    assert.equal(EP.agentModelLabel({ models: [] }, ''), '');
});
