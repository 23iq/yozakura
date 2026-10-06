const { test } = require('node:test');
const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');
const { loadLibrary } = require('./lib/qmljs.cjs');

const E = loadLibrary(path.join(__dirname, '../modules/services/ai/Effort.js'));
const plain = v => JSON.parse(JSON.stringify(v));
const table = JSON.parse(fs.readFileSync(path.join(__dirname, '../assets/ai/models.json'), 'utf8'));
const entry = (prov, prefix) => table.providers[prov].find(e => e.prefix === prefix);

const gpt5 = entry('openai', 'gpt-5');
const gpt52 = entry('openai', 'gpt-5.2');
const o3 = entry('openai', 'o3');
const sonnet = entry('anthropic', 'claude-sonnet-4');
const haiku35 = entry('anthropic', 'claude-3-5-haiku');
const pro25 = entry('gemini', 'gemini-2.5-pro');
const flash25 = entry('gemini', 'gemini-2.5-flash');
const gemini3 = entry('gemini', 'gemini-3');
const qwenOllama = { id: 'qwen3:8b', family: 'qwen3', capabilities: ['completion', 'tools', 'thinking'] };
const gptOssOllama = { id: 'gpt-oss:20b', family: 'gptoss', capabilities: ['completion', 'tools', 'thinking'] };
const llamaOllama = { id: 'llama3.2', family: 'llama', capabilities: ['completion', 'tools'] };

test('levelsFor follows the model capabilities', () => {
    assert.deepEqual(plain(E.levelsFor(gpt5)), ['off', 'low', 'medium', 'high']);
    assert.deepEqual(plain(E.levelsFor(gpt52)), ['off', 'low', 'medium', 'high', 'max']);
    assert.deepEqual(plain(E.levelsFor(o3)), ['low', 'medium', 'high']);
    assert.deepEqual(plain(E.levelsFor(sonnet)), ['off', 'low', 'medium', 'high', 'max']);
    assert.deepEqual(plain(E.levelsFor(haiku35)), []);
    assert.deepEqual(plain(E.levelsFor(pro25)), ['low', 'medium', 'high', 'max']);
    assert.deepEqual(plain(E.levelsFor(flash25)), ['off', 'low', 'medium', 'high', 'max']);
    assert.deepEqual(plain(E.levelsFor(gemini3)), ['low', 'high']);
    assert.deepEqual(plain(E.levelsFor(qwenOllama)), ['off', 'high']);
    assert.deepEqual(plain(E.levelsFor(gptOssOllama)), ['low', 'medium', 'high']);
    assert.deepEqual(plain(E.levelsFor(llamaOllama)), []);
    assert.deepEqual(plain(E.levelsFor(null)), []);
    assert.deepEqual(plain(E.levelsFor({ reasoning: 'anthropic_budget' })), ['off', 'low', 'medium', 'high', 'max']);
});

test('defaultLevel and resolve pick supported levels', () => {
    assert.equal(E.defaultLevel(gpt5), 'medium');
    assert.equal(E.defaultLevel(gemini3), 'high');
    assert.equal(E.defaultLevel(haiku35), '');
    assert.equal(E.resolve('max', o3), 'high');
    assert.equal(E.resolve('off', o3), '');
    assert.equal(E.resolve('medium', gemini3), 'low');
    assert.equal(E.resolve('low', qwenOllama), 'high');
    assert.equal(E.resolve('bogus', gpt5), '');
    assert.equal(E.resolve('HIGH', gpt5), 'high');
});

test('OpenAI reasoning_effort', () => {
    assert.deepEqual(plain(E.params('openai', 'high', gpt5)), { reasoning_effort: 'high' });
    assert.deepEqual(plain(E.params('openai', 'off', gpt5)), { reasoning_effort: 'minimal' });
    assert.deepEqual(plain(E.params('openai', 'off', gpt52)), { reasoning_effort: 'none' });
    assert.deepEqual(plain(E.params('openai', 'max', gpt52)), { reasoning_effort: 'xhigh' });
    assert.deepEqual(plain(E.params('openai', 'off', o3)), {});
    assert.deepEqual(plain(E.params('openai', 'high', entry('openai', 'gpt-4o'))), {});
    const groqQwen = entry('groq', 'qwen/qwen3-32b');
    assert.deepEqual(plain(E.params('openai', 'off', groqQwen)), { reasoning_effort: 'none' });
    assert.deepEqual(plain(E.params('openai', 'high', groqQwen)), { reasoning_effort: 'default' });
});

