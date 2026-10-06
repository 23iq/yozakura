// Task board helpers (modules/services/tasks/TaskModel.js): grouping and
// order, keyboard steps, formatting, plan edits, /template parsing,
// tasks.create params, activity text, tasks.configure payload.
const { test } = require('node:test');
const assert = require('node:assert/strict');
const path = require('node:path');
const { loadLibrary } = require('./lib/qmljs.cjs');

const M = loadLibrary(path.join(__dirname, '../modules/services/tasks/TaskModel.js'));
const plain = v => JSON.parse(JSON.stringify(v));
const NOW = 1_800_000_000_000;

const task = (id, status, extra) => Object.assign({ id, status, projectDir: '/p', title: id, createdAt: 0, runs: [] }, extra || {});

test('statuses map to board sections, attention first', () => {
    assert.deepEqual(plain(M.SECTIONS), ['waiting', 'running', 'review', 'queued', 'done']);
    assert.equal(M.sectionOf('awaiting_plan'), 'waiting');
    assert.equal(M.sectionOf('waiting'), 'waiting');
    assert.equal(M.sectionOf('verifying'), 'running');
    assert.equal(M.sectionOf('planning'), 'running');
    assert.equal(M.sectionOf('waiting_limit'), 'queued');
    assert.equal(M.sectionOf('review'), 'review');
    for (const s of ['accepted', 'discarded', 'failed', 'cancelled'])
        assert.equal(M.sectionOf(s), 'done');
    assert.equal(M.statusInfo('running').busy, true);
});

test('board groups by project, sorts per section, collapses done', () => {
    const tasks = [
        task('q2', 'queued', { createdAt: 20 }),
        task('q1', 'queued', { createdAt: 10 }),
        task('r1', 'running', { startedAt: 50 }),
        task('d1', 'accepted', { finishedAt: 100 }),
        task('d2', 'failed', { finishedAt: 200 }),
        task('rv', 'review', { finishedAt: 5 }),
        task('other', 'running', { projectDir: '/elsewhere' }),
    ];
    const b = M.board(tasks, { dir: '/p/' });
    assert.equal(b.total, 6);
    const by = Object.fromEntries(b.sections.map(s => [s.id, s]));
    assert.deepEqual(plain(by.queued.tasks.map(t => t.id)), ['q1', 'q2']);
    assert.deepEqual(plain(by.done.tasks.map(t => t.id)), ['d2', 'd1']);
    assert.equal(by.done.collapsed, true);
    assert.equal(by.running.collapsed, false);
    assert.deepEqual(plain(M.order(b)), ['r1', 'rv', 'q1', 'q2']);
    const open = M.board(tasks, { dir: '/p', collapsed: { done: false, queued: true }, doneLimit: 1, hideEmpty: true });
    assert.deepEqual(plain(open.sections.map(s => s.id)), ['running', 'review', 'queued', 'done']);
    assert.deepEqual(plain(M.order(open)), ['r1', 'rv', 'd2']);
    assert.equal(open.sections[3].count, 2);
    assert.equal(M.board(tasks, {}).total, 7);
});

test('keyboard steps clamp and start at the ends', () => {
    const ids = ['a', 'b', 'c'];
    assert.equal(M.step(ids, '', 1), 'a');
    assert.equal(M.step(ids, '', -1), 'c');
    assert.equal(M.step(ids, 'a', 1), 'b');
    assert.equal(M.step(ids, 'c', 1), 'c');
    assert.equal(M.step(ids, 'a', -1), 'a');
    assert.equal(M.step([], 'a', 1), '');
});

