const { test } = require('node:test');
const assert = require('node:assert/strict');
const path = require('node:path');
const qmljs = require('./lib/qmljs.cjs');

const load = file => qmljs.loadLibrary(path.join(__dirname, file));
const faces = load('../modules/bar/clock/ClockFaces.js');
const glyphs = load('../modules/bar/clock/faces/DotMatrixGlyphs.js');
const pomo = load('../modules/bar/clock/PomodoroStyles.js');
const panel = load('../modules/bar/clock/ClockPanelLayout.js');
const agenda = load('../modules/widgets/dashboard/widgets/time/AgendaModel.js');
const registry = load('../modules/widgets/dashboard/widgets/WidgetRegistry.js');
const grid = load('../modules/widgets/dashboard/widgets/BentoGrid.js');
const plain = v => JSON.parse(JSON.stringify(v));

// ---------------------------------------------------------------- kanji

test('kanji minutes 0..59: 零分, 一分 .. 十分, 十一分, 二十五分, 五十九分', () => {
    const expected = { 0: '零分', 1: '一分', 9: '九分', 10: '十分', 11: '十一分', 19: '十九分',
        20: '二十分', 25: '二十五分', 30: '三十分', 42: '四十二分', 59: '五十九分' };
    for (const [m, text] of Object.entries(expected))
        assert.equal(faces.kanjiMinutes(Number(m)), text, `minute ${m}`);
    const all = [];
    for (let m = 0; m < 60; m++)
        all.push(faces.kanjiMinutes(m));
    assert.equal(new Set(all).size, 60, 'every minute is distinct');
    for (const text of all)
        assert.match(text, /^[零一二三四五六七八九十]+分$/, 'only kanji numerals');
});

test('kanji time: 十時 二十五分; midnight is 零時; on the hour keeps 零分', () => {
    assert.equal(faces.kanjiTime(10, 25, false), '十時 二十五分');
    assert.equal(faces.kanjiTime(0, 0, false), '零時 零分');
    assert.equal(faces.kanjiTime(23, 59, false), '二十三時 五十九分');
    assert.equal(faces.kanjiTime(12, 0, false), '十二時 零分');
});

test('kanji time in 12h: 午前/午後 with 1..12 hours', () => {
    assert.equal(faces.kanjiTime(0, 5, true), '午前 十二時 五分');
    assert.equal(faces.kanjiTime(13, 30, true), '午後 一時 三十分');
    assert.equal(faces.kanjiTime(12, 0, true), '午後 十二時 零分');
});

// ---------------------------------------------------------------- digital

test('digital parts: 24h padded, 12h with suffix', () => {
    assert.deepEqual(plain(faces.parts(7, 5, false)), { hours: '07', minutes: '05', suffix: '' });
    assert.deepEqual(plain(faces.parts(19, 45, true)), { hours: '7', minutes: '45', suffix: 'PM' });
    assert.deepEqual(plain(faces.parts(0, 0, true)), { hours: '12', minutes: '00', suffix: 'AM' });
});

// ---------------------------------------------------------------- registry

test('face registry: known faces resolve, unknown falls back to digital', () => {
    assert.deepEqual(plain(faces.ids()), ['digital', 'stacked', 'dotMatrix', 'kanji']);
    assert.equal(faces.resolve('kanji', false).id, 'kanji');
    assert.equal(faces.resolve('dotMatrix', false).url, 'faces/DotMatrix.qml');
    assert.equal(faces.resolve('bogus', false).id, 'digital');
    assert.equal(faces.resolve(undefined, false).id, 'digital');
});

test('a vertical bar turns digital into stacked, keeps the others', () => {
    assert.equal(faces.resolve('digital', true).id, 'stacked');
    assert.equal(faces.resolve('bogus', true).id, 'stacked');
    assert.equal(faces.resolve('kanji', true).id, 'kanji');
    assert.equal(faces.resolve('stacked', false).id, 'stacked');
});

// ---------------------------------------------------------------- dot matrix

test('dot matrix glyphs: 3x5 for every digit and the colon, unknown is blank', () => {
    for (const ch of '0123456789:') {
        const g = glyphs.glyph(ch);
        assert.equal(g.length, 15, ch);
        assert.ok(g.some(Boolean), `${ch} has dots`);
    }
    assert.deepEqual(plain(glyphs.glyph('1')), [0, 1, 0, 1, 1, 0, 0, 1, 0, 0, 1, 0, 1, 1, 1]);
    assert.ok(glyphs.glyph('x').every(d => d === 0));
    assert.equal(glyphs.glyph(':').filter(Boolean).length, 2);
});

// ---------------------------------------------------------------- pomodoro

