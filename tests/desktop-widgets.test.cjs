const { test } = require('node:test');
const assert = require('node:assert/strict');
const path = require('node:path');
const qmljs = require('./lib/qmljs.cjs');

const loadLibrary = file => qmljs.loadLibrary(path.join(__dirname, file));
const plain = value => JSON.parse(JSON.stringify(value));

const registry = loadLibrary('../modules/desktop/widgets/WidgetRegistry.js');
const geo = loadLibrary('../modules/desktop/widgets/WidgetGeometry.js');
const cal = loadLibrary('../modules/desktop/widgets/CalendarModel.js');
const net = loadLibrary('../modules/desktop/widgets/NetRate.js');
const clocks = loadLibrary('../modules/desktop/clockstyles/ClockStyleRegistry.js');
const validator = loadLibrary('../config/ConfigValidator.js');
const schema = loadLibrary('../modules/settings/schema/desktop.js');
const defaults = plain(loadLibrary('../config/defaults/desktop.js').data);

// ------------------------------------------------------------ registry

test('every widget type is complete and its file exists', () => {
    const fs = require('node:fs');
    const ids = registry.ids();
    assert.deepEqual(plain(ids), ['media', 'calendar', 'system', 'note', 'weather']);
    for (const t of registry.types) {
        assert.ok(t.labelKey && t.descKey && t.icon, t.id);
        assert.ok(fs.existsSync(path.join(__dirname, '../modules/desktop/widgets/types', t.file)), t.file);
        assert.ok(t.size.w >= t.minSize.w && t.size.h >= t.minSize.h, t.id);
        for (const o of t.options) {
            assert.ok(['toggle', 'select'].includes(o.type), `${t.id}.${o.key}`);
            if (o.type === 'select')
                assert.ok(o.choices.some(c => c.value === o.default), `${t.id}.${o.key} default`);
        }
    }
    assert.equal(registry.get('nope'), null);
});

test('options fill in registry defaults, own values win', () => {
    const w = { type: 'system', options: { net: false } };
    assert.deepEqual(plain(registry.options(w)), { cpu: true, ram: true, gpuTemp: true, net: false });
    assert.equal(registry.option({ type: 'note', options: { text: 'hi' } }, 'text'), 'hi');
    assert.equal(registry.option({ type: 'note' }, 'tint'), 'tertiary');
});

test('normalize: unknown types dropped, numbers clamped inside the screen, ids unique', () => {
    const list = registry.normalizeList([
        { type: 'media', x: 0.9, y: -1, w: 0.3, h: 2, options: [] },
        { type: 'bogus', x: 0, y: 0, w: 0.1, h: 0.1 },
        null,
        { id: 'a', type: 'note', x: 'x', y: 0.2, w: 0.1, h: 0.1 },
        { id: 'a', type: 'note', x: 0.1, y: 0.2, w: 0.1, h: 0.1, monitor: 'DP-1' }
    ]);
    assert.equal(list.length, 3);
    const m = list[0];
    assert.equal(m.type, 'media');
    assert.ok(Math.abs(m.x - 0.7) < 1e-9, m.x);
    assert.equal(m.y, 0);
    assert.equal(m.h, 1);
    assert.deepEqual(plain(m.options), {});
    assert.equal(m.monitor, '');
    assert.equal(list[1].x, 0);
    assert.notEqual(list[1].id, list[2].id);
    assert.equal(list[2].monitor, 'DP-1');
});

test('sizes scale with the screen height (never below 60 %)', () => {
    const big = registry.sizeFraction('calendar', 2560, 1440);
    assert.ok(Math.abs(big.w - 360 / 2560) < 1e-9 && Math.abs(big.h - 360 / 1440) < 1e-9);
    const small = registry.sizeFraction('calendar', 1280, 720);
    assert.ok(Math.abs(small.h * 720 - 360 * 0.6) < 1e-6, small.h * 720);
    const fhd = registry.minFraction('note', 1920, 1080);
    assert.ok(Math.abs(fhd.w * 1920 - 168 * 0.75) < 1e-6);
});

// ------------------------------------------------------------ geometry

const screen = { x: 0, y: 0, w: 2560, h: 1440 };

test('relative <-> pixels round trip', () => {
    const w = { x: 0.25, y: 0.5, w: 0.125, h: 0.1 };
    const px = geo.toPixels(w, 2560, 1440);
    assert.deepEqual(plain(px), { x: 640, y: 720, w: 320, h: 144 });
    assert.deepEqual(plain(geo.toRelative(px, 2560, 1440)), w);
    // The same layout on another resolution keeps its proportions.
    assert.deepEqual(plain(geo.toPixels(w, 1920, 1080)), { x: 480, y: 540, w: 240, h: 108 });
});

