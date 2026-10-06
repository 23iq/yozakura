// Backend notify.request -> notifyInternal options
// (modules/notifications/NotifyRequest.js): clipboard and call actions,
// translated timer buttons, no notification sound for timers.
const { test } = require('node:test');
const assert = require('node:assert/strict');
const path = require('node:path');
const { loadLibrary } = require('./lib/qmljs.cjs');

const R = loadLibrary(path.join(__dirname, '../modules/notifications/NotifyRequest.js'));
const plain = v => JSON.parse(JSON.stringify(v));

function deps() {
    const d = { calls: [], copies: [] };
    d.call = (method, params) => d.calls.push([method, plain(params)]);
    d.copy = value => d.copies.push(value);
    d.tr = key => 'T:' + key;
    return d;
}

test('timer notification: call actions run the backend method, texts are translated', () => {
    const d = deps();
    const o = R.build({
        summary: 'tea', body: 'Timer 10m finished', urgency: 'critical', replaceKey: 'timer-t3',
        actions: [
            { identifier: 'snooze', text: '+5 min', call: { method: 'timers.add', params: { id: 't3', spec: '5m' } } },
            { identifier: 'stop', text: 'Stop', call: { method: 'timers.dismiss', params: { id: 't3' } } }
        ]
    }, d);
    assert.deepEqual(plain(o.actions), [{ identifier: 'snooze', text: 'T:timers.action.snooze' }, { identifier: 'stop', text: 'T:timers.action.stop' }]);
    assert.equal(o.urgency, 'critical');
    assert.deepEqual(plain(o.hints), { 'suppress-sound': true }, 'the timer alarm plays the sound');
    o.actionHandlers.stop('stop');
    o.actionHandlers.snooze('snooze');
    assert.deepEqual(d.calls, [['timers.dismiss', { id: 't3' }], ['timers.add', { id: 't3', spec: '5m' }]]);
});

test('reminder "Stop" without a call only closes; other notifications keep their texts', () => {
    const d = deps();
    const o = R.build({ summary: 'Reminder', replaceKey: 'timer-r4', actions: [{ identifier: 'dismiss', text: 'Stop' }] }, d);
    assert.equal(o.actions[0].text, 'T:timers.action.stop');
    assert.equal(o.actionHandlers.dismiss, undefined);

    const other = R.build({ summary: 'Color', actions: [{ identifier: 'hex', text: 'Copy HEX', clipboard: '#ff0000' }, { identifier: 'x', text: 'Call', call: { method: 'foo.bar' } }] }, d);
    assert.equal(other.actions[0].text, 'Copy HEX');
    assert.equal(other.hints, undefined);
    assert.equal(other.appName, 'Yozakura');
    assert.equal(other.expireTimeout, 5000);
    other.actionHandlers.hex();
    other.actionHandlers.x();
    assert.deepEqual(d.copies, ['#ff0000']);
    assert.deepEqual(d.calls, [['foo.bar', {}]]);
});

test('actions without an identifier are dropped', () => {
    const o = R.build({ summary: 's', actions: [null, { text: 'no id' }, { identifier: 'ok' }] }, deps());
    assert.deepEqual(plain(o.actions), [{ identifier: 'ok', text: 'ok' }]);
});

test('expireTimeout 0 keeps a notification with actions until dismissed', () => {
    const act = [{ identifier: 'open', text: 'Open', call: { method: 'tasks.open', params: { id: 'k1' } } }];
    assert.equal(R.build({ summary: 'waiting', expireTimeout: 0, actions: act }, deps()).expireTimeout, 0);
    assert.equal(R.build({ summary: 'plain', expireTimeout: 0 }, deps()).expireTimeout, 5000, 'no actions: the short default');
    assert.equal(R.build({ summary: 'x', expireTimeout: -1, actions: act }, deps()).expireTimeout, -1);
    assert.equal(R.build({ summary: 'x', expireTimeout: 12000 }, deps()).expireTimeout, 12000);
});

test('action data survives a save/restore and rebuilds working handlers', () => {
    const d = deps();
    const o = R.build({
        summary: 'Claude is waiting', actions: [
            { identifier: 'allow', text: 'Allow', call: { method: 'agents.respond', params: { session: 's1', request: 'r1', decision: 'allow' } } },
            { identifier: 'hex', text: 'Copy', clipboard: '#00ff00' },
            { identifier: 'nothing', text: 'Close' }]
    }, d);
    const saved = JSON.parse(JSON.stringify(o.actionData)); // what history keeps
    assert.deepEqual(Object.keys(saved).sort(), ['allow', 'hex']);
    const h = R.handlers(saved, d);
    h.allow();
    h.hex();
    assert.deepEqual(d.calls, [['agents.respond', { session: 's1', request: 'r1', decision: 'allow' }]]);
    assert.deepEqual(d.copies, ['#00ff00']);
    assert.deepEqual(Object.keys(R.handlers(null, d)), []);
    assert.deepEqual(Object.keys(R.handlers({ x: { call: {} } }, d)), []);
});

test('a failed action call becomes a short quiet notice', () => {
    const n = plain(R.failureNotice({ message: 'no pending request r1' }, k => 'T:' + k));
    assert.equal(n.summary, 'T:notifications.action_failed');
    assert.equal(n.body, 'no pending request r1');
    assert.equal(n.urgency, 'low');
    assert.ok(n.expireTimeout > 0 && n.hints['suppress-sound']);
    assert.equal(R.failureNotice('boom').body, 'boom');
});
