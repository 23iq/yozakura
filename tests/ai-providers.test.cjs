const { test } = require('node:test');
const assert = require('node:assert/strict');
const path = require('node:path');
const { loadLibrary } = require('./lib/qmljs.cjs');

const P = loadLibrary(path.join(__dirname, '../modules/services/ai/Providers.js'));
const plain = v => JSON.parse(JSON.stringify(v));

function feed(provider, lines) {
    const acc = P.newAccumulator();
    let text = '';
    let thinking = '';
    let done = false;
    let error = '';
    for (const l of lines) {
        const r = P.parse(provider, l, acc);
        text += r.text;
        thinking += r.thinking;
        done = done || r.done;
        error = error || r.error;
    }
    return { text, thinking, done, error, tools: plain(P.finishTools(acc)), usage: plain(acc.usage) };
}

const tools = [{ name: 'windows_list', description: 'List windows', parameters: { type: 'object', properties: { all: { type: ['boolean', 'null'] } }, additionalProperties: false } }];
const convo = [
    { role: 'notice', content: 'ui only' },
    { role: 'user', content: 'what is open?', attachments: [{ type: 'image', mimeType: 'image/png', base64: 'AAA' }, { type: 'text', name: 'selection', text: 'sel' }] },
    { role: 'assistant', content: '', toolCalls: [{ id: 'c1', name: 'windows_list', args: { all: true } }] },
    { role: 'tool', toolCallId: 'c1', name: 'windows_list', content: '[kitty]' },
];

test('openai body: tools, images, tool round trip, inline text context', () => {
    const b = plain(P.body(convo, { provider: 'openai', model: 'gpt-5' }, tools, { system: 'sys' }));
    assert.equal(b.messages[0].role, 'system');
    assert.equal(b.messages[1].content[1].type, 'image_url');
    assert.ok(b.messages[1].content[0].text.includes('<context name="selection">'));
    assert.equal(b.messages[2].tool_calls[0].function.arguments, '{"all":true}');
    assert.equal(b.messages[3].role, 'tool');
    assert.equal(b.tools[0].function.name, 'windows_list');
    assert.equal(b.stream, true);
    assert.equal(P.endpoint({ provider: 'openai', model: 'x' }, 'k'), 'https://api.openai.com/v1/chat/completions');
    assert.equal(P.endpoint({ provider: 'groq', model: 'x' }, 'k'), 'https://api.groq.com/openai/v1/chat/completions');
    assert.equal(P.endpoint({ provider: 'custom', model: 'x', endpoint: 'http://h:1/v1' }, 'k'), 'http://h:1/v1/chat/completions');
});

test('openai stream: text, reasoning, split tool call arguments, usage', () => {
    const r = feed('openai', [
        'data: {"choices":[{"delta":{"reasoning_content":"hmm"}}]}',
        'data: {"choices":[{"delta":{"content":"Hi"}}]}',
        'data: {"choices":[{"delta":{"tool_calls":[{"index":0,"id":"call_1","function":{"name":"windows_list","arguments":"{\\"al"}}]}}]}',
        'data: {"choices":[{"delta":{"tool_calls":[{"index":0,"function":{"arguments":"l\\":true}"}}]}}]}',
        'data: {"choices":[],"usage":{"prompt_tokens":3,"completion_tokens":4}}',
        'data: [DONE]',
    ]);
    assert.equal(r.text, 'Hi');
    assert.equal(r.thinking, 'hmm');
    assert.equal(r.done, true);
    assert.deepEqual(r.tools, [{ id: 'call_1', name: 'windows_list', args: { all: true } }]);
    assert.deepEqual(r.usage, { inputTokens: 3, outputTokens: 4 });
    assert.equal(feed('openai', ['{"error":{"message":"bad key"}}']).error, 'bad key');
});

