// Rows of the model picker (PickerModel.js).
const { test } = require('node:test');
const assert = require('node:assert/strict');
const path = require('node:path');
const { loadLibrary } = require('./lib/qmljs.cjs');

const PM = loadLibrary(path.join(__dirname, '../modules/aicenter/header/PickerModel.js'));

const models = [
    { id: 'agent:claude', name: 'Claude Code', model: 'claude', provider: 'agent', kind: 'agent' },
    { id: 'openai:gpt-5', name: 'gpt-5', model: 'gpt-5', provider: 'openai', kind: 'api' },
    { id: 'openai:gpt-4o', name: 'gpt-4o', model: 'gpt-4o', provider: 'openai', kind: 'api' },
    { id: 'anthropic:claude-sonnet-4-5', name: 'Claude Sonnet 4.5', model: 'claude-sonnet-4-5', provider: 'anthropic', kind: 'api' },
    { id: 'ollama:qwen3', name: 'qwen3', model: 'qwen3', provider: 'ollama', kind: 'local' }
];
const order = ['anthropic', 'openai', 'gemini', 'ollama', 'custom'];
const sig = rows => Array.from(rows).map(r => r.type === 'header' ? '#' + r.group : (r.type === 'provider' ? '+' + r.provider.id : r.entry.id));

test('groups: recent first, agents, then providers in preset order, default first', () => {
    const rows = PM.build(models, { recent: ['ollama:qwen3', 'openai:gpt-5'], defaultId: 'openai:gpt-4o', order, unconnected: [{ id: 'gemini', label: 'Google Gemini' }] });
    assert.deepEqual(sig(rows), ['#recent', 'ollama:qwen3', 'openai:gpt-5', '#agent', 'agent:claude', '#anthropic', 'anthropic:claude-sonnet-4-5',
        '#openai', 'openai:gpt-4o', 'openai:gpt-5', '#ollama', 'ollama:qwen3', '#unconnected', '+gemini']);
    assert.equal(rows[1].recent, true);
});

test('search matches every word over name, id and provider label', () => {
    const rows = PM.build(models, { query: 'claude sonnet', order, recent: ['anthropic:claude-sonnet-4-5'], labels: { anthropic: 'Anthropic' } });
    assert.deepEqual(sig(rows), ['#anthropic', 'anthropic:claude-sonnet-4-5']);
    assert.deepEqual(sig(PM.build(models, { query: 'anthropic', order, labels: { anthropic: 'Anthropic' } })), ['#anthropic', 'anthropic:claude-sonnet-4-5']);
    assert.deepEqual(sig(PM.build(models, { query: 'gem', order, unconnected: [{ id: 'gemini', label: 'Google Gemini' }] })), ['#unconnected', '+gemini']);
});

test('Code lists agents only and never unconnected providers', () => {
    const rows = PM.build(models, { kind: 'agent', order, unconnected: [{ id: 'gemini', label: 'Gemini' }] });
    assert.deepEqual(sig(rows), ['#agent', 'agent:claude']);
});

test('options: flat list, no recent, no unconnected', () => {
    const rows = PM.build(models, { groupByProvider: false, recent: ['openai:gpt-5'], kind: 'chat', showUnconnected: false, unconnected: [{ id: 'gemini', label: 'G' }] });
    assert.deepEqual(sig(rows), ['openai:gpt-5', 'anthropic:claude-sonnet-4-5', 'openai:gpt-4o', 'ollama:qwen3']);
    assert.ok(!sig(PM.build(models, { showRecent: false, recent: ['openai:gpt-5'], order })).includes('#recent'));
});

test('keyboard navigation skips headers', () => {
    const rows = PM.build(models, { recent: [], order, unconnected: [{ id: 'gemini', label: 'G' }] });
    const first = PM.initialIndex(rows, '');
    assert.equal(rows[first].type, 'model');
    assert.equal(rows[PM.initialIndex(rows, 'openai:gpt-4o')].entry.id, 'openai:gpt-4o');
    const next = PM.step(rows, first, 1);
    assert.equal(rows[next].entry.id, 'anthropic:claude-sonnet-4-5');
    assert.equal(PM.step(rows, first, -1), first);
    const last = PM.step(rows, rows.length - 2, 1);
    assert.equal(rows[last].type, 'provider');
});