test('elapsed, cost, tokens, checks, attempts, branch', () => {
    assert.equal(M.duration(42_000), '42s');
    assert.equal(M.duration(12 * 60_000), '12m');
    assert.equal(M.duration(65 * 60_000), '1h 05m');
    assert.equal(M.duration(50 * 3600_000), '2d 2h');
    assert.equal(M.elapsed(task('a', 'running', { startedAt: NOW - 90_000 }), NOW), '1m');
    assert.equal(M.elapsed(task('a', 'accepted', { startedAt: NOW - 90_000, finishedAt: NOW - 60_000 }), NOW), '30s');
    assert.equal(M.elapsed(task('a', 'queued'), NOW), '');
    assert.equal(M.cost({ cost: { costUsd: 0.4234 } }), '$0.42');
    assert.equal(M.cost({ cost: { costUsd: 0.0123 } }), '$0.012');
    assert.equal(M.cost({ cost: { inputTokens: 12000, outputTokens: 345 } }), '12.3k tok');
    assert.equal(M.cost({}), '');
    assert.equal(M.tokens(2_500_000), '2.5M');
    const t = task('a', 'review', {
        runs: [
            { index: 0, agent: 'claude', attempts: 1, checks: [{ status: 'fail' }, { status: 'pass' }], branch: 'yoz/a' },
            { index: 1, agent: 'codex', attempts: 2, checks: [{ status: 'timeout' }] },
        ],
    });
    assert.equal(M.checkStatus(t), 'timeout');
    assert.equal(M.attempts(t), 2);
    assert.equal(M.branch(t), 'yoz/a');
    assert.equal(M.branch(Object.assign({}, t, { inPlace: true })), '');
    assert.deepEqual(plain(M.taskAgents(t)), ['claude', 'codex']);
    assert.equal(M.agentIcon('claude'), 'anthropic.svg');
    assert.equal(M.agentIcon('opencode'), '');
    assert.equal(M.agentLabel('codex', [{ id: 'codex', label: 'Codex CLI' }]), 'Codex CLI');
    assert.equal(M.agentLabel('opencode', []), 'OpenCode');
});

test('runs: primary, review runs, actions, commit message', () => {
    const t = task('a', 'waiting', { runs: [{ index: 0, status: 'review' }, { index: 1, status: 'waiting' }] });
    assert.equal(M.primaryRun(t), 1);
    assert.equal(M.primaryRun(task('b', 'review', { runs: [{ index: 0, status: 'failed' }, { index: 1, status: 'review' }] })), 1);
    assert.equal(M.primaryRun(task('c', 'queued')), -1);
    assert.equal(M.reviewRuns(t).length, 1);
    assert.equal(M.runAt(t, 1).status, 'waiting');
    assert.equal(M.runAt(t, 5), null);
    const review = M.actions(task('a', 'review'));
    assert.equal(review.accept, true);
    assert.equal(review.followup, true);
    assert.equal(review.cancel, false);
    const running = M.actions(task('a', 'running'));
    assert.equal(running.accept, false);
    assert.equal(running.cancel, true);
    assert.equal(M.actions(task('a', 'accepted')).discard, false);
    assert.equal(M.actions(task('a', 'awaiting_plan')).runPlan, true);
    assert.equal(M.commitMessage({ title: 'T' }, { commitMessage: '  feat: x \n' }), 'feat: x');
    assert.equal(M.commitMessage({ title: 'T' }, {}), 'T');
});

test('plan edits are pure', () => {
    const s = ['a', 'b', 'c'];
    assert.deepEqual(plain(M.planMove(s, 0, 2)), ['b', 'c', 'a']);
    assert.deepEqual(plain(M.planMove(s, 0, 5)), ['a', 'b', 'c']);
    assert.deepEqual(plain(M.planRemove(s, 1)), ['a', 'c']);
    assert.deepEqual(plain(M.planInsert(s, 1, 'x')), ['a', 'x', 'b', 'c']);
    assert.deepEqual(plain(M.planInsert(s, -1, 'z')), ['a', 'b', 'c', 'z']);
    assert.deepEqual(plain(M.planSet(s, 2, 'C')), ['a', 'b', 'C']);
    assert.deepEqual(plain(M.planClean([' a ', '', '  ', 'b'])), ['a', 'b']);
    assert.deepEqual(plain(s), ['a', 'b', 'c']);
});

test('slash templates', () => {
    const templates = [{ id: 'review', name: 'Review', description: 'Review the diff' }, { id: 'fix-check', name: 'Fix check' }];
    assert.deepEqual(plain(M.slashCommands(templates)), [{ cmd: '/review', desc: 'Review the diff' }, { cmd: '/fix-check', desc: 'Fix check' }]);
    assert.deepEqual(plain(M.parseSlash('/review  the auth module', templates)), { template: 'review', input: 'the auth module' });
    assert.deepEqual(plain(M.parseSlash('/fix-check', templates)), { template: 'fix-check', input: '' });
    assert.equal(M.parseSlash('/nope x', templates), null);
    assert.equal(M.parseSlash('review', templates), null);
});

