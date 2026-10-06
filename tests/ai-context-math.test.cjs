// Context window arithmetic (ContextMath.js).
const { test } = require('node:test');
const assert = require('node:assert/strict');
const path = require('node:path');
const { loadLibrary } = require('./lib/qmljs.cjs');

const M = loadLibrary(path.join(__dirname, '../modules/services/ai/ContextMath.js'));

test('fraction and level', () => {
    assert.equal(M.fraction(50, 200), 0.25);
    assert.equal(M.fraction(500, 200), 1);
    assert.equal(M.fraction(10, 0), 0);
    assert.equal(M.level(0.5, 80, 95), 'ok');
    assert.equal(M.level(0.8, 80, 95), 'warn');
    assert.equal(M.level(0.95, 80, 95), 'critical');
    assert.equal(M.level(0.7, 60, 90), 'warn');
});

test('compact labels', () => {
    assert.equal(M.short(950), '950');
    assert.equal(M.short(1234), '1.2k');
    assert.equal(M.short(1000), '1k');
    assert.equal(M.short(62200), '62k');
    assert.equal(M.short(200000), '200k');
    assert.equal(M.short(1048576), '1M');
    assert.equal(M.short(1047576), '1.05M');
    assert.equal(M.short(2000000), '2M');
    assert.equal(M.label(62200, 200000), '62k/200k');
    assert.equal(M.short(32768), '32k');
    assert.equal(M.short(131072), '128k');
    assert.equal(M.short(262144), '256k');
});

test('Ollama num_ctx: model maximum capped by the setting', () => {
    assert.equal(M.numCtx(262144, 32768), 32768);
    assert.equal(M.numCtx(8192, 32768), 8192);
    assert.equal(M.numCtx(0, 32768), 32768);
    assert.equal(M.numCtx(131072, 0), 131072);
    assert.equal(M.numCtx(0, 0), 0);
});

test('window of a model: override > Ollama allocation > table', () => {
    const gpt = { id: 'openai:gpt-5', model: 'gpt-5', provider: 'openai', info: { contextWindow: 400000 } };
    assert.deepEqual(JSON.parse(JSON.stringify(M.windowFor(gpt, [], 32768))), { window: 400000, source: 'table' });
    assert.equal(M.windowFor(gpt, [{ model: 'GPT-5', contextWindow: 272000 }], 0).window, 272000);
    assert.equal(M.windowFor(gpt, [{ model: 'openai:gpt-5', contextWindow: 100000 }], 0).source, 'override');
    const ollama = { id: 'ollama:qwen3', model: 'qwen3', provider: 'ollama', info: { contextWindow: 262144 } };
    assert.deepEqual(JSON.parse(JSON.stringify(M.windowFor(ollama, [], 32768))), { window: 32768, source: 'ollama' });
    assert.equal(M.windowFor({ id: 'x', model: 'x', provider: 'custom', info: {} }, [], 0).window, 0);
    assert.equal(M.windowFor(null, [], 0).window, 0);
});

test('usage and estimates', () => {
    assert.equal(M.usedFromUsage({ inputTokens: 1000, outputTokens: 200 }), 1200);
    assert.equal(M.usedFromUsage(null), 0);
    const est = M.estimateTokens([{ role: 'user', content: 'x'.repeat(400) }, { role: 'assistant', content: 'y'.repeat(40), toolCalls: [{ name: 'n', args: { a: 1 } }] }], 'sys!');
    assert.ok(est >= 110 && est <= 115, String(est));
});
