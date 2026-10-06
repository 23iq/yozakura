// Effort, num_ctx and tool support in Providers.body() request bodies, per
// provider family (no network).
const { test } = require('node:test');
const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');
const { loadLibrary } = require('./lib/qmljs.cjs');

const P = loadLibrary(path.join(__dirname, '../modules/services/ai/Providers.js'));
const MI = loadLibrary(path.join(__dirname, '../modules/services/ai/ModelInfo.js'));
const plain = v => JSON.parse(JSON.stringify(v));
const table = JSON.parse(fs.readFileSync(path.join(__dirname, '../assets/ai/models.json'), 'utf8'));
const model = (provider, id, extra) => Object.assign({ provider, model: id, info: MI.lookup(table, provider, id) }, extra || {});
const msgs = [{ role: 'user', content: 'hi' }];
const tools = [{ name: 'timer_start', description: 'Start a timer', parameters: { type: 'object', properties: {} } }];

test('OpenAI: reasoning_effort, off maps to the model value', () => {
    const m = model('openai', 'gpt-5');
    assert.equal(P.body(msgs, m, [], { effort: 'high' }).reasoning_effort, 'high');
    assert.equal(P.body(msgs, m, [], { effort: 'off' }).reasoning_effort, 'minimal');
    // no effort -> nothing sent
    assert.equal(P.body(msgs, m, [], {}).reasoning_effort, undefined);
    // a model without reasoning ignores the level
    assert.equal(P.body(msgs, model('openai', 'gpt-4o'), [], { effort: 'high' }).reasoning_effort, undefined);
    assert.deepEqual(plain(P.body(msgs, m, [], {}).stream_options), { include_usage: true });
});

test('Anthropic: thinking budget, max_tokens above it, no temperature', () => {
    const b = P.body(msgs, model('anthropic', 'claude-sonnet-4-5'), [], { effort: 'medium', temperature: 0.7 });
    assert.deepEqual(plain(b.thinking), { type: 'enabled', budget_tokens: 8192 });
    assert.ok(b.max_tokens > 8192);
    assert.equal(b.temperature, undefined);
    const off = P.body(msgs, model('anthropic', 'claude-sonnet-4-5'), [], { effort: 'off' });
    assert.equal(off.thinking, undefined);
    assert.equal(P.body(msgs, model('anthropic', 'claude-3-5-haiku'), [], { effort: 'high' }).thinking, undefined);
});

test('Anthropic tool loops hand the signed thinking block back first', () => {
    const conv = [
        { role: 'user', content: 'start a timer' },
        { role: 'assistant', content: '', thinking: 'need the tool', signature: 'sig==', toolCalls: [{ id: 't1', name: 'timer_start', args: {} }] },
        { role: 'tool', toolCallId: 't1', name: 'timer_start', content: 'ok' }
    ];
    const b = P.body(conv, model('anthropic', 'claude-sonnet-4-5'), tools, { effort: 'low' });
    const assistant = b.messages[1];
    assert.equal(assistant.role, 'assistant');
    assert.deepEqual(plain(assistant.content[0]), { type: 'thinking', thinking: 'need the tool', signature: 'sig==' });
    assert.equal(assistant.content[1].type, 'tool_use');
    // without a signature (other providers, old chats) no thinking block
    const noSig = P.body([conv[0], Object.assign({}, conv[1], { signature: '' }), conv[2]], model('anthropic', 'claude-sonnet-4-5'), tools, {});
    assert.equal(noSig.messages[1].content[0].type, 'tool_use');
});

