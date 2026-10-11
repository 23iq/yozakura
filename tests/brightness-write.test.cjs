// Single-flight brightness writer (modules/services/BrightnessWrite.js).
const { test } = require('node:test');
const assert = require('node:assert/strict');
const path = require('node:path');
const { loadLibrary } = require('./lib/qmljs.cjs');

const W = loadLibrary(path.join(__dirname, '..', 'modules/services/BrightnessWrite.js'));
const plain = v => JSON.parse(JSON.stringify(v));

test('first request writes immediately, later ones wait for the bus', () => {
    const st = W.create();
    assert.equal(W.submit(st, 40), 40);
    assert.equal(W.submit(st, 41), null);
    assert.equal(W.submit(st, 42), null);
});

test('only the newest value is written after the running write ends', () => {
    const st = W.create();
    W.submit(st, 10);
    for (let v = 11; v <= 30; v++)
        W.submit(st, v);
    assert.equal(W.done(st, true), 30);
    // nothing queued behind it: the backlog never builds up
    assert.equal(W.done(st, true), null);
    assert.equal(W.submit(st, 31), 31);
});

test('at most one write is in flight however many requests arrive', () => {
    const st = W.create();
    let started = 0;
    const run = raw => { if (raw !== null) started++; };
    run(W.submit(st, 1));
    for (let i = 2; i < 50; i++)
        run(W.submit(st, i));
    assert.equal(started, 1);
    run(W.done(st, true));
    assert.equal(started, 2);
});

test('a failed fast write retries once with plain flags', () => {
    const st = W.create();
    W.submit(st, 55);
    assert.equal(W.done(st, false), 55);
    assert.equal(st.fast, false);
    // a second failure is dropped, not looped
    assert.equal(W.done(st, false), null);
});

test('a failed write does not overwrite a newer pending value', () => {
    const st = W.create();
    W.submit(st, 55);
    W.submit(st, 60);
    assert.equal(W.done(st, false), 60);
});

test('commands: ddcutil fast/plain flags and brightnessctl', () => {
    assert.deepEqual(plain(W.command(true, '4', 73, true)),
        ['ddcutil', '-b', '4', '--skip-ddc-checks', '--noverify', 'setvcp', '10', '73']);
    assert.deepEqual(plain(W.command(true, '4', 73, false)),
        ['ddcutil', '-b', '4', 'setvcp', '10', '73']);
    assert.deepEqual(plain(W.command(false, '', 12, true)),
        ['brightnessctl', '--class', 'backlight', 's', '12', '--quiet']);
});
