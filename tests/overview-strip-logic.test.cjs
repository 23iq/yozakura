const { test } = require('node:test');
const assert = require('node:assert/strict');
const path = require('node:path');
const { loadLibrary } = require('./lib/qmljs.cjs');

const load = file => loadLibrary(path.join(__dirname, file));
const Styles = load('../modules/widgets/overview/OverviewStyles.js');
const Strip = load('../modules/widgets/overview/StripMath.js');
const Search = load('../modules/widgets/overview/OverviewSearch.js');

test('registry resolves style, scrolling layout wins, unknown falls back to grid', () => {
    assert.deepEqual([...Styles.ids()], ['grid', 'strip']);
    assert.equal(Styles.resolve('strip', 'dwindle'), 'strip');
    assert.equal(Styles.resolve('grid', 'dwindle'), 'grid');
    assert.equal(Styles.resolve('bogus', 'dwindle'), 'grid');
    assert.equal(Styles.resolve(undefined, 'dwindle'), 'grid');
    assert.equal(Styles.resolve('strip', 'scrolling'), 'scrolling');
    assert.equal(Styles.resolve('grid', 'scrolling'), 'scrolling');
    for (const id of [...Styles.ids()]) assert.match(Styles.labelKey(id), /^settings\.shell\.overview_style_/);
});

test('step clamps to 1..count', () => {
    assert.equal(Strip.step(3, 1, 10), 4);
    assert.equal(Strip.step(3, -1, 10), 2);
    assert.equal(Strip.step(1, -1, 10), 1);
    assert.equal(Strip.step(10, 1, 10), 10);
    assert.equal(Strip.step(5, 0, 10), 5);
});

test('count covers shown, active and the busiest workspace', () => {
    assert.equal(Strip.count(10, 3, [{ workspace: { id: 2 } }]), 10);
    assert.equal(Strip.count(4, 2, [{ workspace: { id: 7 } }, null, {}]), 7);
    assert.equal(Strip.count(4, 9, []), 9);
    assert.equal(Strip.count(0, 0, []), 1);
});

test('visible cells is odd, at least 1, at most count', () => {
    assert.equal(Strip.visibleCount(5, 10), 5);
    assert.equal(Strip.visibleCount(4, 10), 3);
    assert.equal(Strip.visibleCount(9, 4), 3);
    assert.equal(Strip.visibleCount(0, 10), 1);
    assert.equal(Strip.visibleCount(5, 1), 1);
});

test('belt offset centers the selected cell', () => {
    // viewport 500, cell 100, gap 10: cell 1 center is 50, so x = 200
    assert.equal(Strip.beltX(500, 100, 10, 1), 200);
    assert.equal(Strip.beltX(500, 100, 10, 2), 90);
    assert.equal(Strip.cellX(100, 10, 3), 220);
});

test('cell emphasis falls off with distance', () => {
    assert.equal(Strip.emphasis(4, 4), 1);
    assert.ok(Strip.emphasis(5, 4) < 1);
    assert.ok(Strip.emphasis(6, 4) < Strip.emphasis(5, 4));
    assert.ok(Strip.emphasis(20, 4) >= 0.25);
});

test('search ranks windows and ignores non matches', () => {
    const wins = [
        { title: 'Terminal', class: 'kitty' },
        { title: 'notes', class: 'obsidian' },
        { title: 'Firefox', class: 'firefox' },
    ];
    assert.equal(Search.rank('', wins).length, 0);
    assert.deepEqual(Search.rank('fire', wins).map(w => w.class), ['firefox']);
    assert.equal(Search.rank('zzz', wins).length, 0);
    assert.equal(Search.rank('kit', [null, ...wins])[0].class, 'kitty');
});
