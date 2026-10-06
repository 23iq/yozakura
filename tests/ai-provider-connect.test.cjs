const { test } = require('node:test');
const assert = require('node:assert/strict');
const path = require('node:path');
const { loadLibrary } = require('./lib/qmljs.cjs');

const lib = name => loadLibrary(path.join(__dirname, '../modules/services/ai', name));
const C = lib('ProviderConnect.js');
const R = lib('RequestPolicy.js');
const P = lib('Providers.js');
const plain = v => JSON.parse(JSON.stringify(v));

test('connected means: key for cloud providers, endpoint for custom, reachable for local servers', () => {
    const keys = { openai: { api_key: 'sk-1', endpoint: '' }, custom: { api_key: '', endpoint: 'http://box:8000/v1' }, gemini: { api_key: '' } };
    const state = { keys, ollama: { reachable: true }, lmstudio: { reachable: false, endpoint: 'http://127.0.0.1:1234/v1', error: 'connection refused' }, hidden: [] };
    assert.equal(C.status('openai', state).state, 'connected');
    assert.equal(C.status('gemini', state).state, 'none');
    assert.equal(C.status('custom', state).connected, true);
    assert.equal(C.status('ollama', state).connected, true);
    assert.deepEqual(plain(C.status('lmstudio', state)), { state: 'offline', connected: false, local: true });
    assert.equal(C.status('lmstudio', { keys }).state, 'none', 'never probed');
    assert.equal(C.status('openai', Object.assign({}, state, { hidden: ['openai'] })).state, 'hidden');
});

test('no fake key: an old "ollama: enabled" entry does not make Ollama connected', () => {
    const state = { keys: { ollama: { api_key: 'enabled', endpoint: '' } }, ollama: { reachable: false } };
    assert.equal(C.status('ollama', state).connected, false);
});

test('unconnected lists presets without a connection, minus hidden and listed ones', () => {
    const state = { keys: { openai: { api_key: 'k' } }, ollama: { reachable: true }, lmstudio: {}, hidden: ['minimax'] };
    const ids = plain(C.unconnected(state, { groq: true })).map(p => p.id);
    assert.ok(!ids.includes('openai') && !ids.includes('ollama') && !ids.includes('minimax') && !ids.includes('groq'));
    assert.ok(ids.includes('anthropic') && ids.includes('lmstudio') && ids.includes('custom') && ids.includes('deepseek') && ids.includes('openrouter'));
    assert.equal(ids[ids.length - 1], 'custom', 'remote, then local, then custom');
});

test('validation of the form', () => {
    assert.equal(C.validate('openai', '', ''), 'ai.connect.need_key');
    assert.equal(C.validate('openai', ' sk ', ''), '');
    assert.equal(C.validate('custom', '', ''), 'ai.connect.need_url');
    assert.equal(C.validate('custom', '', 'box:8000'), 'ai.connect.bad_url');
    assert.equal(C.validate('custom', '', 'http://box:8000/v1'), '');
    assert.equal(C.validate('ollama', '', ''), '', 'local providers need nothing');
    assert.equal(C.validate('lmstudio', '', 'ftp://x'), 'ai.connect.bad_url');
});

test('test call: Ollama is probed, others use the free listing test', () => {
    assert.deepEqual(plain(C.testCall('ollama', '', ' http://gpu:11434 ')), { method: 'providers.ollama.probe', params: { endpoint: 'http://gpu:11434' } });
    assert.deepEqual(plain(C.testCall('openai', ' sk ', '')), { method: 'providers.test', params: { provider: 'openai', baseUrl: '', key: 'sk' } });
    assert.deepEqual(plain(C.testCall('custom', '', 'http://h/v1', { 'X-T': '1' })).params.headers, { 'X-T': '1' });
});

