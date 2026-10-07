const { test } = require('node:test');
const assert = require('node:assert/strict');
const path = require('node:path');
const { loadLibrary } = require('./lib/qmljs.cjs');

const G = loadLibrary(path.join(__dirname, '../modules/widgets/dashboard/wallpapers/WallpaperGrid.js'));

test('columnsFor reflows with the width and stays in range', () => {
    assert.equal(G.columnsFor(700, 100), 7);
    assert.equal(G.columnsFor(400, 100), 4);
    assert.equal(G.columnsFor(100, 100), 3);
    assert.equal(G.columnsFor(5000, 100), 12);
    assert.equal(G.columnsFor(0, 100), 3);
    assert.equal(G.columnsFor(700, 0), 3);
});
