const { test } = require('node:test');
const assert = require('node:assert/strict');
const path = require('node:path');
const { loadLibrary } = require('./lib/qmljs.cjs');

const T = loadLibrary(path.join(__dirname, '../modules/tools/ScreenshotTarget.js'));
const A = { x: 0, y: 0, width: 1920, height: 1080, name: 'A' };
const B = { x: 1920, y: 0, width: 1920, height: 1080, name: 'B' };

test('selection inside the screen shows the preview', () => {
    assert.ok(T.showsPreview(A, { x: 10, y: 10 }, 'region', ''));
    assert.ok(!T.showsPreview(B, { x: 10, y: 10 }, 'region', ''));
});
test('edges are half-open', () => {
    assert.ok(!T.showsPreview(A, { x: 1920, y: 5 }, 'region', ''));
    assert.ok(T.showsPreview(B, { x: 1920, y: 5 }, 'region', ''));
});
test('screen mode falls back to the cursor screen', () => {
    assert.ok(T.showsPreview(B, { x: -5, y: -5 }, 'screen', 'B'));
    assert.ok(!T.showsPreview(A, { x: -5, y: -5 }, 'screen', 'B'));
    assert.ok(!T.showsPreview(B, { x: -5, y: -5 }, 'region', 'B'));
});
