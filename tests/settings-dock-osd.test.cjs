const { test } = require('node:test');
const assert = require('node:assert/strict');
const path = require('node:path');

const qmljs = require('./lib/qmljs.cjs');
const lib = file => qmljs.loadLibrary(path.join(__dirname, '..', file));
const plain = v => JSON.parse(JSON.stringify(v));

const Dock = lib('modules/settings/editors/DockLook.js');
const Osd = lib('modules/settings/stages/OsdPlace.js');

test('dock sizes: the nearest step is ringed, the default is one', () => {
    assert.equal(Dock.SIZES[Dock.nearestSize(24)].px, 24);
    assert.equal(Dock.SIZES[Dock.nearestSize(12)].px, 20);
    assert.equal(Dock.SIZES[Dock.nearestSize(96)].px, 44);
    assert.equal(Dock.SIZES[Dock.nearestSize(30)].px, 32);
});

test('dock indicators: none turns running indicators off, a style turns them on', () => {
    assert.equal(Dock.indicatorOf(false, 'line'), 'none');
    assert.equal(Dock.indicatorOf(true, 'line'), 'line');
    assert.equal(Dock.indicatorOf(undefined, ''), 'dot');
    assert.deepEqual(plain(Dock.indicatorWrites('none')), { 'dock.showRunningIndicators': false });
    assert.deepEqual(plain(Dock.indicatorWrites('glow')), { 'dock.showRunningIndicators': true, 'dock.indicator': 'glow' });
});

test('the OSD on the stage: a picked edge, else the first free edge', () => {
    assert.equal(Osd.edge('pill', 'left', {}), 'left');
    assert.equal(Osd.edge('pill', 'auto', { occupied: [] }), 'bottom');
    assert.equal(Osd.edge('pill', 'auto', { occupied: ['bottom', 'top'] }), 'right');
    // the island style follows the notch while auto
    assert.equal(Osd.edge('island', 'auto', { notchPosition: 'top', notchEnabled: true, occupied: ['top'] }), 'top');
    // in the bar: no edge of its own
    assert.equal(Osd.edge('bar-inline', 'auto', {}), '');
    assert.equal(Osd.positionFor('top'), 'top');
    assert.equal(Osd.positionFor('nowhere'), 'auto');
});
