const { test } = require('node:test');
const assert = require('node:assert/strict');
const path = require('node:path');
const qmljs = require('./lib/qmljs.cjs');

const R = qmljs.loadLibrary(path.join(__dirname, '../modules/dock/indicators/IndicatorRegistry.js'));
const plain = v => JSON.parse(JSON.stringify(v));

test('registry lists dot, line, glow, brush; each file exists', () => {
    const fs = require('node:fs');
    assert.deepEqual(plain(R.ids()), ['dot', 'line', 'glow', 'brush']);
    for (const id of R.ids())
        assert.ok(fs.existsSync(path.join(__dirname, '../modules/dock/indicators', R.get(id).url)), id);
    assert.equal(R.get('nope').id, 'dot', 'unknown styles fall back to dot');
    assert.equal(R.get(undefined).id, 'dot');
});

test('placement: indicators hug the screen edge the dock sits on', () => {
    assert.deepEqual(plain(R.placement('bottom')), { vertical: false, side: 'bottom' });
    assert.deepEqual(plain(R.placement('top')), { vertical: false, side: 'top' });
    assert.deepEqual(plain(R.placement('left')), { vertical: true, side: 'left' });
    assert.deepEqual(plain(R.placement('right')), { vertical: true, side: 'right' });
    assert.deepEqual(plain(R.placement('bogus')), { vertical: false, side: 'bottom' });
});

test('count: marks cap at 3 and shrink beyond three windows', () => {
    assert.deepEqual(plain(R.shown(1)), { n: 1, wide: true });
    assert.deepEqual(plain(R.shown(3)), { n: 3, wide: true });
    assert.deepEqual(plain(R.shown(7)), { n: 3, wide: false });
    assert.deepEqual(plain(R.shown(0)), { n: 0, wide: true });
});
