const assert = require('node:assert/strict');
const { test } = require('node:test');
const { loadLibrary } = require('./lib/qmljs.cjs');
const S = loadLibrary('modules/aicenter/assistant/Suggestions.js');

const ids = list => JSON.parse(JSON.stringify(list)).map(s => s.id);

test('without context only the always-available prompts are offered', () => {
    assert.deepEqual(ids(S.suggest({}, [], 4)), ['selection', 'desktop-theme', 'region', 'desktop-dnd']);
});

test('clipboard content picks the most useful prompt', () => {
    assert.equal(S.suggest({ clipboard: { text: 'Traceback (most recent call last):\n  File "x"' } }, ['clipboard'], 1)[0].id, 'clip-error');
    assert.equal(S.suggest({ clipboard: { text: 'https://example.com/a' } }, ['clipboard'], 1)[0].id, 'clip-url');
    assert.equal(S.suggest({ clipboard: { text: 'function f() {\n  return 1;\n}' } }, ['clipboard'], 1)[0].id, 'clip-code');
    assert.equal(S.suggest({ clipboard: { text: 'x'.repeat(400) } }, ['clipboard'], 1)[0].id, 'clip-long');
    assert.equal(S.suggest({ clipboard: { text: 'hello' } }, ['clipboard'], 1)[0].id, 'clip-text');
    assert.equal(S.suggest({ clipboard: { isImage: true } }, ['clipboard'], 1)[0].context, 'clipboard');
    assert.equal(S.suggest({ clipboard: { text: '  ' } }, ['clipboard'], 3).length, 0);
});

test('live context comes first and carries arguments', () => {
    const ctx = { hour: 9, media: { title: 'Song', artist: 'Band', playing: true }, window: { appId: 'firefox' }, timer: { label: 'Tea 3:00' } };
    const list = S.suggest(ctx, [], 6);
    assert.deepEqual(ids(list), ['media-playing', 'timer', 'window', 'selection', 'time-morning', 'desktop-theme']);
    assert.deepEqual(Array.from(list[0].args), ['Song · Band']);
    assert.deepEqual(Array.from(list[2].args), ['firefox']);
});

test('disabled kinds are skipped and the limit is respected', () => {
    const ctx = { hour: 23, media: { title: 'Song', playing: false }, window: { title: 'Terminal' } };
    assert.deepEqual(ids(S.suggest(ctx, ['time', 'media'], 4)), ['media-paused', 'time-night']);
    assert.equal(S.suggest(ctx, [], 2).length, 2);
    assert.equal(S.suggest({ hour: 15 }, ['time'], 3)[0].id, 'time-focus');
});
