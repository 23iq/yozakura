const { test } = require('node:test');
const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');
const { loadLibrary } = require('./lib/qmljs.cjs');

const P = loadLibrary(path.join(__dirname, '../modules/services/ai/ProviderPresets.js'));
const plain = v => JSON.parse(JSON.stringify(v));

test('every spec provider has a preset', () => {
    const want = ['openai', 'anthropic', 'gemini', 'mistral', 'groq', 'minimax', 'openrouter', 'lmstudio', 'deepseek', 'custom', 'ollama'];
    assert.deepEqual(plain(P.ids()).sort(), want.slice().sort());
});

test('presets are complete and consistent', () => {
    for (const p of P.PRESETS) {
        assert.ok(p.label, p.id);
        assert.ok(['openai', 'anthropic', 'gemini', 'ollama'].includes(p.family), p.id);
        if (p.icon)
            assert.ok(fs.existsSync(path.join(__dirname, '../assets/aiproviders', p.icon)), `${p.id}: icon ${p.icon}`);
        if (p.keyRequired) {
            assert.match(p.keyUrl, /^https:\/\//, p.id);
            assert.match(p.keyId, /^[A-Z_]+_API_KEY$/, p.id);
        }
        if (p.id !== 'custom')
            assert.match(p.baseUrl, /^https?:\/\//, p.id);
        if (p.local)
            assert.equal(p.keyRequired, false, p.id);
    }
    assert.equal(P.preset('lmstudio').baseUrl, 'http://127.0.0.1:1234/v1');
    assert.equal(P.preset('ollama').baseUrl, 'http://127.0.0.1:11434');
});

test('lookups', () => {
    assert.equal(P.preset('nope'), null);
    assert.equal(P.family('minimax'), 'anthropic');
    assert.equal(P.family('unknown'), 'openai');
    assert.equal(P.effortFamily('openrouter'), 'openrouter');
    assert.equal(P.effortFamily('gemini'), 'gemini');
    assert.equal(P.needsKey('openai'), true);
    assert.equal(P.needsKey('ollama'), false);
    assert.equal(P.isConnected('openai', '', ''), false);
    assert.equal(P.isConnected('openai', 'sk-1', ''), true);
    assert.equal(P.isConnected('lmstudio', '', ''), true);
    assert.equal(P.isConnected('custom', '', ''), false);
    assert.equal(P.isConnected('custom', '', 'http://x/v1'), true);
    const order = plain(P.sorted()).map(p => p.id);
    assert.equal(order[order.length - 1], 'custom');
    assert.ok(order.indexOf('ollama') > order.indexOf('openrouter'));
    assert.equal(order[0], 'anthropic');
});
