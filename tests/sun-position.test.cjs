const { test } = require('node:test');
const assert = require('node:assert/strict');
const path = require('node:path');
const { loadLibrary } = require('./lib/qmljs.cjs');

const S = loadLibrary(path.join(__dirname, '../modules/theme/SunPosition.js'));
const at = (iso, lat, lon) => S.position(Date.parse(iso), lat, lon);
const near = (a, b, tol, msg) => assert.ok(Math.abs(a - b) <= tol, `${msg}: ${a} vs ${b}`);

test('solstice noon at Greenwich: due south, 90 - lat + tilt', () => {
    const p = at('2024-06-21T12:02:00Z', 51.4769, 0);
    near(p.altitude, 61.96, 0.1, 'altitude');
    near(p.azimuth, 180, 0.5, 'azimuth');
    near(p.declination, 23.44, 0.02, 'declination');
});

test('equinox noon on the equator: overhead', () => {
    near(at('2024-03-20T12:07:00Z', 0, 0).altitude, 89.8, 0.3, 'altitude');
});

test('London solstice sunrise (03:43 UTC) and sunset (20:21 UTC)', () => {
    const rise = at('2024-06-21T03:43:00Z', 51.5074, -0.1278);
    near(rise.altitude, -0.83, 0.3, 'sunrise altitude');
    near(rise.azimuth, 49, 1, 'sunrise azimuth (north-east)');
    const set = at('2024-06-21T20:21:00Z', 51.5074, -0.1278);
    near(set.altitude, -0.83, 0.3, 'sunset altitude');
    near(set.azimuth, 311, 1, 'sunset azimuth (north-west)');
});

test('southern summer: Sydney noon sun stands to the north', () => {
    const p = at('2024-12-21T01:53:00Z', -33.87, 151.21);
    near(p.altitude, 79.57, 0.2, 'altitude');
    assert.ok(p.azimuth < 5 || p.azimuth > 355, `azimuth ${p.azimuth}`);
});

test('New York winter noon is low', () => {
    near(at('2024-12-21T16:54:00Z', 40.71, -74).altitude, 25.85, 0.2, 'altitude');
});

test('midnight is below the horizon', () => {
    assert.ok(at('2024-06-21T00:00:00Z', 48.85, 2.35).altitude < -10);
});

test('timezone fallback: longitude from the offset, a plausible latitude', () => {
    assert.deepEqual(JSON.parse(JSON.stringify(S.fromTimezone(-60))), { lat: 48, lon: 15 });
    assert.equal(S.fromTimezone(300).lon, -75);
    assert.ok(S.fromTimezone(-600).lat < 0, 'UTC+10 is mostly Australia');
    assert.equal(typeof S.fromTimezone(-345).lat, 'number');
});

test('place: known coordinates, then "lat,lon" text, then timezone', () => {
    assert.equal(S.resolvePlace(10, 20, '', 0).source, 'location');
    const c = S.resolvePlace(NaN, NaN, ' 40.4, -3.7 ', 0);
    assert.equal(c.source, 'coords');
    assert.equal(c.lat, 40.4);
    assert.equal(S.resolvePlace(NaN, NaN, 'Madrid', -60).source, 'timezone');
    assert.equal(S.parseCoords('95,10'), null);
});
