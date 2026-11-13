// Settings home and page bento: column counts and packing of the home tiles
// (HomeLayout.js), arrow-key moves between tiles, the masonry of a page's
// cards (BentoLayout.js) and the live status line of each tile
// (HomeStatus.js), in every language.
const { test } = require('node:test');
const assert = require('node:assert/strict');
const path = require('node:path');
const { loadLibrary } = require('./lib/qmljs.cjs');

const dir = path.join(__dirname, '..', 'modules/settings');
const HomeLayout = loadLibrary(path.join(dir, 'HomeLayout.js'));
const BentoLayout = loadLibrary(path.join(dir, 'BentoLayout.js'));
const HomeStatus = loadLibrary(path.join(dir, 'HomeStatus.js'));
const Categories = loadLibrary(path.join(dir, 'schema/Categories.js'));
const plain = v => JSON.parse(JSON.stringify(v));
const tr = lang => require(`../translations/${lang}.json`);

test('home is three columns, two when narrow, with hysteresis; rows stretch to fill', () => {
    assert.equal(HomeLayout.columns(900, 240, 2), 3);
    assert.equal(HomeLayout.columns(600, 240, 2), 2);
    // near the switch point a grid of three stays three (no flip-flop)
    assert.equal(HomeLayout.columns(700, 240, 3), 3);
    assert.equal(HomeLayout.columns(700, 240, 2), 2);
    assert.equal(HomeLayout.columns(0, 240, 3), 2);
    // 3 rows and 2 gaps of 12 fill 556 px
    assert.equal(Math.round(HomeLayout.rowUnit(556, 3, 12, 20) * 3 + 2 * 12), 556);
    // never under the minimum (home scrolls then)
    assert.equal(HomeLayout.rowUnit(100, 3, 12, 150), 150);
});

test('home tiles are equal cells, three by three, in reading order', () => {
    const tiles = Categories.home();
    for (const cols of [2, 3]) {
        const { cells, rows } = HomeLayout.pack(tiles, cols);
        assert.equal(cells.length, 9);
        assert.equal(rows, Math.ceil(9 / cols));
        cells.forEach((c, i) => {
            assert.deepEqual([c.w, c.h], [1, 1], c.id);
            assert.deepEqual([c.col, c.row], [i % cols, Math.floor(i / cols)], c.id);
        });
    }
});

test('arrow keys move to the next tile that way', () => {
    const { cells } = HomeLayout.pack(Categories.home(), 3);
    const at = id => cells.findIndex(c => c.id === id);
    assert.equal(cells[HomeLayout.neighbour(cells, at('look'), 'right')].id, 'screen');
    assert.equal(cells[HomeLayout.neighbour(cells, at('look'), 'down')].id, 'panels');
    assert.equal(HomeLayout.neighbour(cells, at('look'), 'left'), at('look'));
    assert.equal(HomeLayout.neighbour(cells, at('look'), 'up'), at('look'));
});

test('page cards: 1 to 3 columns, masonry without overlap', () => {
    assert.equal(BentoLayout.columns(300, 340), 1);
    assert.equal(BentoLayout.columns(800, 340), 2);
    assert.equal(BentoLayout.columns(2000, 340), 3);
    const items = [{ span: 2, height: 100 }, { span: 1, height: 50 }, { span: 1, height: 200 }, { span: 1, height: 30 }];
    const { places, height, floor } = BentoLayout.place(items, 3, 10);
    assert.deepEqual(plain(places[0]), { col: 0, span: 2, y: 0 });
    assert.deepEqual(plain(places[1]), { col: 2, span: 1, y: 0 });
    // the next card goes under the shortest column
    assert.equal(places[2].col, 2);
    assert.equal(places[2].y, 60);
    assert.equal(places[3].y, 110);
    assert.equal(height, 260);
    // the shortest column ends at 100: a next card lands at or below it
    assert.equal(floor, 100);
    // a span wider than the grid is clamped
    assert.equal(BentoLayout.place([{ span: 2, height: 10 }], 1, 0).places[0].span, 1);
});

test('a page of wide cards uses two columns, not an empty third', () => {
    assert.equal(BentoLayout.fit(3, [2, 2, 2]), 2);
    assert.equal(BentoLayout.fit(3, [2, 1, 2]), 3);
    assert.equal(BentoLayout.fit(1, [2]), 1);
    // one narrow card: one column (centred), not a row of empty ones
    assert.equal(BentoLayout.fit(3, [1]), 1);
    assert.equal(BentoLayout.fit(3, [1, 1]), 2);
    assert.equal(BentoLayout.fit(3, [2]), 2);
});

test('a section with picture cards or an editor spans two columns', () => {
    assert.equal(BentoLayout.spanOf({ entries: [{ type: 'switch' }] }), 1);
    // a picture choice of more than three options: two columns
    assert.equal(BentoLayout.spanOf({ entries: [{ type: 'select', display: 'cards', options: [1, 2, 3] }] }), 1);
    assert.equal(BentoLayout.spanOf({ entries: [{ type: 'select', display: 'cards', options: [1, 2, 3, 4] }] }), 2);
    assert.equal(BentoLayout.spanOf({ entries: [{ type: 'custom', component: 'BarStyleCards' }] }), 2);
    // an editor is one column unless it needs the width
    assert.equal(BentoLayout.spanOf({ entries: [{ type: 'custom', component: 'WindowGapsEditor' }] }), 1);
    assert.equal(BentoLayout.spanOf({ entries: [{ type: 'custom', component: 'BarLayoutEditor' }] }), 2);
    assert.equal(BentoLayout.spanOf({ span: 3, entries: [] }), 3);
    // an out-of-window editor does not widen the card
    assert.equal(BentoLayout.spanOf({ entries: [{ type: 'custom', component: 'BarLayoutEditor', advanced: true }] }, e => !e.advanced), 1);
});