test('pomodoro styles: ring default, slots, island has no bar view', () => {
    assert.deepEqual(plain(pomo.ids()), ['ring', 'underline', 'countdown', 'island']);
    assert.equal(pomo.resolve('bogus').id, 'ring');
    assert.equal(pomo.resolve('ring').slot, 'inline');
    assert.equal(pomo.resolve('countdown').slot, 'inline');
    assert.equal(pomo.resolve('underline').slot, 'overlay');
    assert.equal(pomo.resolve('island').slot, 'none');
    assert.equal(pomo.resolve('island').url, '');
});

test('pomodoro state: idle, running work, break, ringing', () => {
    assert.deepEqual(plain(pomo.state(null)), { active: false, progress: 0, label: '', phase: '', ringing: false, running: false });
    const work = pomo.state({ leftMs: 754000, progress: 0.5, state: 'running', ringing: false, pomodoro: { phase: 'work' } });
    assert.deepEqual(plain(work), { active: true, progress: 0.5, label: '12:34', phase: 'work', ringing: false, running: true });
    const rest = pomo.state({ leftMs: 61000, progress: 0.2, state: 'paused', ringing: false, pomodoro: { phase: 'break' } });
    assert.equal(rest.phase, 'break');
    assert.equal(rest.running, false);
    const ring = pomo.state({ leftMs: 0, progress: 0, state: 'ringing', ringing: true, pomodoro: { phase: 'work' } });
    assert.equal(ring.ringing, true);
    assert.equal(ring.label, '00:00');
});

test('countdown label keeps a fixed width (always mm:ss under an hour)', () => {
    const widths = [1500000, 600000, 59000, 9000, 1000].map(ms => pomo.state({ leftMs: ms, progress: 1, state: 'running', pomodoro: { phase: 'work' } }).label.length);
    assert.ok(widths.every(w => w === 5), String(widths));
});

// ---------------------------------------------------------------- panel

test('clock panel default grid uses registered widgets and fits 2 columns', () => {
    const cells = panel.defaultGrid(panel.COLS);
    const ids = cells.map(c => c.widget);
    assert.deepEqual(plain(ids), ['weather', 'pomodoro', 'agenda', 'worldClocks']);
    const reg = { ids: registry.ids, byId: registry.byId, defaultGrid: panel.defaultGrid };
    const norm = grid.normalize([], panel.COLS, reg);
    assert.equal(norm.length, 4, 'nothing dropped by normalize');
    for (const c of norm)
        assert.ok(c.x + c.w <= panel.COLS, c.widget);
});

test('new widgets are registered host-agnostic', () => {
    for (const id of ['pomodoro', 'worldClocks', 'agenda']) {
        const w = registry.byId(id);
        assert.ok(w, id);
        assert.match(w.url, /^time\//);
        assert.ok(w.labelKey.startsWith('bento.widget.'));
    }
});

test('panel cells are written into a copy of moduleOptions', () => {
    const opts = { clock: { showWeather: false }, taskbar: { showLabels: true } };
    const next = plain(panel.withCells(opts, [{ widget: 'agenda', x: 0, y: 0, w: 1, h: 1 }]));
    assert.deepEqual(next, { clock: { showWeather: false, panel: { cells: [{ widget: 'agenda', x: 0, y: 0, w: 1, h: 1 }] } }, taskbar: { showLabels: true } });
    assert.equal(opts.clock.panel, undefined, 'input untouched');
    assert.deepEqual(plain(panel.withCells(null, [])), { clock: { panel: { cells: [] } } });
});

// ---------------------------------------------------------------- agenda

test('agenda: calendar events win when a source has them', () => {
    const rows = agenda.rows({ events: [{ title: 'Standup', at: 2000 }], reminders: [{ id: 'r', message: 'x', at: 1500, leftMs: 500 }], timers: [], now: 1000 });
    assert.equal(rows.length, 1);
    assert.equal(rows[0].kind, 'event');
    assert.equal(rows[0].title, 'Standup');
    assert.equal(rows[0].leftMs, 1000);
});

test('agenda: without events, reminders and timers soonest first, pomodoro excluded', () => {
    const rows = agenda.rows({
        events: null,
        reminders: [{ id: 'r1', message: 'Call', at: 9000, leftMs: 8000 }],
        timers: [{ id: 't1', name: 'Tea', leftMs: 3000, state: 'running' },
                 { id: 'p', name: '', leftMs: 100, state: 'running', pomodoro: { phase: 'work' } }],
        now: 1000
    });
    assert.deepEqual(plain(rows.map(r => r.id)), ['t1', 'r1']);
    assert.deepEqual(plain(rows.map(r => r.kind)), ['timer', 'reminder']);
    assert.equal(rows[1].title, 'Call');
});

test('agenda: limit and empty', () => {
    assert.deepEqual(plain(agenda.rows({ now: 0 })), []);
    const many = [];
    for (let i = 0; i < 10; i++)
        many.push({ id: 'r' + i, message: 'm', at: i, leftMs: i });
    assert.equal(agenda.rows({ reminders: many, now: 0 }, 3).length, 3);
});
