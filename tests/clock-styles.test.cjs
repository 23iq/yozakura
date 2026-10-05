const { test } = require('node:test');
const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');
const qmljs = require('./lib/qmljs.cjs');

const loadLibrary = file => qmljs.loadLibrary(path.join(__dirname, file));

const text = loadLibrary('../modules/desktop/clockstyles/ClockText.js');
const registry = loadLibrary('../modules/desktop/clockstyles/ClockStyleRegistry.js');
const placement = loadLibrary('../modules/desktop/clockstyles/ClockPlacement.js');
const validator = loadLibrary('../config/ConfigValidator.js');
const desktopDefaults = JSON.parse(JSON.stringify(loadLibrary('../config/defaults/desktop.js').data));
const plain = value => JSON.parse(JSON.stringify(value));

// ---------------------------------------------------------------- kanji

test('kanji numbers cover 1..31 with 十/二十/三十 forms', () => {
    const expected = {
        1: '一', 5: '五', 9: '九', 10: '十', 11: '十一', 12: '十二', 19: '十九',
        20: '二十', 21: '二十一', 29: '二十九', 30: '三十', 31: '三十一'
    };
    for (const [n, k] of Object.entries(expected))
        assert.equal(text.kanjiNumber(Number(n)), k, `kanjiNumber(${n})`);
});

test('kanji dates for every month and the day forms', () => {
    const months = ['一', '二', '三', '四', '五', '六', '七', '八', '九', '十', '十一', '十二'];
    months.forEach((m, i) => assert.equal(text.kanjiDate(new Date(2026, i, 1)), `${m}月一日`));
    assert.equal(text.kanjiDate(new Date(2026, 9, 5)), '十月五日');
    assert.equal(text.kanjiDate(new Date(2026, 9, 10)), '十月十日');
    assert.equal(text.kanjiDate(new Date(2026, 9, 11)), '十月十一日');
    assert.equal(text.kanjiDate(new Date(2026, 9, 20)), '十月二十日');
    assert.equal(text.kanjiDate(new Date(2026, 9, 21)), '十月二十一日');
    assert.equal(text.kanjiDate(new Date(2026, 9, 30)), '十月三十日');
    assert.equal(text.kanjiDate(new Date(2026, 9, 31)), '十月三十一日');
    assert.equal(text.kanjiDate(new Date(2026, 11, 31)), '十二月三十一日');
});

test('kanji weekdays, Sunday to Saturday', () => {
    // 2026-10-04 is a Sunday.
    const days = ['日曜日', '月曜日', '火曜日', '水曜日', '木曜日', '金曜日', '土曜日'];
    days.forEach((d, i) => assert.equal(text.kanjiWeekday(new Date(2026, 9, 4 + i)), d));
});

test('every glyph the kanji helpers can produce is in the bundled font subset', () => {
    const subsetChars = new Set(Array.from('0123456789時分一二三四五六七八九十〇月日曜火水木金土夜桜午前後'));
    for (let m = 0; m < 12; m++) {
        for (let d = 1; d <= 31; d++) {
            const date = new Date(2026, m, d, d % 24);
            for (const ch of text.kanjiDate(date) + text.kanjiWeekday(date) + text.kanjiMeridiem(date))
                assert.ok(subsetChars.has(ch), `missing glyph ${ch}`);
        }
    }
});

test('hours, minutes and meridiem in 24h and 12h', () => {
    const at = (h, m) => new Date(2026, 9, 5, h, m);
    assert.equal(text.hours(at(9, 5), false), '09');
    assert.equal(text.hours(at(21, 47), false), '21');
    assert.equal(text.hours(at(0, 0), false), '00');
    assert.equal(text.hours(at(0, 0), true), '12');
    assert.equal(text.hours(at(12, 0), true), '12');
    assert.equal(text.hours(at(21, 47), true), '9');
    assert.equal(text.minutes(at(21, 5)), '05');
    assert.equal(text.kanjiMeridiem(at(11, 59)), '午前');
    assert.equal(text.kanjiMeridiem(at(12, 0)), '午後');
    assert.equal(text.meridiem(at(0, 30)), 'AM');
    assert.equal(text.meridiem(at(23, 30)), 'PM');
});