test('every tile has a live status line in every language', () => {
    const values = {
        'bar.position': 'top', 'bar.panels': [], 'notch.enabled': true, 'dock.enabled': true,
        'theme.language': 'ink', 'wallpaper.matugenScheme': 'scheme-tonal-spot', 'compositor.gapsIn': 6,
        'compositor.borderSize': 2,
    };
    for (const lang of ['en', 'es', 'ru']) {
        const t = tr(lang);
        const ctx = { get: k => values[k], tr: k => t[k] || `?${k}`, wallpapers: 12, preset: '' };
        for (const g of Categories.home()) {
            const line = HomeStatus.line(g.id, ctx);
            assert.ok(line && line.indexOf('?') < 0, `${lang} ${g.id}: ${line}`);
        }
    }
    const en = tr('en');
    const ctx = { get: k => values[k], tr: k => en[k], wallpapers: 12, preset: '' };
    assert.equal(HomeStatus.line('screen', ctx), 'Top bar · island · dock');
    assert.equal(HomeStatus.line('windows', ctx), 'Gaps 6 · edge 2');
    // an "auto" corner is named as the shell resolves it
    assert.equal(HomeStatus.line('notifications', ctx), 'Top right');
    // the former status tiles' live values, in plain words
    assert.equal(HomeStatus.line('devices', { ...ctx, network: 'Sakura 5G', volume: 0.62, outputs: [{ width: 2560, height: 1440, refresh: 143.9 }] }), 'Sakura 5G · Volume 62 % · 2560×1440 · 144 Hz');
    assert.equal(HomeStatus.line('system', { ...ctx, language: 'English', update: false }), 'English · up to date');
    assert.equal(HomeStatus.line('panels', ctx), 'Launcher: Auto');
    values['notifications.dnd.enabled'] = true;
    assert.equal(HomeStatus.line('notifications', ctx), 'Do Not Disturb is on');
    values['bar.panels'] = [{}, {}];
    values['dock.enabled'] = false;
    assert.equal(HomeStatus.line('screen', ctx), '2 bars · island');
});

test('every home tile scene is registered by its full path (the audit sees it) and exists', () => {
    const fs = require('node:fs');
    const Registry = loadLibrary(path.join(dir, 'Registry.js'));
    for (const g of Categories.home()) {
        const f = Registry.scene(g.id);
        assert.ok(f, `${g.id} has a scene`);
        assert.ok(fs.existsSync(path.join(dir, f)), f);
    }
    const files = fs.readdirSync(path.join(dir, 'home')).filter(f => f.endsWith('Scene.qml'));
    const listed = Object.values(Registry.SCENES).map(f => f.replace('home/', ''));
    assert.deepEqual(files.sort(), listed.sort());
});

test('the page order: plain rows, then big controls, the lead ones first in each', () => {
    const secs = [
        { id: 'a', entries: [{ type: 'custom' }] },
        { id: 'b', entries: [{ type: 'toggle' }] },
        { id: 'c', entries: [{ type: 'selector', display: 'cards' }] },
        { id: 'd', entries: [{ type: 'slider' }] },
    ];
    assert.deepEqual([...BentoLayout.order(secs, ['c', 'd'])], [3, 1, 2, 0]);
    assert.deepEqual([...BentoLayout.order(secs, [])], [1, 3, 0, 2]);
});

test('a narrow card fills the hole a wide one leaves; fixed columns stay', () => {
    // a short card, then a wide one: the third column is free under the
    // short one and a narrow card goes there, not under the wide one
    const items = [{ span: 1, height: 50 }, { span: 2, height: 300 }, { span: 1, height: 100 }, { span: 1, height: 100 }];
    const r = BentoLayout.place(items, 3, 10);
    assert.deepEqual(plain(r.places[1]), { col: 1, span: 2, y: 0 });
    assert.deepEqual(plain(r.places[2]), { col: 0, span: 1, y: 60 });
    assert.deepEqual(plain(r.places[3]), { col: 0, span: 1, y: 170 });
    // a card that grows keeps its column
    const grown = items.map((it, i) => i === 0 ? { span: 1, height: 400 } : it);
    const kept = BentoLayout.place(grown, 3, 10, r.places);
    assert.equal(kept.places[2].col, 0);
    assert.equal(kept.places[3].col, 0);
});

test('the master switch card heads the page', () => {
    const secs = [
        { id: 'a', entries: [{ type: 'toggle', key: 'x.a' }] },
        { id: 'b', entries: [{ type: 'selector', display: 'cards', key: 'x.style' }, { type: 'toggle', key: 'notch.enabled' }] },
    ];
    assert.equal(BentoLayout.order(secs, [])[0], 1);
});
