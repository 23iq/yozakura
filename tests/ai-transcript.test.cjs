const assert = require('node:assert/strict');
const { test } = require('node:test');
const { loadLibrary } = require('./lib/qmljs.cjs');
const T = loadLibrary('modules/aicenter/transcript/Transcript.js');
const Timeline = loadLibrary('modules/services/ai/AgentTimeline.js');

const plain = v => JSON.parse(JSON.stringify(v));
const kinds = rows => plain(rows).map(r => r.kind);

test('every row carries the full schema', () => {
    const r = T.row('user', { text: 'hi', bogus: 1 });
    assert.deepEqual(Object.keys(r).sort(), Object.keys(T.FIELDS).sort());
    assert.equal(r.text, 'hi');
    assert.equal(r.bogus, undefined);
});

test('chat rows: user, thinking, answer, actions and permissions', () => {
    const rows = T.build('chat', [
        { role: 'user', content: 'Float firefox', attachments: '[{"type":"text","name":"w"}]' },
        { role: 'assistant', content: 'Done', thinking: 'look', model: 'Sonnet', toolCalls: JSON.stringify([
            { id: 'c1', name: 'windows_list', title: 'List windows', status: 'done', args: {}, result: '[]' },
            { id: 'c2', name: 'config_set', title: 'Set rule', status: 'ask', args: { key: 'x' } },
            { id: 'c3', name: 'timer_start', title: 'Timer 25:00 started', status: 'done', undo: { server: 'yozakura', tool: 'timer_cancel', args: { id: 't' } } }
        ]) },
        { role: 'error', content: 'boom' },
        { role: 'notice', content: 'note' }
    ]);
    assert.deepEqual(kinds(rows), ['user', 'thinking', 'assistant', 'action', 'permission', 'action', 'error', 'notice']);
    assert.equal(rows[0].attachments, '[{"type":"text","name":"w"}]');
    assert.equal(rows[2].engine, 'Sonnet');
    assert.equal(rows[3].status, 'done');
    assert.equal(rows[3].source, 1);
    assert.equal(rows[4].ref, 'c2');
    assert.equal(rows[4].status, 'pending');
    assert.equal(rows[4].input, '{"key":"x"}');
    assert.equal(T.undoOf(rows[5]).tool, 'timer_cancel');
    assert.equal(T.undoOf(rows[3]), null);
});

test('thinking can be hidden and an empty streaming answer keeps a spinner row', () => {
    const rows = T.fromChatRow({ role: 'assistant', content: '', thinking: 'x', status: 'streaming' }, 0, { showThinking: false });
    assert.equal(rows.length, 0);
    const empty = T.fromChatRow({ role: 'assistant', content: '', status: 'streaming' }, 2);
    assert.equal(empty.length, 1);
    assert.equal(empty[0].streaming, true);
    assert.equal(empty[0].key, 'c2:text');
});

test('agent blocks: folded tool rows and resolved permission cards', () => {
    const state = Timeline.build([
        { kind: 'user', text: 'go' },
        { kind: 'thinking', text: 'hmm', delta: true },
        { kind: 'tool_call', id: 't1', tool: 'Bash', title: '$ make', category: 'exec', input: { command: 'make' } },
        { kind: 'permission_request', id: 't1', tool: 'Bash', title: '$ make', category: 'exec' },
        { kind: 'diff', path: 'a.txt', diff: '@@ -1 +1 @@\n-a\n+b\n' },
        { kind: 'error', message: 'oops' }
    ]);
    const blocks = plain(state.blocks);
    let rows = T.build('agent', blocks);
    assert.deepEqual(kinds(rows), ['user', 'thinking', 'permission', 'diff', 'error']);
    assert.equal(rows[2].ref, 't1');
    Timeline.apply(state, { kind: 'permission_resolved', id: 't1', decision: 'allow' });
    rows = T.build('agent', plain(state.blocks));
    assert.deepEqual(kinds(rows), ['user', 'thinking', 'action', 'diff', 'error']);
    assert.equal(rows[2].decision, 'allow');
    assert.equal(rows[2].ref, 't1');
    assert.deepEqual(kinds(T.build('agent', plain(state.blocks), { showThinking: false })), ['user', 'action', 'diff', 'error']);
});

test('patch updates in place, inserts and removes', () => {
    const a = [T.row('assistant', { text: 'He' })];
    const b = [T.row('assistant', { text: 'Hello' }), T.row('action', { title: 'x' })];
    const ops = plain(T.patch(a, b, 3));
    assert.deepEqual(ops, [
        { op: 'set', index: 3, fields: { text: 'Hello' } },
        { op: 'insert', index: 4, row: plain(b[1]) }
    ]);
    assert.deepEqual(plain(T.patch(b, a, 0)), [
        { op: 'set', index: 0, fields: { text: 'He' } },
        { op: 'remove', index: 1, count: 1 }
    ]);
    assert.deepEqual(plain(T.patch(a, a, 0)), []);
});

test('helpers: speaker groups and input summaries', () => {
    assert.equal(T.startsGroup('', 'assistant'), true);
    assert.equal(T.startsGroup('action', 'assistant'), false);
    assert.equal(T.startsGroup('user', 'thinking'), true);
    assert.equal(T.startsGroup('assistant', 'user'), true);
    assert.equal(T.inputSummary('{"command":"ls -la"}'), '$ ls -la');
    assert.equal(T.inputSummary('{"file_path":"/a/b"}'), '/a/b');
    assert.equal(T.inputSummary('{}'), '');
    assert.equal(T.inputSummary('plain'), 'plain');
});

test('undo keys are per tool call and rows carry an undo state', () => {
    const undo = JSON.stringify({ tool: 'timer_cancel', args: { id: 't1' } });
    assert.equal(T.undoKey({ ref: 'c1', undo }), 'c1|' + undo);
    assert.notEqual(T.undoKey({ ref: 'c1', undo }), T.undoKey({ ref: 'c2', undo }), 'same undo, other call');
    assert.equal(T.undoKey({ ref: 'c1', undo: '' }), '', 'not undoable');
    const rows = T.build('chat', [{ role: 'assistant', content: '', toolCalls: JSON.stringify([
        { id: 'c1', name: 'timer_start', tool: 'timer_start', status: 'done', undo: { tool: 'timer_cancel', args: { id: 't1' } } }]) }]);
    const action = rows.find(r => r.kind === 'action');
    assert.equal(action.undoState, '', 'normalised rows start without an undo state');
});
