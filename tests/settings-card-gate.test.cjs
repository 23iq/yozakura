const { test } = require('node:test');
const assert = require('node:assert/strict');
const path = require('node:path');

const qmljs = require('./lib/qmljs.cjs');
const lib = file => qmljs.loadLibrary(path.join(__dirname, '..', file));
const plain = v => JSON.parse(JSON.stringify(v));

const Gate = lib('modules/settings/CardGate.js');

const SWITCHES = {
    'notch.mediaPanel': { key: 'notch.mediaPanel', type: 'toggle', label: 'Media panel' },
    'desktop.depthClock': { key: 'desktop.depthClock', type: 'toggle', label: 'Depth clock' },
};
const lookup = k => SWITCHES[k] || null;
const getter = values => k => values[k];

const media = [
    { key: 'notch.mediaStyle', enabledWhen: { key: 'notch.mediaPanel', equals: true } },
    { key: 'notch.visualizer', enabledWhen: { key: 'notch.mediaPanel', equals: true } },
    { key: 'notch.noMedia' },
];

test('rows waiting on one switch: dimmed, one action for the card', () => {
    const g = plain(Gate.gate(media, getter({ 'notch.mediaPanel': false }), lookup));
    assert.equal(g.fix.key, 'notch.mediaPanel');
    assert.equal(g.fix.value, true);
    assert.deepEqual(g.ids, ['notch.mediaStyle', 'notch.visualizer']);
});

test('nothing waits once the switch is on', () => {
    assert.equal(Gate.gate(media, getter({ 'notch.mediaPanel': true }), lookup), null);
});

test('hidden rows (visibleWhen) wait too: the card is never only a sentence', () => {
    const clock = [{ key: 'desktop.clockStyle', visibleWhen: { key: 'desktop.depthClock', equals: true } }];
    const g = plain(Gate.gate(clock, getter({ 'desktop.depthClock': false }), lookup));
    assert.deepEqual(g.ids, ['desktop.clockStyle']);
});

test('two different switches, or none a click can flip: no card gate', () => {
    const two = media.concat([{ key: 'desktop.x', enabledWhen: { key: 'desktop.depthClock', equals: true } }]);
    assert.equal(Gate.gate(two, getter({}), lookup), null);
    const other = [{ key: 'a', visibleWhen: { key: 'bar.style', equals: 'islands' } }];
    assert.equal(Gate.gate(other, getter({}), lookup), null);
});
