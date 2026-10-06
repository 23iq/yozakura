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