test('summaries: listing, unverified MiniMax, errors and Ollama probes with capabilities', () => {
    const ok = C.summarize('openai', { ok: true, verified: true, error: '', models: [{ id: 'a' }, { id: 'b' }] }, null);
    assert.equal(ok.ok, true);
    assert.equal(ok.count, 2);
    const mm = C.summarize('minimax', { ok: true, verified: false, models: [] }, null);
    assert.equal(mm.ok, true);
    assert.equal(mm.verified, false);
    const bad = C.summarize('openai', { ok: false, error: 'HTTP 401: Incorrect API key provided: ***', models: [] }, null);
    assert.equal(bad.ok, false);
    assert.match(bad.error, /401/);
    assert.equal(C.summarize('openai', null, 'socket closed').error, 'socket closed');
    const probe = { reachable: true, version: '0.35.0', models: [
        { id: 'qwen3.5:9b', capabilities: ['completion', 'tools'] },
        { id: 'nomic-embed-text', capabilities: ['embedding'] }] };
    const s = C.summarize('ollama', probe, null);
    assert.equal(s.ok, true);
    assert.equal(s.count, 1, 'embedding-only models are not chat models');
    assert.equal(s.models[0].probe.capabilities[1], 'tools');
    assert.equal(s.version, '0.35.0');
    assert.equal(C.summarize('ollama', { reachable: false, error: 'connection refused' }, null).error, 'connection refused');
});

test('save plan: keys in the keystore, local endpoints in the config', () => {
    assert.deepEqual(plain(C.savePlan('openai', ' sk ', 'https://api.openai.com/v1', '')), { keystore: { provider: 'openai', key: 'sk', endpoint: '', curl: '' }, config: null });
    assert.equal(C.savePlan('openai', 'sk', 'https://proxy/v1', '').keystore.endpoint, 'https://proxy/v1');
    assert.deepEqual(plain(C.savePlan('custom', '', 'http://box:8000/v1/', 'curl $AI_ENDPOINT')).keystore, { provider: 'custom', key: '', endpoint: 'http://box:8000/v1', curl: 'curl $AI_ENDPOINT' });
    assert.deepEqual(plain(C.savePlan('ollama', '', 'http://127.0.0.1:11434', '')), { keystore: null, config: { key: 'ai.ollama.endpoint', value: '' } });
    assert.deepEqual(plain(C.savePlan('lmstudio', '', 'http://gpu:1234/v1', '')).config, { key: 'ai.lmstudio.endpoint', value: 'http://gpu:1234/v1' });
});

test('legacy Ollama opt-in key is migrated away', () => {
    assert.deepEqual(plain(C.legacyOllama({}, '')), { remove: false, endpoint: '' });
    assert.deepEqual(plain(C.legacyOllama({ ollama: { api_key: 'enabled', endpoint: '' } }, '')), { remove: true, endpoint: '' });
    assert.deepEqual(plain(C.legacyOllama({ ollama: { api_key: 'enabled', endpoint: 'http://gpu:11434' } }, '')), { remove: true, endpoint: 'http://gpu:11434' });
    assert.deepEqual(plain(C.legacyOllama({ ollama: { api_key: 'enabled', endpoint: 'http://gpu:11434' } }, 'http://set')), { remove: true, endpoint: '' }, 'never overrides the config');
});