// ------------------------------------------------------------- registry

test('registry: default style exists and unknown ids fall back to it', () => {
    assert.ok(registry.has(registry.DEFAULT_ID));
    assert.equal(desktopDefaults.depthClockStyle, registry.DEFAULT_ID);
    assert.deepEqual(plain(registry.ids()), ['yozakura', 'poster']);
    assert.equal(registry.get('nope').id, registry.DEFAULT_ID);
    for (const s of registry.styles) {
        assert.ok(fs.existsSync(path.join(__dirname, '../modules/desktop/clockstyles', s.file)), s.file);
        assert.equal(typeof s.layout, 'function');
        assert.ok(s.sides.length > 0);
    }
});

test('registry: layouts stay inside the safe area on common screens', () => {
    const screens = [[1920, 1080], [2560, 1440], [3840, 2160], [3440, 1440], [1080, 1920]];
    for (const s of registry.styles) {
        for (const [w, h] of screens) {
            const area = { x: 52, y: 52, w: w - 60, h: h - 60 };
            for (const side of s.sides) {
                for (const use12h of [false, true]) {
                    const L = s.layout({ screenW: w, screenH: h, area, side, use12h });
                    for (const b of [L.behind, L.bounds].concat(L.legible || [])) {
                        const where = `${s.id} ${w}x${h} ${side}`;
                        assert.ok(b.w > 0 && b.h > 0, where);
                        assert.ok(b.x >= area.x - 1 && b.x + b.w <= area.x + area.w + 1, `${where}: x ${b.x}..${b.x + b.w}`);
                        assert.ok(b.y >= area.y - 1 && b.y + b.h <= area.y + area.h + 1, `${where}: y ${b.y}..${b.y + b.h}`);
                    }
                    if (side === 'left')
                        assert.ok(L.behind.x + L.behind.w / 2 < area.x + area.w / 2);
                    else
                        assert.ok(L.behind.x + L.behind.w / 2 > area.x + area.w / 2);
                }
            }
        }
    }
});

// ------------------------------------------------------------ placement

// Synthetic grid: subject occupies columns [c0, c1), backdrop luminance `lum`.
function grid(cols, rows, c0, c1, lum = 0.2) {
    let cover = '', l = '';
    const hx = v => Math.round(v * 255).toString(16).padStart(2, '0');
    for (let r = 0; r < rows; r++)
        for (let c = 0; c < cols; c++) {
            cover += hx(c >= c0 && c < c1 ? 1 : 0);
            l += hx(lum);
        }
    return { cols, rows, cover, lum: l };
}

const W = 2560, H = 1440;
const areas = { left: { x: 0, y: 52, w: W, h: H - 52 }, right: { x: 0, y: 52, w: W, h: H - 52 } };
const opts = extra => Object.assign({ screenW: W, screenH: H, areas, position: 'auto', preferSide: 'left', use12h: false }, extra);

test('placement: coverage and luminance are area-weighted box means', () => {
    const g = grid(96, 54, 0, 48, 0.8);
    assert.equal(placement.coverage(g, { x: 0, y: 0, w: W / 2, h: H }, W, H), 1);
    assert.equal(placement.coverage(g, { x: W / 2, y: 0, w: W / 2, h: H }, W, H), 0);
    assert.ok(Math.abs(placement.coverage(g, { x: W / 4, y: 0, w: W / 2, h: H }, W, H) - 0.5) < 0.02);
    assert.ok(Math.abs(placement.luminance(g, { x: 10, y: 10, w: 100, h: 100 }, W, H) - 0.8) < 0.01);
    assert.equal(placement.coverage({ cols: 2, rows: 2, cover: 'ff', lum: 'ff' }, { x: 0, y: 0, w: 10, h: 10 }, W, H), 0);
});

