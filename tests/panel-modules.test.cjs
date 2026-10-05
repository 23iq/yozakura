const { test } = require('node:test');
const assert = require('node:assert/strict');
const path = require('node:path');

const qmljs = require('./lib/qmljs.cjs');
const lib = file => qmljs.loadLibrary(path.join(__dirname, '..', 'modules/bar/modules', file));
const plain = v => JSON.parse(JSON.stringify(v));

const WorldClock = lib('WorldClock.js');
const Stats = lib('StatsFormat.js');
const Magnify = lib('DockMagnify.js');
const Downloads = lib('Downloads.js');
const AppNames = lib('AppNames.js');

test('world clock offsets and wall time', () => {
    assert.equal(WorldClock.parseOffset('+0900'), 540);
    assert.equal(WorldClock.parseOffset('-0530'), -330);
    assert.equal(WorldClock.parseOffset('+05:45'), 345);
    assert.equal(WorldClock.parseOffset('junk'), null);
    const now = Date.UTC(2026, 9, 5, 23, 30);
    const tokyo = WorldClock.timeAt(now, 540, -300);
    assert.deepEqual(plain(tokyo), { hours: 8, minutes: 30, dayDelta: 1 });
    assert.equal(WorldClock.format(tokyo, false), '08:30');
    assert.equal(WorldClock.format({ hours: 0, minutes: 5 }, true), '12:05 AM');
    assert.equal(WorldClock.format({ hours: 15, minutes: 0 }, true), '3:00 PM');
    const zones = plain(WorldClock.zonesOf([{ zone: 'America/New_York' }, { label: 'X', zone: 'bad zone;rm' }, null]));
    assert.deepEqual(zones, [{ label: 'New York', zone: 'America/New_York' }]);
});

test('system stats formatting', () => {
    assert.equal(Stats.rate(512), '512B');
    assert.equal(Stats.rate(2.5 * 1024 * 1024), '2.5M');
    assert.equal(Stats.rate(15 * 1024), '15K');
    assert.equal(Stats.percent(123), '100%');
    assert.equal(Stats.temp(-1), '--°');
    assert.equal(Stats.temp(51.6), '52°');
    assert.deepEqual(plain(Stats.itemsOf(['cpu', 'bogus', 'net', 'cpu'])), ['cpu', 'net']);
    assert.deepEqual(plain(Stats.itemsOf(undefined)), ['cpu', 'ram']);
    assert.equal(Stats.level('cpu', 95), 2);
    assert.equal(Stats.level('gpuTemp', 72), 1);
});

test('dock magnification falls off smoothly', () => {
    assert.equal(Magnify.scaleAt(0, 52, 1.6), 1.6);
    assert.equal(Magnify.scaleAt(52 * 3, 52, 1.6), 1);
    const near = Magnify.scaleAt(30, 52, 1.6);
    const far = Magnify.scaleAt(90, 52, 1.6);
    assert.ok(near > far && far > 1 && near < 1.6);
    assert.equal(Magnify.scaleAt(10, 52, 1), 1);
    assert.equal(Magnify.dotCount(7), 3);
});

test('downloads helpers', () => {
    assert.equal(Downloads.isImage('a.JPG'), true);
    assert.equal(Downloads.iconFor('x.pdf'), 'application-pdf');
    assert.equal(Downloads.iconFor('noext'), 'text-x-generic');
    assert.equal(Downloads.isPartial('big.iso.part'), true);
    const fan = plain(Downloads.fan(4, 50, 1));
    assert.equal(fan.length, 4);
    assert.ok(fan[3].y < fan[0].y && fan[3].x > fan[0].x, 'rises and curls right');
    assert.ok(plain(Downloads.fan(3, 50, -1))[2].x < 0);
});

test('app names', () => {
    assert.equal(AppNames.pretty('org.gnome.Nautilus'), 'Nautilus');
    assert.equal(AppNames.pretty('visual-studio-code'), 'Visual Studio Code');
    assert.equal(AppNames.pretty(''), '');
});