test('anthropic body + stream (incl. minimax bearer)', () => {
    const b = plain(P.body(convo, { provider: 'anthropic', model: 'claude' }, tools, { system: 'sys' }));
    assert.equal(b.system, 'sys');
    assert.equal(b.messages[0].content[0].type, 'image');
    assert.equal(b.messages[1].content[0].type, 'tool_use');
    assert.equal(b.messages[2].content[0].type, 'tool_result');
    assert.equal(b.tools[0].input_schema.type, 'object');
    assert.ok(P.headers({ provider: 'minimax' }, 'k').includes('Authorization: Bearer k'));
    assert.ok(P.headers({ provider: 'anthropic' }, 'k').includes('x-api-key: k'));
    const r = feed('anthropic', [
        'event: message_start', 'data: {"type":"message_start","message":{"usage":{"input_tokens":7}}}',
        'data: {"type":"content_block_delta","index":0,"delta":{"type":"thinking_delta","thinking":"t"}}',
        'data: {"type":"content_block_delta","index":1,"delta":{"type":"text_delta","text":"Hello"}}',
        'data: {"type":"content_block_start","index":2,"content_block":{"type":"tool_use","id":"toolu_1","name":"windows_list"}}',
        'data: {"type":"content_block_delta","index":2,"delta":{"type":"input_json_delta","partial_json":"{}"}}',
        'data: {"type":"message_delta","delta":{"stop_reason":"tool_use"},"usage":{"output_tokens":9}}',
        'data: {"type":"message_stop"}',
    ]);
    assert.equal(r.text, 'Hello');
    assert.equal(r.thinking, 't');
    assert.deepEqual(r.tools, [{ id: 'toolu_1', name: 'windows_list', args: {} }]);
    assert.deepEqual(r.usage, { inputTokens: 7, outputTokens: 9 });
});

test('gemini body (schema cleaned) + stream with function call', () => {
    const b = plain(P.body(convo, { provider: 'gemini', model: 'gemini-2.5-flash' }, tools, { system: 'sys' }));
    assert.equal(b.systemInstruction.parts[0].text, 'sys');
    assert.equal(b.contents[1].parts[0].functionCall.name, 'windows_list');
    assert.equal(b.contents[2].parts[0].functionResponse.name, 'windows_list');
    const params = b.tools[0].functionDeclarations[0].parameters;
    assert.equal(params.additionalProperties, undefined);
    assert.deepEqual(params.properties.all, { type: 'boolean', nullable: true });
    assert.ok(P.endpoint({ provider: 'gemini', model: 'm' }, 'k').endsWith(':streamGenerateContent?alt=sse'));
    const r = feed('gemini', [
        'data: {"candidates":[{"content":{"parts":[{"text":"Let me check","thought":true},{"text":"Ok"}]}}]}',
        'data: {"candidates":[{"content":{"parts":[{"functionCall":{"name":"windows_list","args":{"all":false}}}]},"finishReason":"STOP"}],"usageMetadata":{"promptTokenCount":1,"candidatesTokenCount":2}}',
    ]);
    assert.equal(r.text, 'Ok');
    assert.equal(r.thinking, 'Let me check');
    assert.equal(r.tools[0].name, 'windows_list');
    assert.deepEqual(r.tools[0].args, { all: false });
    assert.equal(r.done, true);
});

test('ollama body + ndjson stream with thinking and tool calls', () => {
    const b = plain(P.body(convo, { provider: 'ollama', model: 'qwen3.5:9b' }, tools, { system: 'sys' }));
    assert.deepEqual(b.messages[1].images, ['AAA']);
    assert.deepEqual(b.messages[2].tool_calls[0].function.arguments, { all: true });
    assert.equal(b.messages[3].tool_name, 'windows_list');
    const r = feed('ollama', [
        '{"message":{"role":"assistant","content":"","thinking":"hm"},"done":false}',
        '{"message":{"role":"assistant","content":"","tool_calls":[{"function":{"name":"windows_list","arguments":{"all":true}}}]},"done":false}',
        '{"message":{"role":"assistant","content":"done"},"done":true,"prompt_eval_count":5,"eval_count":6}',
    ]);
    assert.equal(r.thinking, 'hm');
    assert.equal(r.text, 'done');
    assert.equal(r.tools[0].name, 'windows_list');
    assert.deepEqual(r.usage, { inputTokens: 5, outputTokens: 6 });
});

test('legacy chats (role function / functionCall) convert to tool messages', () => {
    const msgs = plain(P.normalize([
        { role: 'user', content: 'x' },
        { role: 'assistant', content: '', functionCall: { name: 'run_shell_command', args: { command: 'ls' } } },
        { role: 'function', name: 'run_shell_command', content: 'out' },
        { role: 'assistant', content: '' },
    ]));
    assert.deepEqual(msgs.map(m => m.role), ['user', 'assistant', 'tool']);
    assert.equal(msgs[1].toolCalls[0].id, msgs[2].toolCallId);
});