test('moved: snaps to the grid relative to the bounds and stays inside', () => {
    const b = { x: 16, y: 60, w: 2528, h: 1364 };
    const start = { x: 100, y: 200, w: 300, h: 200 };
    assert.deepEqual(plain(geo.moved(start, 13, 30, b, 24)), { x: 112, y: 228, w: 300, h: 200 });
    assert.deepEqual(plain(geo.moved(start, 5000, 5000, b, 24)), { x: 16 + 2528 - 300, y: 60 + 1364 - 200, w: 300, h: 200 });
    assert.deepEqual(plain(geo.moved(start, -5000, -5000, b, 24)), { x: 16, y: 60, w: 300, h: 200 });
    assert.deepEqual(plain(geo.moved(start, 7, 3, b, 0)), { x: 107, y: 203, w: 300, h: 200 });
});

test('resized: far edge on the grid, min size, never past the bounds', () => {
    const start = { x: 0, y: 0, w: 300, h: 200 };
    assert.deepEqual(plain(geo.resized(start, 10, 10, { w: 100, h: 100 }, screen, 24)), { x: 0, y: 0, w: 312, h: 216 });
    assert.deepEqual(plain(geo.resized(start, -1000, -1000, { w: 120, h: 96 }, screen, 24)), { x: 0, y: 0, w: 120, h: 96 });
    assert.deepEqual(plain(geo.resized({ x: 2400, y: 0, w: 100, h: 100 }, 900, 0, { w: 50, h: 50 }, screen, 0)), { x: 2400, y: 0, w: 160, h: 100 });
});

test('overlaps / intersection', () => {
    assert.equal(geo.overlaps({ x: 0, y: 0, w: 10, h: 10 }, { x: 5, y: 5, w: 10, h: 10 }), true);
    assert.equal(geo.overlaps({ x: 0, y: 0, w: 10, h: 10 }, { x: 10, y: 0, w: 10, h: 10 }), false);
    assert.equal(geo.overlaps({ x: 0, y: 0, w: 10, h: 10 }, null), false);
    assert.equal(geo.intersection({ x: 0, y: 0, w: 10, h: 10 }, { x: 5, y: 5, w: 10, h: 10 }), 25);
});

test('monitor assignment: own screen when connected, else the first one', () => {
    const names = ['DP-1', 'HDMI-A-1'];
    assert.equal(geo.screenFor({ monitor: 'HDMI-A-1' }, names), 'HDMI-A-1');
    assert.equal(geo.screenFor({ monitor: 'eDP-1' }, names), 'DP-1');
    assert.equal(geo.screenFor({ monitor: '' }, names), 'DP-1');
    assert.equal(geo.screenFor({ monitor: 'x' }, []), '');
    const list = [{ id: 1, monitor: 'HDMI-A-1' }, { id: 2, monitor: '' }, { id: 3, monitor: 'gone' }];
    assert.deepEqual(plain(geo.forScreen(list, 'DP-1', names).map(w => w.id)), [2, 3]);
    assert.deepEqual(plain(geo.forScreen(list, 'HDMI-A-1', names).map(w => w.id)), [1]);
});

test('freeSpot: right side first, clear of other widgets and the clock', () => {
    const size = { w: 400, h: 300 };
    const first = geo.freeSpot(size, screen, [], 24, 24);
    assert.ok(first.x + first.w <= 2560 - 24 && first.x > 2000, JSON.stringify(first));
    assert.equal(first.y % 24, 0);
    const clock = { x: 1800, y: 0, w: 760, h: 1440 };
    const spot = geo.freeSpot(size, screen, [clock], 24, 24);
    assert.equal(geo.overlaps({ x: spot.x - 24, y: spot.y - 24, w: spot.w + 48, h: spot.h + 48 }, clock), false);
    const taken = [clock, spot];
    const next = geo.freeSpot(size, screen, taken, 24, 24);
    assert.equal(geo.overlaps(next, spot), false);
    // Full screen: falls back to the top-right corner.
    const full = geo.freeSpot(size, screen, [screen], 24, 24);
    assert.equal(full.x, 2560 - 400 - 24);
});

test('covered: windows of the active workspace hiding the whole widget', () => {
    const mon = { id: 0, x: 2560, y: 0, width: 2560, height: 1440, scale: 1, transform: 0, activeWorkspace: { id: 3 } };
    const win = (x, y, w, h, extra) => Object.assign({ monitor: 0, workspace: { id: 3 }, hidden: false, at: [x, y], size: [w, h] }, extra || {});
    const r = { x: 100, y: 100, w: 300, h: 200 };
    assert.equal(geo.covered(r, mon, [win(2560, 0, 1280, 1440)]), true);
    assert.equal(geo.covered(r, mon, [win(2560 + 200, 0, 1280, 1440)]), false); // half visible
    assert.equal(geo.covered(r, mon, [win(2560, 0, 1280, 1440, { workspace: { id: 4 } })]), false);
    assert.equal(geo.covered(r, mon, [win(2560, 0, 1280, 1440, { hidden: true })]), false);
    assert.equal(geo.covered(r, null, []), false);
});

// ------------------------------------------------------------ calendar