for (const style of registry.styles) {
    test(`placement (${style.id}): goes to the side away from the subject, behind it`, () => {
        const subjectLeft = placement.choose(style, grid(96, 54, 0, 40), opts());
        assert.equal(subjectLeft.side, 'right');
        assert.equal(subjectLeft.depth, true);
        assert.equal(subjectLeft.light, false);
        const subjectRight = placement.choose(style, grid(96, 54, 56, 96, 0.9), opts({ preferSide: 'right' }));
        assert.equal(subjectRight.side, 'left');
        assert.equal(subjectRight.light, true);
    });

    test(`placement (${style.id}): heavy coverage falls back to drawing in front`, () => {
        const full = placement.choose(style, grid(96, 54, 0, 96), opts());
        assert.equal(full.depth, false);
        assert.ok(full.coverage > placement.MAX_COVER);
    });

    test(`placement (${style.id}): forced position, preferred side and no data`, () => {
        const forced = placement.choose(style, grid(96, 54, 56, 96), opts({ position: 'right' }));
        assert.equal(forced.side, 'right');
        const empty = placement.choose(style, grid(96, 54, 0, 0), opts({ preferSide: 'right' }));
        assert.equal(empty.side, 'right');
        const none = placement.choose(style, null, opts({ preferSide: 'right' }));
        assert.equal(none.side, 'right');
        assert.equal(none.measured, false);
        assert.equal(none.depth, false);
        assert.equal(none.light, false);
        assert.ok(none.layout && none.layout.behind);
    });
}

test('placement: one hidden digit group is enough to draw in front', () => {
    const style = registry.get('poster');
    // Subject over the lower half only, where the minutes sit on the left.
    const g = grid(96, 54, 0, 0);
    const rows = [];
    for (let r = 0; r < 54; r++)
        for (let c = 0; c < 96; c++)
            rows.push(r >= 30 && c < 30 ? 'ff' : '00');
    g.cover = rows.join('');
    const r = placement.choose(style, g, opts({ position: 'left' }));
    assert.equal(r.side, 'left');
    assert.equal(r.depth, false);
});

// ------------------------------------------------------------ validator

test('validator: unknown clock styles and positions fall back to the defaults', () => {
    const bad = validator.validate({ depthClockStyle: 'bogus', depthClockPosition: 'center' }, desktopDefaults);
    assert.equal(bad.depthClockStyle, 'yozakura');
    assert.equal(bad.depthClockPosition, 'auto');
    const good = validator.validate({ depthClockStyle: 'poster', depthClockPosition: 'right' }, desktopDefaults);
    assert.equal(good.depthClockStyle, 'poster');
    assert.equal(good.depthClockPosition, 'right');
});

test('placement: unstable video mattes keep the clock in front', () => {
    const style = registry.get('yozakura');
    const g = grid(96, 54, 0, 40);
    g.jitter = '20'.repeat(96 * 54); // ~0.125 mean change per frame everywhere
    const r = placement.choose(style, g, opts());
    assert.ok(r.instability > placement.MAX_INSTABILITY);
    assert.equal(r.depth, false);
    g.jitter = '02'.repeat(96 * 54);
    assert.equal(placement.choose(style, g, opts()).depth, true);
});

test('placement: a readable side beats a less covered but unusable one', () => {
    const style = registry.get('yozakura');
    // Flicker only on the right edge, subject only on the left edge (light).
    const g = grid(96, 54, 0, 4);
    const jit = [];
    for (let r = 0; r < 54; r++)
        for (let c = 0; c < 96; c++)
            jit.push(c >= 80 ? '40' : '00');
    g.jitter = jit.join('');
    const r = placement.choose(style, g, opts({ preferSide: 'right' }));
    assert.equal(r.side, 'left');
    assert.equal(r.depth, true);
    assert.ok(r.reach >= 0);
});