test('model lists and malformed tool arguments', () => {
    const openai = plain(P.parseModelList('openai', JSON.stringify({ data: [{ id: 'gpt-5' }, { id: 'text-embedding-3' }, { id: 'gpt-4o-audio-preview' }, { id: 'o4-mini' }] })));
    assert.deepEqual(openai.map(m => m.id), ['gpt-5', 'o4-mini']);
    const gem = plain(P.parseModelList('gemini', JSON.stringify({ models: [{ name: 'models/gemini-2.5-flash', displayName: 'Gemini 2.5 Flash' }, { name: 'models/text-embedding-004' }] })));
    assert.deepEqual(gem.map(m => m.id), ['gemini-2.5-flash']);
    const acc = P.newAccumulator();
    P.parse('openai', 'data: {"choices":[{"delta":{"tool_calls":[{"index":0,"id":"c","function":{"name":"f","arguments":"{bad"}}]}}]}', acc);
    assert.deepEqual(plain(P.finishTools(acc))[0].args, { _raw: '{bad' });
    assert.equal(P.errorFromBody('[{\n  "error": {\n    "message": "API key not valid"\n  }\n}]'), 'API key not valid');
});

const Rows = loadLibrary(path.join(__dirname, '../modules/services/ai/ChatRows.js'));

test('chat rows: provider messages, stored file, legacy v1 import', () => {
    const rows = [
        { role: 'user', content: 'hi', attachments: '[]', toolCalls: '[]' },
        { role: 'assistant', content: '', toolCalls: JSON.stringify([{ id: 'a', name: 'f', args: {}, status: 'done', result: 'ok' }, { id: 'b', name: 'g', args: {}, status: 'ask' }]) },
        { role: 'notice', content: 'x', attachments: '[]', toolCalls: '[]' },
        { role: 'error', content: 'boom', attachments: '[]', toolCalls: '[]' },
    ];
    const msgs = plain(Rows.toMessages(rows));
    assert.deepEqual(msgs.map(m => m.role), ['user', 'assistant', 'tool']);
    assert.equal(msgs[1].toolCalls.length, 1); // unanswered calls are not sent
    assert.deepEqual(plain(Rows.toStored(rows)).map(m => m.role), ['user', 'assistant', 'notice']);
    const legacy = plain(Rows.fromStored([
        { role: 'user', content: 'ls' },
        { role: 'assistant', content: '', functionCall: { name: 'run_shell_command', args: { command: 'ls' } } },
        { role: 'function', name: 'run_shell_command', content: 'a.txt' },
    ]));
    assert.equal(legacy.length, 2);
    assert.equal(legacy[1].toolCalls[0].result, 'a.txt');
    assert.equal(plain(Rows.fromStored({ version: 2, messages: [{ role: 'system', content: 'n' }] }))[0].role, 'notice');
});

test('API keys never end up in URLs or shell scripts', () => {
    const key = 'sk-SECRET$&\'"`$(id)';
    for (const provider of ['gemini', 'openai', 'anthropic', 'mistral', 'groq', 'ollama', 'custom']) {
        const url = P.endpoint({ provider: provider, model: 'm', endpoint: 'http://x/v1' }, key);
        assert.ok(!url.includes('SECRET'), provider + ': ' + url);
    }
    assert.ok(plain(P.headers({ provider: 'gemini', model: 'm' }, key)).includes('x-goog-api-key: ' + key));
    for (const id of ['gemini', 'openai', 'anthropic', 'mistral', 'groq']) {
        const r = plain(P.modelsRequest(id, key));
        assert.ok(!r.url.includes('SECRET'), id + ': ' + r.url);
        assert.ok(r.headers.some(h => h.includes(key)), id);
    }
    // Custom curl templates get placeholders as environment variables: the
    // script text never contains the key, and $& etc. are not interpreted.
    const tpl = 'curl -sS "{{ENDPOINT}}" -H "Authorization: Bearer {{API_KEY}}" -d @{{BODY_PATH}} # {{API_KEY}}';
    const c = plain(P.customCurl(tpl, { endpoint: 'http://e/$&', apiKey: key, bodyPath: '/run/b.json' }));
    assert.equal(c.script, 'curl -sS "${AI_ENDPOINT}" -H "Authorization: Bearer ${AI_API_KEY}" -d @${AI_BODY_PATH} # ${AI_API_KEY}');
    assert.deepEqual(c.env, { AI_ENDPOINT: 'http://e/$&', AI_API_KEY: key, AI_BODY_PATH: '/run/b.json' });
});