test('month grid: 6x7 cells, week start, today and outside days', () => {
    const oct = new Date(2026, 9, 15);
    const monday = cal.monthGrid(oct, 1, new Date(2026, 9, 5));
    assert.equal(monday.length, 42);
    // 1 Oct 2026 is a Thursday: three September days lead on Monday weeks.
    assert.deepEqual(plain(monday.slice(0, 4).map(c => [c.day, c.inMonth])), [[28, false], [29, false], [30, false], [1, true]]);
    assert.ok(monday.find(c => c.today).day === 5);
    const sunday = cal.monthGrid(oct, 0, oct);
    assert.equal(sunday[4].day, 1);
    assert.equal(cal.rowsNeeded(oct, 1), 5);
    assert.equal(cal.rowsNeeded(new Date(2026, 1, 1), 0), 4); // Feb 2026 starts on Sunday
    assert.equal(cal.rowsNeeded(new Date(2026, 7, 1), 1), 6); // Aug 2026 starts on Saturday
    assert.equal(cal.firstDayOf('monday', 0), 1);
    assert.equal(cal.firstDayOf('sunday', 1), 0);
    assert.equal(cal.firstDayOf('locale', 7), 0);
    assert.deepEqual(plain(cal.weekdayOrder(1)), [1, 2, 3, 4, 5, 6, 0]);
});

test('khal output parsing', () => {
    const out = 'Mon 05.10.\t09:30\tStandup\n\n05.10.2026\t\tHoliday\tall day\n06.10.\t14.00\tDentist\nbroken line\n';
    assert.deepEqual(plain(cal.parseKhal(out, 0)), [
        { date: 'Mon 05.10.', time: '09:30', title: 'Standup' },
        { date: '05.10.2026', time: '', title: 'Holiday all day' },
        { date: '06.10.', time: '14.00', title: 'Dentist' }
    ]);
    assert.equal(cal.parseKhal(out, 2).length, 2);
    assert.deepEqual(plain(cal.parseKhal('', 4)), []);
});

// ------------------------------------------------------------ network

test('/proc/net/dev totals skip loopback; rates and formatting', () => {
    const dev = `Inter-|   Receive                                                |  Transmit
 face |bytes    packets errs drop fifo frame compressed multicast|bytes    packets errs drop fifo colls carrier compressed
    lo: 1000      10    0    0    0     0          0         0     1000      10    0    0    0     0       0          0
  eth0: 5000      50    0    0    0     0          0         0     2000      20    0    0    0     0       0          0
 wlan0: 300       3    0    0    0     0          0         0      100       1    0    0    0     0       0          0
`;
    assert.deepEqual(plain(net.totals(dev)), { rx: 5300, tx: 2100 });
    assert.deepEqual(plain(net.rate({ rx: 0, tx: 0 }, { rx: 2048, tx: 1024 }, 2000)), { rx: 1024, tx: 512 });
    assert.deepEqual(plain(net.rate(null, { rx: 1, tx: 1 }, 1000)), { rx: 0, tx: 0 });
    assert.deepEqual(plain(net.rate({ rx: 100, tx: 100 }, { rx: 0, tx: 0 }, 1000)), { rx: 0, tx: 0 }); // counter reset
    assert.equal(net.format(0), '0 B/s');
    assert.equal(net.format(1536), '1.5 KB/s');
    assert.equal(net.format(5 * 1024 * 1024), '5.0 MB/s');
    assert.deepEqual(plain(net.normalized([0, 50, 100], 10)), [0, 0.5, 1]);
    assert.deepEqual(plain(net.normalized([1, 2], 10)), [0.1, 0.2]);
    assert.deepEqual(plain(net.push([1, 2, 3], 4, 3)), [2, 3, 4]);
});

// ------------------------------------------------------------ config

test('defaults, validator and settings options stay in sync with the registries', () => {
    assert.equal(defaults.depthClockInk, 'auto');
    assert.deepEqual(defaults.widgets, []);
    assert.ok(registry.VARIANTS.includes(defaults.widgetVariant));
    const ok = plain(validator.validate({ depthClockInk: 'tertiary', widgetVariant: 'popup', widgets: [{ type: 'note' }] }, defaults));
    assert.equal(ok.depthClockInk, 'tertiary');
    assert.equal(ok.widgetVariant, 'popup');
    assert.equal(ok.widgets.length, 1);
    const bad = plain(validator.validate({ depthClockInk: 'nope', widgetVariant: 'nope', widgets: 'x' }, defaults));
    assert.equal(bad.depthClockInk, 'auto');
    assert.equal(bad.widgetVariant, defaults.widgetVariant);
    assert.deepEqual(bad.widgets, []);
    assert.deepEqual(plain(schema.INK_OPTIONS.map(o => o.value)), plain(clocks.INKS));
    assert.deepEqual(plain(schema.VARIANT_OPTIONS.map(o => o.value)), plain(registry.VARIANTS));
});
