// Usage formatting for the AI bar (UsageFormat.js).
const { test } = require('node:test');
const assert = require('node:assert/strict');
const path = require('node:path');
const { loadLibrary } = require('./lib/qmljs.cjs');

const F = loadLibrary(path.join(__dirname, '../modules/services/ai/UsageFormat.js'));

test('token counts', () => {
    assert.equal(F.tokens(0), '0');
    assert.equal(F.tokens(950), '950');
    assert.equal(F.tokens(1234), '1.2k');
    assert.equal(F.tokens(1000), '1k');
    assert.equal(F.tokens(12400), '12k');
    assert.equal(F.tokens(1250000), '1.3M');
    assert.equal(F.tokens(15400000), '15M');
    assert.equal(F.tokens(undefined), '0');
});

test('costs', () => {
    assert.equal(F.cost(null), '');
    assert.equal(F.cost(0), '$0');
    assert.equal(F.cost(0.123), '$0.12');
    assert.equal(F.cost(0.123, { estimated: true }), '≈ $0.12');
    assert.equal(F.cost(0.004, { estimated: true }), '≈ <$0.01');
    assert.equal(F.cost(0.004, { decimals: 3 }), '$0.004');
    assert.equal(F.cost(1.5, { style: 'code' }), '1.50 USD');
    assert.equal(F.cost(0, { style: 'code' }), '0 USD');
});

test('totals cost and strip text', () => {
    assert.equal(F.totalsCost(null), '');
    assert.equal(F.totalsCost({ requests: 2, unpriced: 2, costUSD: 0 }), '', 'nothing priced');
    assert.equal(F.totalsCost({ requests: 3, unpriced: 1, costUSD: 0.5, estimated: true }), '≈ $0.50+');
    const t = { requests: 2, inputTokens: 12000, outputTokens: 400, costUSD: 0.12, estimated: true };
    assert.equal(F.stripText(t), '12k · ≈ $0.12');
    assert.equal(F.stripText(t, { tokens: false }), '≈ $0.12');
    assert.equal(F.stripText(t, { cost: false }), '12k');
    assert.equal(F.stripText({ requests: 0 }), '');
    assert.equal(F.stripText({ requests: 1, inputTokens: 10, outputTokens: 5, unpriced: 1 }), '15');
});

test('durations', () => {
    assert.equal(F.duration(0), '');
    assert.equal(F.duration(20 * 1000), '<1m');
    assert.equal(F.duration(45 * 60000), '45m');
    assert.equal(F.duration(130 * 60000), '2h 10m');
    assert.equal(F.duration(120 * 60000), '2h');
    assert.equal(F.duration((3 * 24 + 4) * 3600000), '3d 4h');
    assert.equal(F.duration(90 * 60000, { d: ' д', h: ' ч', m: ' мин' }), '1 ч 30 мин');
    const now = Date.parse('2026-10-06T10:00:00Z');
    assert.equal(F.msUntil('2026-10-06T11:00:00Z', now), 3600000);
    assert.equal(F.msUntil('2026-10-06T09:00:00Z', now), 0);
    assert.equal(F.msUntil('', now), 0);
});

