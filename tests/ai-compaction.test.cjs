// Compaction of HTTP chats (Compaction.js) and how ChatRows sends a
// compacted conversation.
const { test } = require('node:test');
const assert = require('node:assert/strict');
const path = require('node:path');
const { loadLibrary } = require('./lib/qmljs.cjs');

const C = loadLibrary(path.join(__dirname, '../modules/services/ai/Compaction.js'));
const R = loadLibrary(path.join(__dirname, '../modules/services/ai/ChatRows.js'));
const T = loadLibrary(path.join(__dirname, '../modules/aicenter/transcript/Transcript.js'));
const plain = v => JSON.parse(JSON.stringify(v));

const u = t => ({ role: 'user', content: t, attachments: '[]', toolCalls: '[]' });
const a = (t, calls) => ({ role: 'assistant', content: t, attachments: '[]', toolCalls: JSON.stringify(calls || []) });
const chat = [u('q1'), a('a1'), u('q2'), a('a2', [{ id: 'c1', name: 'timer_start', tool: 'timer_start', args: { minutes: 5 }, status: 'done', result: 'started' }]), u('q3'), a('a3'), { role: 'notice', content: 'n' }, u('q4'), a('a4')];

test('plan keeps the last N user turns', () => {
    assert.deepEqual(plain(C.plan(chat, 2)), { start: 0, cut: 4, previous: -1 });
    assert.deepEqual(plain(C.plan(chat, 1)), { start: 0, cut: 7, previous: -1 });
    // nothing older than the kept turns
    assert.equal(C.plan(chat, 4), null);
    assert.equal(C.plan(chat, 9), null);
    // keep 0 compacts everything
    assert.equal(C.plan(chat, 0).cut, chat.length);
    assert.equal(C.plan([], 2), null);
});

test('a second compaction starts after the previous summary', () => {
    const rows = [u('q1'), a('a1'), { role: 'summary', content: 'S1' }, u('q2'), a('a2'), u('q3'), a('a3')];
    assert.deepEqual(plain(C.plan(rows, 1)), { start: 3, cut: 5, previous: 2 });
    assert.equal(C.plan(rows, 2), null);
    const text = C.transcript(rows, C.plan(rows, 1));
    assert.match(text, /^Earlier summary:\nS1/);
    assert.match(text, /User: q2/);
    assert.doesNotMatch(text, /q1|q3/);
});

test('transcript includes tool calls with clipped results', () => {
    const text = C.transcript(chat, C.plan(chat, 2));
    assert.match(text, /User: q1\n\nAssistant: a1/);
    assert.match(text, /Tool timer_start \{"minutes":5\} -> started/);
    const req = C.request(chat, C.plan(chat, 2));
    assert.equal(req.length, 1);
    assert.equal(req[0].role, 'user');
});

test('toMessages sends the last summary and what follows it', () => {
    const rows = [u('q1'), a('a1'), { role: 'summary', content: 'S1' }, u('q2'), a('a2')];
    const msgs = plain(R.toMessages(rows));
    assert.equal(msgs.length, 3);
    assert.equal(msgs[0].role, 'user');
    assert.ok(msgs[0].content.startsWith(C.SUMMARY_PREFIX));
    assert.ok(msgs[0].content.endsWith('S1'));
    assert.equal(msgs[1].content, 'q2');
    // stored and restored
    const stored = R.toStored(rows);
    assert.equal(stored[2].role, 'summary');
    assert.equal(R.fromStored({ messages: stored })[2].role, 'summary');
});

test('the transcript shows a summary as a compaction marker', () => {
    const rows = T.fromChatRow({ role: 'summary', content: 'S1' }, 2, {});
    assert.equal(rows.length, 1);
    assert.equal(rows[0].kind, 'compacted');
    assert.equal(rows[0].text, 'S1');
    assert.equal(T.startsGroup('assistant', 'compacted'), true);
});

test('auto-compaction threshold', () => {
    assert.equal(C.shouldAutoCompact(true, 0.96, 95), true);
    assert.equal(C.shouldAutoCompact(true, 0.94, 95), false);
    assert.equal(C.shouldAutoCompact(false, 0.99, 95), false);
    assert.equal(C.shouldAutoCompact(true, 0, 0), false);
});
