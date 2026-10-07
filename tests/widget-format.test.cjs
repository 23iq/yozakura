const { test } = require('node:test');
const assert = require('node:assert/strict');
const path = require('node:path');
const qmljs = require('./lib/qmljs.cjs');

const load = file => qmljs.loadLibrary(path.join(__dirname, file));
const fmt = load('../modules/widgets/dashboard/widgets/WidgetFormat.js');
const faces = load('../modules/bar/clock/ClockFaces.js');
const panel = load('../modules/bar/clock/ClockPanelLayout.js');
const tr = (k, ...a) => [k, ...a].join('|');

test('weather glyphs follow the WMO code groups and day / night', () => {
    assert.equal(fmt.weatherGlyph(0, true), 'sun');
    assert.equal(fmt.weatherGlyph(0, false), 'moon');
    assert.equal(fmt.weatherGlyph(2, true), 'cloudSun');
    assert.equal(fmt.weatherGlyph(1, false), 'cloudMoon');
    assert.equal(fmt.weatherGlyph(3), 'cloud');
    assert.equal(fmt.weatherGlyph(45), 'cloudFog');
    for (const c of [51, 61, 65, 80, 82])
        assert.equal(fmt.weatherGlyph(c), 'cloudRain', String(c));
    for (const c of [71, 75, 77, 85, 86])
        assert.equal(fmt.weatherGlyph(c), 'cloudSnow', String(c));
    assert.equal(fmt.weatherGlyph(95), 'cloudLightning');
    assert.equal(fmt.weatherGlyph('x'), 'sun', 'garbage is clear sky');
});

test('temperatures round and never read -0', () => {
    assert.equal(fmt.temp(17.6), '18°');
    assert.equal(fmt.temp(-0.3), '0°');
    assert.equal(fmt.temp(-4.5), '-4°');
});

test('weather details leave out what the source lacks', () => {
    assert.equal(fmt.weatherDetails({ max: 21.2, min: 11.8, rain: 40, wind: 12.4 }, tr),
        'clock.panel.high_low|21°|12° · clock.panel.rain|40 · clock.panel.wind|12');
    assert.equal(fmt.weatherDetails({ max: 3, min: -1, rain: -1, wind: null }, tr), 'clock.panel.high_low|3°|-1°');
    assert.equal(fmt.weatherDetails(null, tr), '');
});

test('zone offsets read against the local zone', () => {
    assert.equal(fmt.offsetLabel(540, 180), '+6h');
    assert.equal(fmt.offsetLabel(-300, 0), '−5h');
    assert.equal(fmt.offsetLabel(570, 180), '+6h30');
    assert.equal(fmt.offsetLabel(185, 180), '+0h05');
    assert.equal(fmt.offsetLabel(180, 180), '0h');
    assert.equal(fmt.offsetLabel(null, 180), '');
});

test('media time is m:ss or h:mm:ss', () => {
    assert.equal(fmt.mediaTime(104.9), '1:44');
    assert.equal(fmt.mediaTime(3723), '1:02:03');
    assert.equal(fmt.mediaTime(-3), '0:00');
});

test('pomodoro label: focus with the round, breaks by name', () => {
    assert.equal(fmt.pomodoroLabel(null, tr), 'clock.panel.focus · clock.panel.round_of|1|4');
    assert.equal(fmt.pomodoroLabel({ pomodoro: { phase: 'work', round: 3, every: 4 } }, tr),
        'clock.panel.focus · clock.panel.round_of|3|4');
    assert.equal(fmt.pomodoroLabel({ pomodoro: { phase: 'break', round: 3 } }, tr), 'clock.panel.break');
    assert.equal(fmt.pomodoroLabel({ pomodoro: { phase: 'longBreak' } }, tr), 'clock.panel.long_break');
    assert.equal(fmt.pomodoroPhase({ pomodoro: { phase: 'odd' } }).phase, 'work');
});

test('kanji weekday', () => {
    assert.equal(faces.kanjiWeekday(0), '日曜日');
    assert.equal(faces.kanjiWeekday(2), '火曜日');
    assert.equal(faces.kanjiWeekday(6), '土曜日');
    assert.equal(faces.kanjiWeekday(7), '日曜日');
});

test('clock panel style: column by default, unknown falls back', () => {
    assert.equal(panel.styleOf(null), 'column');
    assert.equal(panel.styleOf({ clock: {} }), 'column');
    assert.equal(panel.styleOf({ clock: { panelStyle: 'wide' } }), 'wide');
    assert.equal(panel.styleOf({ clock: { panelStyle: 'bento' } }), 'bento');
    assert.equal(panel.styleOf({ clock: { panelStyle: 'grid' } }), 'column');
});