test('Anthropic thinking budget and max_tokens', () => {
    assert.deepEqual(plain(E.params('anthropic', 'off', sonnet)), {});
    assert.deepEqual(plain(E.params('anthropic', 'low', sonnet)), { thinking: { type: 'enabled', budget_tokens: 2048 } });
    assert.deepEqual(plain(E.params('anthropic', 'max', sonnet)), { thinking: { type: 'enabled', budget_tokens: 32768 } });
    // Opus 4 has 32k output: max budget leaves room for the answer.
    const opus = entry('anthropic', 'claude-opus-4');
    assert.equal(E.params('anthropic', 'max', opus).thinking.budget_tokens, 32000 - 4096);

    const body = { model: 'claude-sonnet-4-5', max_tokens: 8192, temperature: 0.3, stream: true };
    const out = plain(E.apply(body, 'anthropic', 'high', sonnet));
    assert.equal(out.thinking.budget_tokens, 16384);
    assert.ok(out.max_tokens > out.thinking.budget_tokens);
    assert.equal(out.temperature, undefined);
    assert.equal(body.temperature, 0.3, 'input body untouched');
    const opusOut = plain(E.apply({ max_tokens: 8192 }, 'anthropic', 'max', opus));
    assert.equal(opusOut.max_tokens, 32000);
    assert.ok(opusOut.max_tokens > opusOut.thinking.budget_tokens);
    assert.deepEqual(plain(E.apply({ max_tokens: 100, temperature: 1 }, 'anthropic', 'off', sonnet)), { max_tokens: 100, temperature: 1 });
});

test('Gemini thinking config', () => {
    assert.deepEqual(plain(E.params('gemini', 'off', flash25)), { generationConfig: { thinkingConfig: { thinkingBudget: 0 } } });
    assert.deepEqual(plain(E.params('gemini', 'off', pro25)), {}, 'pro cannot turn thinking off');
    assert.equal(E.params('gemini', 'max', flash25).generationConfig.thinkingConfig.thinkingBudget, 24576);
    assert.equal(E.params('gemini', 'max', pro25).generationConfig.thinkingConfig.thinkingBudget, 32768);
    assert.equal(E.params('gemini', 'low', entry('gemini', 'gemini-2.5-flash-lite')).generationConfig.thinkingConfig.thinkingBudget, 1024);
    assert.deepEqual(plain(E.params('gemini', 'high', gemini3)), { generationConfig: { thinkingConfig: { thinkingLevel: 'high', includeThoughts: true } } });
    const merged = plain(E.apply({ contents: [], generationConfig: { temperature: 0.5 } }, 'gemini', 'medium', flash25));
    assert.deepEqual(merged.generationConfig, { temperature: 0.5, thinkingConfig: { thinkingBudget: 8192, includeThoughts: true } });
});

test('Ollama think', () => {
    assert.deepEqual(plain(E.params('ollama', 'off', qwenOllama)), { think: false });
    assert.deepEqual(plain(E.params('ollama', 'high', qwenOllama)), { think: true });
    assert.deepEqual(plain(E.params('ollama', 'low', gptOssOllama)), { think: 'low' });
    assert.deepEqual(plain(E.params('ollama', 'max', gptOssOllama)), { think: 'high' });
    assert.deepEqual(plain(E.params('ollama', 'off', gptOssOllama)), {});
    assert.deepEqual(plain(E.params('ollama', 'high', llamaOllama)), {});
});

test('OpenRouter unified reasoning object', () => {
    assert.deepEqual(plain(E.params('openrouter', 'high', gpt5)), { reasoning: { effort: 'high' } });
    assert.deepEqual(plain(E.params('openrouter', 'medium', sonnet)), { reasoning: { max_tokens: 8192 } });
    assert.deepEqual(plain(E.params('openrouter', 'low', pro25)), { reasoning: { max_tokens: 1024 } });
    assert.deepEqual(plain(E.params('openrouter', 'off', sonnet)), {});
});