test('extra headers: custom endpoint headers (sanitised) and OpenRouter attribution', () => {
    const cfg = { customHeaders: [{ name: 'X-Proxy', value: 'tok\r\nInjected: 1' }, { name: '', value: 'x' }, { name: 'Bad Name:', value: 'v' }], openrouterAttribution: true };
    assert.deepEqual(plain(C.extraHeaders('custom', cfg)), ['X-Proxy: tok Injected: 1', 'BadName: v']);
    const or = plain(C.extraHeaders('openrouter', cfg, { url: 'https://example.org/app', name: 'App' }));
    assert.equal(or.length, 2);
    assert.match(or[0], /^HTTP-Referer: https:\/\//);
    assert.equal(or[1], 'X-Title: App');
    assert.deepEqual(plain(C.extraHeaders('openrouter', cfg)), [], 'no app identity, no attribution');
    assert.deepEqual(plain(C.extraHeaders('openrouter', { openrouterAttribution: false })), []);
    assert.deepEqual(plain(C.extraHeaders('openai', cfg)), []);
    assert.deepEqual(plain(C.headerMap(['A: 1', 'B:2:3', 'bad'])), { A: '1', B: '2:3' });
});

test('request policy: timeout args, bounded retries, transient failures only', () => {
    assert.deepEqual(plain(R.timeoutArgs(600)), ['--max-time', '600']);
    assert.deepEqual(plain(R.timeoutArgs(0)), []);
    assert.equal(R.retries(99), 5);
    const base = { error: 'HTTP 503 overloaded', attempt: 0, max: 1 };
    assert.equal(R.shouldRetry(base), true);
    assert.equal(R.shouldRetry(Object.assign({}, base, { attempt: 1 })), false, 'max reached');
    assert.equal(R.shouldRetry(Object.assign({}, base, { streamed: true })), false, 'never after streaming');
    assert.equal(R.shouldRetry(Object.assign({}, base, { aborted: true })), false);
    assert.equal(R.shouldRetry({ error: 'Incorrect API key', attempt: 0, max: 3 }), false, '401 is not transient');
    assert.equal(R.shouldRetry({ error: 'curl: (7) Failed to connect', curlCode: 7, attempt: 0, max: 2 }), true);
    assert.equal(R.shouldRetry({ error: 'Rate limit reached', attempt: 0, max: 2 }), true);
    assert.ok(R.backoff(1) < R.backoff(2) && R.backoff(10) <= 8000);
});

test('OpenAI-compatible families: DeepSeek, OpenRouter, LM Studio, custom', () => {
    const ep = (provider, endpoint) => P.endpoint({ provider, model: 'm', endpoint: endpoint || '' }, '');
    assert.equal(ep('deepseek'), 'https://api.deepseek.com/v1/chat/completions');
    assert.equal(ep('openrouter'), 'https://openrouter.ai/api/v1/chat/completions');
    assert.equal(ep('lmstudio'), 'http://127.0.0.1:1234/v1/chat/completions');
    assert.equal(ep('lmstudio', 'http://gpu:1234'), 'http://gpu:1234/v1/chat/completions');
    assert.equal(ep('custom', 'http://box:8000/api'), 'http://box:8000/api/chat/completions');
    assert.equal(P.family('lmstudio'), 'openai');
    assert.equal(P.PROVIDERS.lmstudio.local, true);
    const h = plain(P.headers({ provider: 'openrouter' }, 'sk-or', ['X-Title: App\nEvil: 1']));
    assert.ok(h.includes('Authorization: Bearer sk-or'));
    assert.ok(h.includes('X-Title: App Evil: 1'));
    assert.ok(!plain(P.headers({ provider: 'lmstudio' }, '')).some(x => x.startsWith('Authorization')), 'no key, no auth header');
});

test('model listing requests honour a base override and send no empty auth', () => {
    assert.deepEqual(plain(P.modelsRequest('lmstudio', '', 'http://gpu:1234/v1/')), { url: 'http://gpu:1234/v1/models', headers: [] });
    assert.deepEqual(plain(P.modelsRequest('deepseek', 'k')), { url: 'https://api.deepseek.com/v1/models', headers: ['Authorization: Bearer k'] });
    assert.deepEqual(plain(P.modelsRequest('custom', 'k', 'http://box/v1', ['X-A: 1'])).headers, ['Authorization: Bearer k', 'X-A: 1']);
    assert.equal(P.modelsRequest('minimax', 'k').headers[0], 'Authorization: Bearer k');
});

test('listings: OpenRouter names and capability hints, LM Studio drops embeddings', () => {
    const or = plain(P.parseModelList('openrouter', JSON.stringify({ data: [
        { id: 'anthropic/claude-sonnet-4.5', name: 'Anthropic: Claude Sonnet 4.5', context_length: 200000, supported_parameters: ['tools', 'reasoning'], architecture: { input_modalities: ['text', 'image'] } }] })));
    assert.equal(or[0].name, 'Anthropic: Claude Sonnet 4.5');
    assert.deepEqual(or[0].hint, { contextWindow: 200000, tools: true, vision: true, source: 'listing' });
    const lm = plain(P.parseModelList('lmstudio', JSON.stringify({ data: [{ id: 'qwen3-8b' }, { id: 'text-embedding-nomic-embed-text-v1.5' }] })));
    assert.deepEqual(lm.map(m => m.id), ['qwen3-8b']);
    assert.equal(lm[0].hint, undefined);
});

test('Ollama keep_alive goes into the body', () => {
    const m = { provider: 'ollama', model: 'qwen3' };
    assert.equal(P.body([{ role: 'user', content: 'hi' }], m, [], { keepAlive: '10m' }).keep_alive, '10m');
    assert.equal(P.body([{ role: 'user', content: 'hi' }], m, [], { keepAlive: '-1' }).keep_alive, -1);
    assert.equal(P.body([{ role: 'user', content: 'hi' }], m, [], {}).keep_alive, undefined);
});
