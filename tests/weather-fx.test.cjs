const { test } = require('node:test');
const assert = require('node:assert/strict');
const path = require('node:path');
const { loadLibrary } = require('./lib/qmljs.cjs');

const M = loadLibrary(path.join(__dirname, '../modules/theme/WeatherFxModel.js'));
const on = (extra) => Object.assign(M.options({ mode: 'subtle' }), extra || {});
const live = (code, tempC, month = 0, lat = 40) => ({ code, tempC, known: true, month, lat });

test('modes and toggles normalise with defaults', () => {
    assert.equal(M.normalizeMode('loud'), 'off');
    const o = M.options(null);
    assert.equal(o.mode, 'off');
    assert.equal(o.rain, true);
    assert.equal(o.heat, false, 'heat is off by default within the feature');
    assert.equal(o.seasonal, false);
    assert.equal(M.options({ heat: true, rain: false }).rain, false);
});

test('mode off draws nothing, whatever the weather', () => {
    const fx = M.effects(M.options({ mode: 'off' }), live(65, -5));
    assert.equal(fx.any, false);
    assert.equal(fx.rain, 0);
});

test('drizzle is lighter than rain, storms heaviest', () => {
    const d = M.condition(51), r = M.condition(63), s = M.condition(95);
    assert.equal(d.sky, 'drizzle');
    assert.equal(r.sky, 'rain');
    assert.equal(s.sky, 'storm');
    assert.ok(d.rain < r.rain && r.rain < s.rain);
    assert.ok(M.beadCount(d.rain, 'subtle', 60000) < M.beadCount(s.rain, 'subtle', 60000));
    assert.ok(M.cadence('rain', d.rain, 'subtle') > M.cadence('rain', s.rain, 'subtle'));
});

test('rain toggle off hides rain only', () => {
    const fx = M.effects(on({ rain: false }), live(45, 5));
    assert.equal(fx.rain, 0);
    assert.ok(fx.fog > 0);
    assert.equal(M.effects(on({ rain: false }), live(63, 10)).any, false);
});

test('frost below zero, snow settles, heat only when enabled and hot', () => {
    assert.equal(M.effects(on(), live(0, 2)).frost, 0);
    assert.ok(M.effects(on(), live(0, -1)).frost > 0);
    assert.ok(M.effects(on(), live(0, -12)).frost > M.effects(on(), live(0, -1)).frost);
    const snow = M.effects(on(), live(73, -2));
    assert.ok(snow.snow > 0 && snow.frost > 0);
    assert.equal(M.effects(on(), live(0, 36)).heat, 0, 'heat toggle defaults off');
    assert.ok(M.effects(on({ heat: true }), live(0, 36)).heat > 0);
    assert.equal(M.effects(on({ heat: true }), live(0, 25)).heat, 0);
});

test('unknown weather draws no weather, still the season', () => {
    const fx = M.effects(on({ seasonal: true }), { code: 63, tempC: NaN, known: false, month: 3, lat: 40 });
    assert.equal(fx.rain, 0);
    assert.equal(fx.seasonal, 'petals');
});

test('season follows the hemisphere', () => {
    assert.equal(M.season(48, 3), 'spring');
    assert.equal(M.season(-34, 3), 'autumn');
    assert.equal(M.season(-34, 9), 'spring');
    assert.equal(M.season(NaN, 9), 'autumn');
    assert.equal(M.season(10, 0), 'winter');
    assert.equal(M.hemisphere(-0.1), 'south');
});

test('petals in spring, leaves in autumn, not while it rains', () => {
    const o = on({ seasonal: true });
    assert.equal(M.effects(o, live(1, 15, 4)).seasonal, 'petals');
    assert.equal(M.effects(o, live(1, 15, 9)).seasonal, 'leaves');
    assert.equal(M.effects(o, live(1, 15, 9, -30)).seasonal, 'petals');
    assert.equal(M.effects(o, live(63, 15, 4)).seasonal, '');
    assert.equal(M.effects(on(), live(1, 15, 4)).seasonal, '', 'sub-toggle off by default');
});

test('a forced preview ignores mode and toggles', () => {
    for (const name of M.PREVIEWS) {
        const fx = M.effects(M.options({ mode: 'off', rain: false, frost: false, fog: false }), M.previewWeather(name), true);
        assert.ok(fx.any, name);
    }
    assert.equal(M.previewWeather('nope'), null);
    assert.equal(M.effects(M.options(null), M.previewWeather('leaves'), true).seasonal, 'leaves');
});

test('vivid is denser and stronger than subtle, counts stay capped', () => {
    assert.ok(M.strength('vivid') > M.strength('subtle'));
    assert.ok(M.beadCount(0.7, 'vivid', 80000) > M.beadCount(0.7, 'subtle', 80000));
    assert.ok(M.beadCount(1, 'vivid', 1e7) <= 22);
    assert.equal(M.beadCount(0, 'vivid', 80000), 0);
    assert.ok(M.flakeSlots(1, 'subtle', 1800) <= 18);
    assert.ok(M.flakeSlots(0.3, 'subtle', 600) < M.flakeSlots(0.9, 'subtle', 600));
    assert.ok(M.cadence('seasonal', 0, 'subtle') > 10000, 'petals stay occasional');
});

test('rng is deterministic per seed', () => {
    const a = M.rng(7), b = M.rng(7), c = M.rng(8);
    const x = [a(), a(), a()];
    assert.deepEqual(x, [b(), b(), b()]);
    assert.notDeepEqual(x, [c(), c(), c()]);
    assert.ok(x.every((v) => v >= 0 && v < 1));
});