// CLI agents expand into their own models (agents.models).
const claudeCatalog = {
    models: [
        { id: 'default', name: 'Default (recommended)', resolved: 'Opus 5.5', isDefault: true, efforts: ['low', 'high'], defaultEffort: 'high' },
        { id: 'haiku', name: 'Haiku', efforts: ['low', 'high'] },
        { id: 'sonnet', name: 'Sonnet', efforts: [] }
    ],
    manualModel: true
};
const agents = [
    { id: 'agent:claude', name: 'Claude Code', model: 'claude', agent: 'claude', provider: 'agent', kind: 'agent', available: true },
    { id: 'agent:codex', name: 'Codex', model: 'codex', agent: 'codex', provider: 'agent', kind: 'agent', available: true },
    { id: 'agent:opencode', name: 'OpenCode', model: 'opencode', agent: 'opencode', provider: 'agent', kind: 'agent', available: false }
].concat(models.slice(1));
const rowSig = rows => Array.from(rows).map(r => r.type === 'agentModel' ? '>' + r.model.id : (r.type === 'agentStatus' ? '!' + r.status : (r.type === 'agentManual' ? '?manual' : sig([r])[0])));

test('collapsed agents list no models; expanded ones list theirs, status and manual entry', () => {
    const base = { order, showRecent: false, showUnconnected: false, agentCatalogs: { claude: claudeCatalog, codex: { models: [], loading: true } } };
    const collapsed = PM.build(agents, base);
    assert.deepEqual(rowSig(collapsed).slice(0, 4), ['#agent', 'agent:claude', 'agent:codex', 'agent:opencode']);
    assert.equal(collapsed[1].expandable, true);
    assert.equal(collapsed[1].expanded, false);
    assert.equal(collapsed[3].expandable, false, 'unavailable agents do not expand');
    const open = PM.build(agents, Object.assign({}, base, { expanded: { claude: true, codex: true }, currentId: 'agent:claude', currentAgentModel: 'haiku' }));
    assert.deepEqual(rowSig(open).slice(0, 9), ['#agent', 'agent:claude', '>default', '>haiku', '>sonnet', '?manual', 'agent:codex', '!loading', 'agent:opencode']);
    assert.equal(open[1].expanded, true);
    assert.equal(open[3].current, true, 'the current agent model is marked');
    assert.equal(open[2].current, false);
    assert.equal(open[PM.initialIndex(open, 'agent:claude')].model.id, 'haiku', 'the picker opens on the current agent model');
    assert.equal(PM.step(open, 4, 1), 6, 'status and manual rows are skipped by the keyboard');
    const def = PM.build(agents, Object.assign({}, base, { expanded: { claude: true }, currentId: 'agent:claude', currentAgentModel: '' }));
    assert.equal(def.find(r => r.type === 'agentModel' && r.current).model.id, 'default', 'empty model = the agent default');
    const failed = PM.build(agents, Object.assign({}, base, { expanded: { codex: true }, agentCatalogs: { codex: { models: [], error: 'boom' } } }));
    assert.deepEqual(rowSig(failed).slice(1, 4), ['agent:claude', 'agent:codex', '!error']);
    assert.equal(failed[3].error, 'boom');
});

test('search matches agent models: "haiku" finds Claude > Haiku', () => {
    const rows = PM.build(agents, { order, query: 'haiku', agentCatalogs: { claude: claudeCatalog } });
    assert.deepEqual(rowSig(rows), ['#agent', 'agent:claude', '>haiku']);
    assert.equal(rows[1].expanded, true);
    const both = PM.build(agents, { order, query: 'claude sonnet', agentCatalogs: { claude: claudeCatalog } });
    assert.deepEqual(rowSig(both), ['#agent', 'agent:claude', '>sonnet', '#anthropic', 'anthropic:claude-sonnet-4-5']);
    const agentOnly = PM.build(agents, { order, query: 'claude code', agentCatalogs: { claude: claudeCatalog } });
    assert.deepEqual(rowSig(agentOnly), ['#agent', 'agent:claude', '>default', '>haiku', '>sonnet', '?manual']);
});

test('native id of a picked model: the default alias is left to the CLI', () => {
    const AR = loadLibrary(path.join(__dirname, '../modules/aicenter/header/AgentPickerRows.js'));
    assert.equal(AR.nativeId(claudeCatalog.models[0]), '');
    assert.equal(AR.nativeId(claudeCatalog.models[1]), 'haiku');
    assert.equal(AR.nativeId({ id: 'gpt-5.5', isDefault: true }), 'gpt-5.5', 'an explicit pick stays when the default moves');
});
