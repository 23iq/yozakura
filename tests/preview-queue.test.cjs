// PreviewQueue.js: one command at a time, only the latest waits, revert and
// keep always come after an in-flight preview.
const { test } = require('node:test');
const assert = require('node:assert/strict');
const path = require('node:path');
const { loadLibrary } = require('./lib/qmljs.cjs');
const Q = loadLibrary(path.join(__dirname, '../modules/widgets/presets/PreviewQueue.js'));

function harness() {
    const log = [];
    const pending = [];
    const q = Q.create((args, cb) => { log.push(args.join(' ')); pending.push(cb); });
    const finish = () => { const cb = pending.shift(); if (cb) cb(); };
    return { q, log, finish };
}

test('fast previews keep only the latest waiting one', () => {
    const { q, log, finish } = harness();
    q.preview(['apply', '--preview', 'A']);
    q.preview(['apply', '--preview', 'B']);
    q.preview(['apply', '--preview', 'C']);
    assert.deepEqual(log, ['apply --preview A']);
    finish();
    assert.deepEqual(log, ['apply --preview A', 'apply --preview C']);
});

test('revert runs after the in-flight preview, once', () => {
    const { q, log, finish } = harness();
    q.preview(['apply', '--preview', 'A']);
    q.revert();
    q.revert();
    q.preview(['apply', '--preview', 'B']);
    finish();
    assert.deepEqual(log, ['apply --preview A', 'revert']);
});

test('keep applies for real and nothing reverts after it', () => {
    const { q, log, finish } = harness();
    q.preview(['apply', '--preview', 'A']);
    finish();
    q.keep(['apply', 'A']);
    q.revert();
    finish();
    assert.deepEqual(log, ['apply --preview A', 'apply A']);
});

test('no preview, no revert', () => {
    const { q, log } = harness();
    q.revert();
    assert.deepEqual(log, []);
});
