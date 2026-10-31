const { test } = require('node:test');
const assert = require('node:assert/strict');
const path = require('node:path');
const { loadLibrary } = require('./lib/qmljs.cjs');

const L = loadLibrary(path.join(__dirname, '../modules/theme/LightModel.js'));
const base = { x: 0, y: 0, blur: 1, opacity: 0.5 };

test('unknown modes are off', () => {
    assert.equal(L.normalizeMode('disco'), 'off');
    assert.equal(L.normalizeMode('sun'), 'sun');
});

test('fixed light from the top-left casts down-right', () => {
    const l = L.fixed(-45);
    assert.ok(l.dx > 0 && l.dy > 0);
    assert.ok(l.side < 0, 'lit edge on the left');
    const s = L.shadow(L.fixed(0), base, 4);
    assert.deepEqual([s.x, s.y], [0, 4]);
});

test('noon: short, sharp shadow straight down', () => {
    const l = L.sun(180, 62, 51);
    assert.ok(Math.abs(l.dx) < 0.05);
    assert.ok(l.length < 0.7, `length ${l.length}`);
    assert.ok(l.blur < 0.8);
    assert.ok(Math.abs(l.warmth) < 0.05);
});

test('morning sun on the left: long, soft shadow to the right, warm', () => {
    const l = L.sun(95, 8, 48);
    assert.ok(l.side < -0.9, 'light on the left');
    assert.ok(l.dx > 0.7, `dx ${l.dx}`);
    assert.ok(l.length > 2);
    assert.ok(l.blur > 0.9);
    assert.ok(l.warmth > 0.5);
    const evening = L.sun(265, 8, 48);
    assert.ok(evening.dx < -0.7, 'evening shadow falls left');
});

test('southern hemisphere mirrors the sides', () => {
    assert.ok(L.sun(80, 10, -33).dx < 0);
});

test('night: minimal, diffuse, cool', () => {
    const l = L.sun(0, -30, 48);
    assert.ok(l.night);
    assert.equal(l.day, 0);
    assert.ok(l.strength < 0.5);
    assert.ok(l.length < 0.4);
    assert.ok(l.warmth < 0);
    assert.equal(l.side, 0);
});

test('shadow keeps a minimum length and clamps blur/opacity', () => {
    const s = L.shadow(L.sun(95, 8, 48), { x: 0, y: 0, blur: 1, opacity: 1 }, 4);
    assert.ok(s.x >= 8);
    assert.ok(s.blur <= 1 && s.opacity <= 1);
});

test('lantern: always, at night only, or off', () => {
    assert.equal(L.lanternOn('always', false), true);
    assert.equal(L.lanternOn('night', false), false);
    assert.equal(L.lanternOn('night', true), true);
    assert.equal(L.lanternOn('off', true), false);
});

test('time of day reads at a glance: golden hour shadows far longer than noon', () => {
    const golden = L.shadow(L.sun(95, 6, 48), base, 6);
    const noon = L.shadow(L.sun(180, 35, 48), base, 6);
    const night = L.shadow(L.sun(0, -30, 48), base, 6);
    assert.ok(golden.x >= 18, `golden x ${golden.x}`);
    assert.ok(Math.hypot(golden.x, golden.y) > 2.5 * Math.hypot(noon.x, noon.y));
    assert.ok(golden.blur > noon.blur, 'golden hour is softer');
    assert.ok(night.opacity <= 0.25 * 0.5, 'night shadows almost gone');
});

test('strength scales departures from the neutral light', () => {
    assert.equal(L.strengthScale('normal'), 1);
    assert.ok(L.strengthScale('subtle') < 1 && L.strengthScale('dramatic') > 1);
    assert.equal(L.strengthScale('loud'), 1);
    const m = L.sun(95, 8, 48);
    const subtle = L.withStrength(m, L.strengthScale('subtle'));
    const dramatic = L.withStrength(m, L.strengthScale('dramatic'));
    assert.ok(subtle.length < m.length && m.length < dramatic.length);
    assert.ok(subtle.warmth < m.warmth && m.warmth < dramatic.warmth);
    assert.equal(dramatic.dx, m.dx, 'direction kept');
    const noon = L.sun(180, 62, 51);
    assert.ok(L.withStrength(noon, 1.6).length < L.withStrength(m, 1.6).length);
    const night = L.withStrength(L.sun(0, -30, 48), 1.6);
    assert.ok(night.strength > 0 && night.strength < 0.2);
    assert.equal(L.withStrength(null, 1), null);
});
