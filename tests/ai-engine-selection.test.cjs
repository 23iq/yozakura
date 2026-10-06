const assert = require('node:assert/strict');
const { test } = require('node:test');
const { loadLibrary } = require('./lib/qmljs.cjs');
const S = loadLibrary('modules/services/ai/EngineSelection.js');

test('explicit default wins over last selection and discovery order', () => {
    assert.equal(S.initial('agent:codex', 'ollama:qwen'), 'agent:codex');
    assert.equal(S.initial('', 'ollama:qwen'), 'ollama:qwen');
    assert.equal(S.initial('', ''), '');
});

test('code space starts with the last agent or the default agent', () => {
    assert.equal(S.initialCode('agent:codex', 'claude'), 'agent:codex');
    assert.equal(S.initialCode('openai:gpt', 'claude'), 'agent:claude');
    assert.equal(S.initialCode('', ''), 'agent:claude');
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

test('history is split by space: chats and assistant agents vs project agents', () => {
    const stored = [{ id: 'c', title: 'Chat', updated: 5, mode: 'shell' }];
    const agents = [
        { id: 'a', mode: 'assistant', agent: 'claude', cwd: '/home/u', updated: 4 },
        { id: 'l', mode: 'shell', agent: 'codex', cwd: '/home/u', updated: 3 },
        { id: 'p', mode: 'agent', agent: 'codex', cwd: '/src/web', updated: 2 },
        { id: 'q', mode: 'agent', agent: 'claude', cwd: '/src/yoz', updated: 6 },
        { id: 'r', mode: 'agent', agent: 'claude', cwd: '/src/web', updated: 1 }
    ];
    const ids = list => JSON.parse(JSON.stringify(list)).map(e => e.id);
    assert.deepEqual(ids(S.sessions(stored, [], agents, '', 'assistant')), ['c', 'a', 'l']);
    const code = S.sessions(stored, [], agents, '', 'code');
    assert.deepEqual(ids(code), ['q', 'p', 'r']);
    assert.equal(S.sessions(stored, [], agents, '').length, 6);
    assert.ok(code[0].subtitle.includes('/src/yoz'));
    assert.ok(!S.sessions(stored, [], agents, '', 'assistant')[1].subtitle.includes('/home/u'));
    const groups = JSON.parse(JSON.stringify(S.byProject(code)));
    assert.deepEqual(groups.map(g => [g.name, g.entries.map(e => e.id)]), [['yoz', ['q']], ['web', ['p', 'r']]]);
    const rows = JSON.parse(JSON.stringify(S.projectRows(code)));
    assert.deepEqual(rows.map(r => r.header ? '#' + r.name : r.id), ['#yoz', 'q', '#web', 'p', 'r']);
    assert.equal(S.spaceOf({ kind: 'chat' }), 'assistant');
    assert.equal(S.spaceOf({ kind: 'agent', mode: '' }), 'code');
});