test('subscription and limit pick', () => {
    assert.equal(F.subscriptionFor({ kind: 'agent', agent: 'claude' }), 'claude');
    assert.equal(F.subscriptionFor({ kind: 'agent', agent: 'opencode' }), '');
    assert.equal(F.subscriptionFor({ provider: 'anthropic', model: 'claude-x' }), '');
    assert.equal(F.subscriptionFor(null), '');
    const limits = [
        { provider: 'claude', windows: [{ id: 'week', usedPercent: 40 }, { id: '5h', usedPercent: 13, resetsAt: '2026-10-06T15:00:00Z' }] },
        { provider: 'codex', windows: [] },
    ];
    let p = F.pickLimit(limits, 'claude', 'auto');
    assert.equal(p.id, 'week');
    assert.equal(p.fraction, 0.4);
    p = F.pickLimit(limits, 'claude', '5h');
    assert.equal(p.id, '5h');
    assert.equal(p.resetsAt, '2026-10-06T15:00:00Z');
    assert.equal(F.pickLimit(limits, 'claude', 'week_opus').id, 'week', 'missing preference falls back');
    assert.equal(F.pickLimit(limits, 'codex', 'auto'), null);
    assert.equal(F.pickLimit(limits, '', 'auto'), null);
    assert.equal(F.pickLimit([{ provider: 'x', windows: [{ id: 'week', usedPercent: 10 }, { id: '5h', usedPercent: 10 }] }], 'x').id, '5h', 'tie: 5h first');
    assert.equal(F.pickLimit([{ provider: 'x', windows: [{ id: '5h', usedPercent: 130 }] }], 'x').fraction, 1);
    assert.equal(F.level(79, 80, 90), 'ok');
    assert.equal(F.level(80, 80, 90), 'warn');
    assert.equal(F.level(95, 80, 90), 'critical');
});

test('windows list', () => {
    const w = F.windows([{ provider: 'claude', source: 'oauth', windows: [{ id: 'week_opus', usedPercent: 1 }, { id: 'week', usedPercent: 2 }, { id: '5h', usedPercent: 3 }] }]);
    assert.deepEqual(Array.from(w, x => x.id), ['5h', 'week', 'week_opus']);
    assert.equal(w[0].source, 'oauth');
    assert.equal(F.windowKey('5h'), 'ai.usage.window.5h');
    assert.equal(F.windowKey('1d'), '');
});

test('hidden providers', () => {
    const rows = [{ key: 'openai', requests: 1, costUSD: 1, inputTokens: 5 }, { key: 'Ollama', requests: 2, inputTokens: 7 }, { key: 'gpt-4o', provider: 'openai' }];
    assert.deepEqual(F.visibleRows(rows, ['ollama ']).map(r => r.key), ['openai', 'gpt-4o']);
    assert.deepEqual(F.visibleRows(rows, ['OpenAI']).map(r => r.key), ['Ollama']);
    assert.equal(F.isHidden('ollama', ['Ollama']), true);
    const t = F.sumRows(F.visibleRows(rows.slice(0, 2), []));
    assert.equal(t.requests, 3);
    assert.equal(t.inputTokens, 12);
    assert.equal(t.costUSD, 1);
});

test('days and series', () => {
    const from = new Date(2026, 9, 5).toISOString(); // Monday, local midnight
    const to = new Date(2026, 9, 12).toISOString();
    const now = new Date(2026, 9, 7, 15).getTime();
    const days = F.days(from, to, now);
    assert.deepEqual(Array.from(days), ['2026-10-05', '2026-10-06', '2026-10-07']);
    assert.equal(F.days(from, new Date(2026, 9, 6).toISOString(), now).length, 1, 'to bounds the range');
    const rows = [
        { key: '2026-10-05', provider: 'openai', inputTokens: 10, outputTokens: 1 },
        { key: '2026-10-07', provider: 'openai', inputTokens: 5, outputTokens: 0 },
        { key: '2026-10-07', provider: 'claude', inputTokens: 100, outputTokens: 0 },
    ];
    assert.deepEqual(Array.from(F.series(rows, 'openai', days)), [11, 0, 5]);
    assert.deepEqual(Array.from(F.series(rows, '', days)), [11, 0, 105]);
    assert.deepEqual(F.modelsOf([{ key: 'a', provider: 'x' }, { key: 'b', provider: 'y' }], 'y').map(r => r.key), ['b']);
});

test('provider labels and icons', () => {
    assert.equal(F.providerLabel('openai'), 'OpenAI');
    assert.equal(F.providerLabel('claude'), 'Claude Code');
    assert.equal(F.providerLabel('mystery'), 'mystery');
    assert.equal(F.providerIcon('codex'), 'openai.svg');
    assert.equal(F.providerIcon('ollama'), 'ollama.svg');
    assert.equal(F.providerIcon('mystery'), '');
});
