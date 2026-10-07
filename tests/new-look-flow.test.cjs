// NewLookFlow.js: the one-time "Try the new Yozakura look" offer and its
// Keep / Revert countdown state machine.
const { test } = require('node:test');
const assert = require('node:assert/strict');
const path = require('node:path');
const { loadLibrary } = require('./lib/qmljs.cjs');
const F = loadLibrary(path.join(__dirname, '../modules/widgets/presets/NewLookFlow.js'));
const plain = (v) => JSON.parse(JSON.stringify(v));

test('offered once, to existing users not on the new look', () => {
    const g = { onboardingDone: true, newLookOffered: false };
    assert.equal(F.shouldOffer(g, 'Glacier'), true);
    assert.equal(F.shouldOffer(g, 'Yozakura'), false);
    assert.equal(F.shouldOffer(g, 'Yozakura Default'), false, 'the old default name resolves to it');
    assert.equal(F.shouldOffer(g, ''), false, 'nothing while the active set is unknown');
    assert.equal(F.shouldOffer({ onboardingDone: false }, 'Glacier'), false, 'not before onboarding is done');
    assert.equal(F.shouldOffer({ onboardingDone: true, newLookOffered: true }, 'Glacier'), false);
    assert.equal(F.shouldOffer(null, 'Glacier'), false);
});

test('try previews, keep applies, revert and timeout revert, all mark', () => {
    assert.deepEqual(plain(F.step('idle', 'try')), { phase: 'starting', run: ['apply', '--preview', 'Yozakura'], mark: false });
    assert.equal(F.step('starting', 'ok').phase, 'trying');
    assert.deepEqual(plain(F.step('trying', 'keep')), { phase: 'ending', run: ['apply', 'Yozakura'], mark: false });
    assert.deepEqual(plain(F.step('trying', 'revert').run), ['revert']);
    assert.deepEqual(plain(F.step('trying', 'timeout').run), ['revert']);
    assert.deepEqual(plain(F.step('ending', 'ok')), { phase: 'done', run: null, mark: true });
    assert.equal(F.step('ending', 'fail').mark, true);
});

test('not now marks without a command; a failed preview offers again', () => {
    assert.deepEqual(plain(F.step('idle', 'dismiss')), { phase: 'done', run: null, mark: true });
    assert.deepEqual(plain(F.step('starting', 'fail')), { phase: 'idle', run: null, mark: false });
});

test('events out of order change nothing', () => {
    for (const [phase, ev] of [['idle', 'keep'], ['starting', 'keep'], ['trying', 'try'], ['ending', 'revert'], ['done', 'try']])
        assert.deepEqual(plain(F.step(phase, ev)), { phase, run: null, mark: false }, `${phase}/${ev}`);
});

test('countdown', () => {
    assert.equal(F.SECONDS, 30);
    assert.equal(F.remaining(0, 0), 30);
    assert.equal(F.remaining(0, 100), 30);
    assert.equal(F.remaining(0, 29001), 1);
    assert.equal(F.remaining(0, 30000), 0);
    assert.equal(F.remaining(0, 99999, 5), 0);
    assert.equal(F.fraction(15), 0.5);
    assert.equal(F.fraction(0, 0), 0);
});
