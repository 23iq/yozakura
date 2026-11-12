// PomodoroOwner.js: exactly one PomodoroSync owns the `pomodoro` IPC target.
const test = require('node:test');
const assert = require('node:assert');
const path = require('node:path');
const { loadLibrary } = require('./lib/qmljs.cjs');

const lib = () => loadLibrary(path.join(__dirname, '../modules/bar/clock/PomodoroOwner.js'), new Map());

const owners = syncs => syncs.filter(s => s.owner).length;

test('the first claimant owns, later ones do not', () => {
    const o = lib();
    const a = { owner: false }, b = { owner: false }, c = { owner: false };
    o.claim(a); o.claim(b); o.claim(c);
    assert.strictEqual(a.owner, true);
    assert.strictEqual(owners([a, b, c]), 1);
    o.claim(a); // twice is once
    assert.strictEqual(o.count(), 3);
});

test('the next one takes over when the owner goes away', () => {
    const o = lib();
    const a = { owner: false }, b = { owner: false }, c = { owner: false };
    o.claim(a); o.claim(b); o.claim(c);
    o.release(b); // not the owner: nothing changes
    assert.deepStrictEqual([a.owner, c.owner], [true, false]);
    o.release(a);
    assert.deepStrictEqual([a.owner, c.owner], [false, true]);
    o.release(c);
    assert.strictEqual(o.count(), 0);
    const d = { owner: false };
    o.claim(d);
    assert.strictEqual(d.owner, true);
});

test('releasing an unknown object is harmless', () => {
    const o = lib();
    const a = { owner: false };
    o.claim(a);
    o.release({ owner: true });
    assert.strictEqual(a.owner, true);
});
