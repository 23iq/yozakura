const assert = require('node:assert/strict');
const { test } = require('node:test');
const { loadLibrary } = require('./lib/qmljs.cjs');
const S = loadLibrary('modules/services/ai/EngineSelection.js');

test('explicit default wins over last selection and discovery order', () => {
    assert.equal(S.initial('agent:codex', 'ollama:qwen', 'chat', 'claude'), 'agent:codex');
    assert.equal(S.initial('', 'ollama:qwen', 'chat', 'claude'), 'ollama:qwen');
    assert.equal(S.initial('', '', 'agent', 'codex'), 'agent:codex');
    assert.equal(S.initial('', '', 'shell', 'claude', 'agent:codex'), 'agent:codex');
});

test('unavailable explicit engine is retained without choosing a replacement', () => {
    assert.equal(S.resolve([{ id: 'ollama:qwen', model: 'qwen' }], 'agent:codex'), null);
    assert.equal(S.resolve([{ id: 'openai:a', model: 'a' }], 'a').id, 'openai:a');
});

test('agent attachments are preserved and unsupported images rejected', () => {
    const result = S.agentInput('Explain', [{ type: 'text', name: 'file', text: 'hello' }, { type: 'image', path: '/tmp/image.png' }], { images: true });
    assert.equal(result.prompt, '<context name="file">\nhello\n</context>\n\nExplain');
    assert.deepEqual(Array.from(result.images), ['/tmp/image.png']);
    assert.equal(S.agentInput('Explain', [{ type: 'image', path: '/tmp/image.png' }], { images: false }).error, 'images');
    assert.equal(S.agentInput('Explain', [{ type: 'image', base64: 'abc' }], { images: true }).error, 'image_path');
});

test('session list merges live state over stored history and keeps shell agents', () => {
    const result = S.sessions([{ id: 'a', title: 'Stored', updated: 1 }], [{ id: 'a', title: 'Live', busy: true, updated: 2 }], [{ id: 's', mode: 'shell', agent: 'codex', pending: 1, status: 'waiting' }], '');
    assert.equal(result.length, 2);
    assert.equal(result.find(e => e.id === 'a').title, 'Live');
    assert.equal(result.find(e => e.id === 'a').status, 'running');
    assert.equal(result.find(e => e.id === 's').pending, 1);
});
