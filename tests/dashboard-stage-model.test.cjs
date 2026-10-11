const { test } = require('node:test');
const assert = require('node:assert/strict');
const path = require('node:path');
const qmljs = require('./lib/qmljs.cjs');

const m = qmljs.loadLibrary(path.join(__dirname, '../modules/widgets/dashboard/stage/StageModel.js'));
const plain = value => JSON.parse(JSON.stringify(value));

test('greetingKey follows the hour', () => {
    assert.equal(m.greetingKey(7), 'dashboard.stage.greeting.morning');
    assert.equal(m.greetingKey(13), 'dashboard.stage.greeting.afternoon');
    assert.equal(m.greetingKey(20), 'dashboard.stage.greeting.evening');
    assert.equal(m.greetingKey(2), 'dashboard.stage.greeting.night');
    assert.equal(m.greetingKey(23), 'dashboard.stage.greeting.night');
});

test('relativeIn: now, minutes, hours, nothing beyond a day', () => {
    assert.deepEqual(plain(m.relativeIn(20000)), { key: 'dashboard.stage.now', n: 0 });
    assert.deepEqual(plain(m.relativeIn(40 * 60000)), { key: 'dashboard.stage.in_min', n: 40 });
    assert.deepEqual(plain(m.relativeIn(3 * 3600000)), { key: 'dashboard.stage.in_hours', n: 3 });
    assert.equal(m.relativeIn(30 * 3600000).key, '');
    assert.equal(m.relativeIn(-5 * 60000).key, '');
    assert.equal(m.relativeIn(undefined).key, '');
});

test('eventAt parses the khal date formats', () => {
    const at = new Date(2026, 9, 11, 14, 30).getTime();
    assert.equal(m.eventAt('2026-10-11', '14:30'), at);
    assert.equal(m.eventAt('11.10.2026', '14:30'), at);
    assert.equal(m.eventAt('10/11/2026', '14.30'), at);
    assert.equal(m.eventAt('11.10.26', ''), new Date(2026, 9, 11).getTime());
    assert.ok(Number.isNaN(m.eventAt('tomorrow', '')));
});

test('nextRows: pomodoro first, then soonest; past events dropped', () => {
    const now = new Date(2026, 9, 11, 13, 50).getTime();
    const rows = m.nextRows({
        now,
        events: [
            { date: '2026-10-11', time: '09:00', title: 'Standup' },
            { date: '2026-10-11', time: '14:30', title: 'Sync with Mira' },
            { date: '2026-10-11', time: '', title: 'Holiday' },
            { date: '2026-10-12', time: '10:00', title: 'Deck review' }
        ],
        timers: [{ name: 'Focus', leftMs: 600000, pomodoro: true }, { name: 'Tea', leftMs: 120000 }],
        reminders: []
    }, 0);
    assert.deepEqual(plain(rows.map(r => r.title)), ['Focus', 'Holiday', 'Tea', 'Sync with Mira', 'Deck review']);
    assert.equal(rows[0].kind, 'pomodoro');
    assert.equal(rows[3].leftMs, 40 * 60000);
    assert.equal(rows[3].today, true);
    assert.equal(rows[4].today, false);
    assert.equal(rows[1].allDay, true);
    assert.equal(m.nextRows({ now, events: [], timers: [], reminders: [] }, 3).length, 0);
    assert.equal(m.nextRows(null, 3).length, 0);
    assert.equal(m.nextRows({ now, timers: [{ name: 'a', leftMs: 1 }, { name: 'b', leftMs: 2 }] }, 1).length, 1);
});

test('clock formats remaining time', () => {
    assert.equal(m.clock(65000), '1:05');
    assert.equal(m.clock(3725000), '1:02:05');
    assert.equal(m.clock(-1), '0:00');
});

test('weekDays: seven days from the first weekday, today marked', () => {
    const days = m.weekDays(new Date(2026, 9, 11), 1); // Sunday, week from Monday
    assert.equal(days.length, 7);
    assert.deepEqual(plain(days.map(d => d.day)), [5, 6, 7, 8, 9, 10, 11]);
    assert.equal(days[6].today, true);
    assert.equal(days[0].past, true);
    assert.equal(days[0].weekday, 1);
    const sunday = m.weekDays(new Date(2026, 9, 11), 0);
    assert.equal(sunday[0].day, 11);
    assert.equal(sunday[0].today, true);
    assert.equal(sunday[6].day, 17);
});

test('eventDays keys match weekDays iso', () => {
    const days = m.eventDays([{ date: '2026-10-12', time: '10:00', title: 'x' }, { date: 'junk', title: 'y' }]);
    assert.deepEqual(plain(days), { '2026-10-12': true });
    assert.equal(m.weekDays(new Date(2026, 9, 12), 1)[0].iso, '2026-10-12');
});

test('averageTone prefers saturated pixels, null when transparent', () => {
    // two black pixels and one saturated red pixel
    const tone = m.averageTone([0, 0, 0, 255, 0, 0, 0, 255, 230, 40, 40, 255]);
    assert.ok(tone.r > 0.5 && tone.g < 0.2, JSON.stringify(tone));
    assert.equal(m.averageTone([255, 0, 0, 0]), null);
    assert.equal(m.averageTone(null), null);
});

test('tintAlpha keeps the ink readable', () => {
    const dark = { r: 0.08, g: 0.07, b: 0.08 };
    const light = { r: 0.95, g: 0.94, b: 0.95 };
    const inkLight = { r: 0.93, g: 0.9, b: 0.92 };
    const yellow = { r: 1, g: 0.9, b: 0.2 };
    const navy = { r: 0.1, g: 0.15, b: 0.4 };
    assert.equal(m.tintAlpha(navy, dark, inkLight, 0.4, 4.5), 0.4);
    const a = m.tintAlpha(yellow, dark, inkLight, 0.8, 4.5);
    assert.ok(a < 0.8 && a >= 0, String(a));
    assert.ok(m.contrast(m.mix(dark, yellow, a), inkLight) >= 4.5);
    assert.equal(m.tintAlpha(null, dark, inkLight, 0.4, 4.5), 0);
    // a light theme with dark ink: dark art is held back too
    const b = m.tintAlpha({ r: 0, g: 0, b: 0 }, light, { r: 0.1, g: 0.1, b: 0.1 }, 0.6, 4.5);
    assert.ok(m.contrast(m.mix(light, { r: 0, g: 0, b: 0 }, b), { r: 0.1, g: 0.1, b: 0.1 }) >= 4.5);
});

test('rate formats bytes per second', () => {
    assert.equal(m.rate(820), '820 B/s');
    assert.equal(m.rate(12 * 1024), '12 KB/s');
    assert.equal(m.rate(1.4 * 1024 * 1024), '1.4 MB/s');
    assert.equal(m.rate(25 * 1024 * 1024), '25 MB/s');
    assert.equal(m.rate(-3), '0 B/s');
});
