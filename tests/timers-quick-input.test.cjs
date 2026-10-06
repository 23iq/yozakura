// Quick input classification (QuickInput.js), focus summary
// (FocusSummary.js) and quick note planning (QuickNote.js) under
// modules/services/timers/.
const { test } = require('node:test');
const assert = require('node:assert/strict');
const path = require('node:path');
const { loadLibrary } = require('./lib/qmljs.cjs');

const dir = path.join(__dirname, '../modules/services/timers');
const Q = loadLibrary(path.join(dir, 'QuickInput.js'));
const S = loadLibrary(path.join(dir, 'FocusSummary.js'));
const N = loadLibrary(path.join(dir, 'QuickNote.js'));
const plain = v => JSON.parse(JSON.stringify(v));
const tr = (k, ...a) => k + (a.length ? '(' + a.join('|') + ')' : '');

test('classify: empty, focus, note, timers', () => {
    assert.equal(Q.classify('  ', 'timer').kind, 'empty');
    assert.deepEqual(plain(Q.classify('focus', 'timer')), { kind: 'focus', minutes: 0, valid: true });
    assert.deepEqual(plain(Q.classify('Focus 50', 'timer')), { kind: 'focus', minutes: 50, valid: true });
    assert.deepEqual(plain(Q.classify('фокус 1h30', 'timer')), { kind: 'focus', minutes: 90, valid: true });
    assert.equal(Q.classify('focus soon', 'timer').valid, false);
    assert.deepEqual(plain(Q.classify('note buy milk', 'timer')), { kind: 'note', text: 'buy milk' });
    assert.deepEqual(plain(Q.classify('note', 'timer')), { kind: 'timers', text: 'note' }, 'a bare word is not a note');
    assert.deepEqual(plain(Q.classify('10m tea', 'timer')), { kind: 'timers', text: '10m tea' });
    assert.deepEqual(plain(Q.classify(' 18:00 call mom ', 'timer')), { kind: 'timers', text: '18:00 call mom' });
    assert.deepEqual(plain(Q.classify('focus 50', 'note')), { kind: 'note', text: 'focus 50' }, 'note mode takes the line as is');
});

test('minutesOf', () => {
    assert.equal(Q.minutesOf('50'), 50);
    assert.equal(Q.minutesOf('25m'), 25);
    assert.equal(Q.minutesOf('90 min'), 90);
    assert.equal(Q.minutesOf('1h'), 60);
    assert.equal(Q.minutesOf('1.5h'), 90);
    assert.equal(Q.minutesOf('1h30'), 90);
    assert.equal(Q.minutesOf('1h15m'), 75);
    assert.equal(Q.minutesOf(''), 0);
    assert.equal(Q.minutesOf('abc'), 0);
});

test('focus summary: counts since the start, per app, own notifications excluded', () => {
    const list = [
        { appName: 'Telegram', time: 50 },
        { appName: 'Telegram', time: 150 },
        { appName: 'Mail', time: 160 },
        { appName: 'Telegram', time: 170 },
        { appName: 'Yozakura', time: 180, replaceKey: 'timer-t3' },
        { appName: '', time: 190 }
    ];
    const s = plain(S.summarize(list, 100, ['timer-', 'focus-']));
    assert.equal(s.count, 4);
    assert.deepEqual(s.apps, [{ name: 'Telegram', count: 2 }, { name: '?', count: 1 }, { name: 'Mail', count: 1 }]);
    assert.equal(S.body(s, tr, 2), 'focus.summary.some(4|Telegram (2), ?, …)');
    assert.equal(S.body(S.summarize([], 0, []), tr), 'focus.summary.none');
});

test('quick note: appends to the inbox note, creating it with an index entry', () => {
    const fresh = plain(N.plan('', 'Inbox', '2026-10-06T10:00:00Z', 'new-id'));
    assert.equal(fresh.noteId, 'new-id');
    assert.equal(fresh.created, true);
    assert.equal(fresh.header, '# Inbox\n\n');
    const index = JSON.parse(fresh.indexText);
    assert.deepEqual(index.order, ['new-id']);
    assert.deepEqual(index.notes['new-id'], { title: 'Inbox', created: '2026-10-06T10:00:00Z', modified: '2026-10-06T10:00:00Z', isMarkdown: true });

    const existing = JSON.stringify({ order: ['a', 'b'], notes: { a: { title: 'Inbox', isMarkdown: false }, b: { title: 'Inbox', isMarkdown: true, created: 'x' } } });
    const again = plain(N.plan(existing, 'Inbox', 'later', 'unused'));
    assert.equal(again.noteId, 'b', 'the markdown note of that title');
    assert.equal(again.created, false);
    assert.equal(again.header, '');
    const idx = JSON.parse(again.indexText);
    assert.deepEqual(idx.order, ['a', 'b']);
    assert.equal(idx.notes.b.modified, 'later');
    assert.equal(N.line('buy\n milk ', '06.10 14:05'), '- buy milk · 06.10 14:05\n');
    assert.equal(N.plan('{broken', 'Inbox', 't', 'id').created, true, 'a broken index starts over');
});
