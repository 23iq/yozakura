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

test('home columns reflow 6 / 4 / 2 with the width', () => {
    assert.equal(HomeLayout.columns(1200, 150), 6);
    assert.equal(HomeLayout.columns(700, 150), 4);
    assert.equal(HomeLayout.columns(500, 150), 2);
    assert.equal(HomeLayout.columns(0, 150), 2);
});

test('home tiles pack without overlap, in reading order, at every column count', () => {
    const tiles = Categories.home();
    for (const cols of [2, 4, 6]) {
        const { cells, rows } = HomeLayout.pack(tiles, cols);
        assert.equal(cells.length, tiles.length);
        const taken = new Set();
        for (const c of cells) {
            assert.ok(c.col + c.w <= cols, `${c.id} fits ${cols}`);
            for (let y = c.row; y < c.row + c.h; y++)
                for (let x = c.col; x < c.col + c.w; x++) {
                    const k = `${x},${y}`;
                    assert.ok(!taken.has(k), `${c.id} overlaps at ${k} (${cols} cols)`);
                    taken.add(k);
                }
            assert.ok(c.row + c.h <= rows);
        }
        // the big tile comes first, top left
        assert.deepEqual(plain(cells[0]), { id: 'layout', col: 0, row: 0, w: 2, h: 2 });
    }
});

test('arrow keys move to the nearest tile that way', () => {
    const { cells } = HomeLayout.pack(Categories.home(), 6);
    const at = id => cells.findIndex(c => c.id === id);
    // look sits right of the big layout tile
    assert.equal(cells[HomeLayout.neighbour(cells, at('layout'), 'right')].id, 'look');
    assert.equal(HomeLayout.neighbour(cells, at('layout'), 'left'), at('layout'));
    assert.equal(HomeLayout.neighbour(cells, at('layout'), 'up'), at('layout'));
    const down = cells[HomeLayout.neighbour(cells, at('look'), 'down')];
    assert.ok(down.row > cells[at('look')].row);
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
});

test('a section with picture cards or an editor spans two columns', () => {
    assert.equal(BentoLayout.spanOf({ entries: [{ type: 'switch' }] }), 1);
    assert.equal(BentoLayout.spanOf({ entries: [{ type: 'select', display: 'cards' }] }), 2);
    assert.equal(BentoLayout.spanOf({ entries: [{ type: 'custom' }] }), 2);
    assert.equal(BentoLayout.spanOf({ span: 3, entries: [] }), 3);
    // an out-of-window editor does not widen the card
    assert.equal(BentoLayout.spanOf({ entries: [{ type: 'custom', advanced: true }] }, e => !e.advanced), 1);
});

test('every tile has a live status line in every language', () => {
    const values = {
        'bar.position': 'top', 'bar.panels': [], 'notch.enabled': true, 'dock.enabled': true,
        'theme.language': 'ink', 'wallpaper.matugenScheme': 'scheme-tonal-spot', 'compositor.gapsIn': 6,
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
    assert.equal(HomeStatus.line('layout', ctx), 'Top bar · island · dock');
    assert.equal(HomeStatus.line('wallpaper', ctx), '12 in your library');
    assert.equal(HomeStatus.line('windows', ctx), 'Gaps 6 px');
    values['bar.panels'] = [{}, {}];
    values['dock.enabled'] = false;
    assert.equal(HomeStatus.line('layout', ctx), '2 bars · island');
});
