const { test } = require('node:test');
const assert = require('node:assert/strict');
const path = require('node:path');

const qmljs = require('./lib/qmljs.cjs');
const P = qmljs.loadLibrary(path.join(__dirname, '../modules/widgets/dashboard/wallpapers/WallpaperPause.js'));
const defaults = qmljs.loadLibrary(path.join(__dirname, '../config/defaults/performance.js')).data;

test('plays when nothing holds it', () => {
    assert.equal(P.shouldPause({}, defaults), false);
    assert.equal(P.shouldPause({ idleSeconds: 59 }, defaults), false);
});

test('lock, fullscreen and full coverage pause', () => {
    assert.equal(P.shouldPause({ locked: true }, defaults), true);
    assert.equal(P.shouldPause({ fullscreen: true }, defaults), true);
    assert.equal(P.shouldPause({ fullscreen: true }, { ...defaults, pauseWallpaperOnFullscreen: false }), false);
    assert.equal(P.shouldPause({ covered: true }, defaults), true);
});

test('idle pauses after the configured delay, unless turned off', () => {
    assert.equal(P.shouldPause({ idleSeconds: defaults.pauseWallpaperIdleDelay }, defaults), true);
    assert.equal(P.shouldPause({ idleSeconds: 10 }, { ...defaults, pauseWallpaperIdleDelay: 10 }), true);
    assert.equal(P.shouldPause({ idleSeconds: 9999 }, { ...defaults, pauseWallpaperOnIdle: false }), false);
    // Broken delay values use the default.
    assert.equal(P.shouldPause({ idleSeconds: 30 }, { ...defaults, pauseWallpaperIdleDelay: 0 }), false);
    assert.equal(P.shouldPause({ idleSeconds: 60 }, { pauseWallpaperIdleDelay: 'x' }), true);
});

test('battery pause is opt-in', () => {
    assert.equal(defaults.pauseWallpaperOnBattery, false);
    assert.equal(P.shouldPause({ onBattery: true }, defaults), false);
    assert.equal(P.shouldPause({ onBattery: true }, { ...defaults, pauseWallpaperOnBattery: true }), true);
    assert.equal(P.shouldPause({ onBattery: false }, { ...defaults, pauseWallpaperOnBattery: true }), false);
});

test('missing config keeps the historical defaults', () => {
    assert.equal(P.shouldPause({ fullscreen: true }, undefined), true);
    assert.equal(P.shouldPause({ onBattery: true }, null), false);
});