test('create params from the composer', () => {
    const base = { dir: '/p', text: 'Add hello', agents: ['claude'], model: 'opus', effort: 'high' };
    assert.deepEqual(plain(M.createParams(base)), { dir: '/p', prompt: 'Add hello', agent: 'claude', model: 'opus', effort: 'high' });
    const best = plain(M.createParams(Object.assign({}, base, { agents: ['claude', 'codex', 'opencode', 'x', 'y'], planFirst: true, inPlace: true })));
    assert.deepEqual(best.agents, ['claude', 'codex', 'opencode', 'x']);
    assert.equal(best.model, undefined);
    assert.equal(best.mode, 'plan');
    assert.equal(best.inPlace, undefined);
    const ctx = plain(M.createParams({
        dir: '/p', text: 'Explain', agents: ['codex'], inPlace: true,
        attachments: [{ type: 'text', kind: 'selection', name: 'Selection', text: 'foo()' }, { type: 'image', path: '/tmp/s.png' }],
    }));
    assert.equal(ctx.inPlace, true);
    assert.match(ctx.prompt, /<context name="Selection">\nfoo\(\)\n<\/context>/);
    assert.match(ctx.prompt, /Images: \/tmp\/s.png\n\nExplain$/);
    assert.equal(ctx.vars.selection, 'foo()');
    const tpl = plain(M.createParams({ dir: '/p', text: '/review auth', agents: ['claude'], templates: [{ id: 'review' }] }));
    assert.equal(tpl.template, 'review');
    assert.equal(tpl.prompt, 'auth');
    assert.equal(tpl.vars.input, 'auth');
    assert.equal(M.createError(base), '');
    assert.equal(M.createError(Object.assign({}, base, { dir: '' })), 'no_project');
    assert.equal(M.createError(Object.assign({}, base, { text: ' ' })), 'empty');
    assert.equal(M.createError(Object.assign({}, base, { agents: [] })), 'no_agent');
    assert.equal(M.createError(Object.assign({}, base, { agents: ['a', 'b'], inPlace: true })), 'in_place_best_of');
    assert.equal(M.createError({ dir: '/p', text: '/review', agents: ['a'], templates: [{ id: 'review' }] }), '');
});

test('activity text', () => {
    const tr = k => ({ 'ai.tasks.activity_waiting': '%1 is waiting', 'ai.tasks.activity_running_n': '%1 tasks running', 'ai.tasks.activity_review': 'Ready for review', 'ai.tasks.activity_queued': '%1 queued' })[k] || k;
    assert.equal(M.activityText({ headline: 'idle' }, tr), null);
    assert.equal(M.activityText(null, tr), null);
    const w = M.activityText({ headline: 'waiting', agent: 'Codex', taskId: 'a', items: [{ id: 'a', title: 'Add hello' }] }, tr);
    assert.equal(w.label, 'Codex is waiting');
    assert.equal(w.detail, 'Add hello');
    assert.equal(w.color, 'warning');
    const r = M.activityText({ headline: 'running', running: 3, agent: 'Codex' }, tr);
    assert.equal(r.label, '3 tasks running');
    assert.equal(r.busy, true);
    assert.equal(M.activityText({ headline: 'running', running: 1, agent: 'Codex' }, tr).label, 'Codex');
    assert.equal(M.activityText({ headline: 'review', review: 1 }, tr).label, 'Ready for review');
    assert.equal(M.activityText({ headline: 'queued', queued: 2 }, tr).label, '2 queued');
});

test('configure payload', () => {
    assert.deepEqual(plain(M.configureParams({})), { maxParallel: 2, fallbackAgent: '', notify: true, mute: [], mergeMode: 'squash' });
    assert.deepEqual(plain(M.configureParams({ maxParallel: 3.6, fallbackAgent: 'codex', notifications: false, notifyEvents: ['permission', 'review'], mergeMode: 'merge' })),
        { maxParallel: 4, fallbackAgent: 'codex', notify: false, mute: ['plan', 'failed', 'limit'], mergeMode: 'merge' });
});