test('Anthropic stream: signature deltas and cache tokens are collected', () => {
    const acc = P.newAccumulator();
    P.parse('anthropic', 'data: {"type":"message_start","message":{"usage":{"input_tokens":10,"cache_read_input_tokens":1000,"cache_creation_input_tokens":50}}}', acc);
    P.parse('anthropic', 'data: {"type":"content_block_delta","index":0,"delta":{"type":"signature_delta","signature":"abc"}}', acc);
    P.parse('anthropic', 'data: {"type":"content_block_delta","index":0,"delta":{"type":"signature_delta","signature":"def"}}', acc);
    assert.equal(acc.signature, 'abcdef');
    assert.equal(acc.usage.inputTokens, 1060);
    assert.equal(acc.usage.cachedTokens, 1000);
});

test('Gemini: thinkingBudget per level, Gemini 3 thinkingLevel', () => {
    const flash = P.body(msgs, model('gemini', 'gemini-2.5-flash'), [], { effort: 'low' });
    assert.deepEqual(plain(flash.generationConfig.thinkingConfig), { thinkingBudget: 1024, includeThoughts: true });
    const flashOff = P.body(msgs, model('gemini', 'gemini-2.5-flash'), [], { effort: 'off' });
    assert.deepEqual(plain(flashOff.generationConfig.thinkingConfig), { thinkingBudget: 0 });
    const g3 = P.body(msgs, model('gemini', 'gemini-3-pro-preview'), [], { effort: 'high' });
    assert.equal(g3.generationConfig.thinkingConfig.thinkingLevel, 'high');
});

test('Ollama: think flag, gpt-oss levels and num_ctx', () => {
    const qwen = { provider: 'ollama', model: 'qwen3:8b', info: MI.fromOllama({ id: 'qwen3:8b', family: 'qwen3', capabilities: ['completion', 'tools', 'thinking'], contextLength: 40960, detailed: true }) };
    assert.equal(P.body(msgs, qwen, [], { effort: 'off' }).think, false);
    assert.equal(P.body(msgs, qwen, [], { effort: 'high' }).think, true);
    assert.deepEqual(plain(P.body(msgs, qwen, [], { numCtx: 32768 }).options), { num_ctx: 32768 });
    assert.equal(P.body(msgs, qwen, [], {}).options, undefined);
    const oss = { provider: 'ollama', model: 'gpt-oss:20b', info: MI.fromOllama({ id: 'gpt-oss:20b', family: 'gptoss', capabilities: ['completion', 'tools', 'thinking'], detailed: true }) };
    assert.equal(P.body(msgs, oss, [], { effort: 'low' }).think, 'low');
});

test('OpenRouter: reasoning object; usage requested', () => {
    const m = model('openrouter', 'openai/gpt-5');
    const b = P.body(msgs, m, [], { effort: 'high' });
    assert.deepEqual(plain(b.reasoning), { effort: 'high' });
    assert.deepEqual(plain(b.stream_options), { include_usage: true });
    const claude = P.body(msgs, model('openrouter', 'anthropic/claude-sonnet-4.5'), [], { effort: 'low' });
    assert.deepEqual(plain(claude.reasoning), { max_tokens: 2048 });
    assert.equal(P.endpoint(m, 'k'), 'https://openrouter.ai/api/v1/chat/completions');
});

test('Models without tool support get no tools (chat only)', () => {
    const chatOnly = { provider: 'ollama', model: 'gemma3:4b', tools: false, info: MI.fromOllama({ id: 'gemma3:4b', capabilities: ['completion', 'vision'], detailed: true }) };
    assert.equal(P.supportsTools(chatOnly), false);
    assert.equal(P.body(msgs, chatOnly, tools, {}).tools, undefined);
    // info alone is enough
    const infoOnly = { provider: 'ollama', model: 'x', info: { tools: false } };
    assert.equal(P.body(msgs, infoOnly, tools, {}).tools, undefined);
    const withTools = { provider: 'ollama', model: 'qwen3', info: { tools: true } };
    assert.equal(P.body(msgs, withTools, tools, {}).tools.length, 1);
    // unknown capability -> tools are still offered
    assert.equal(P.body(msgs, { provider: 'openai', model: 'mystery' }, tools, {}).tools.length, 1);
});
