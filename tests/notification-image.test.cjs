// Downloaded notification images as data: URLs
// (modules/services/NotificationImage.js): chunked conversion, never a
// truncated image.
const { test } = require('node:test');
const assert = require('node:assert/strict');
const path = require('node:path');
const { loadLibrary } = require('./lib/qmljs.cjs');

const I = loadLibrary(path.join(__dirname, '../modules/services/NotificationImage.js'));

function bytes(n) {
    const b = new Uint8Array(n);
    for (let i = 0; i < n; i++) b[i] = (i * 7 + 3) & 0xff;
    return b;
}

test('base64 of every byte value, across chunk boundaries', () => {
    for (const n of [1, 2, 3, I.CHUNK - 1, I.CHUNK, I.CHUNK + 1, 5 * I.CHUNK + 2]) {
        const b = bytes(n);
        assert.equal(I.dataUrl(b, 'https://x/a.png', btoa),
            'data:image/png;base64,' + Buffer.from(b).toString('base64'), `n=${n}`);
    }
});

test('the chunk size keeps base64 groups whole', () => {
    assert.equal(I.CHUNK % 3, 0);
});

test('an image up to the limit is cached whole', () => {
    const b = bytes(I.MAX_BYTES);
    const url = I.dataUrl(b, 'https://x/a.jpg', btoa);
    assert.equal(Buffer.from(url.slice(url.indexOf(',') + 1), 'base64').length, I.MAX_BYTES);
});

test('a larger or empty image is not cached (no cut image)', () => {
    assert.equal(I.dataUrl(bytes(I.MAX_BYTES + 1), 'https://x/a.png', btoa), '');
    assert.equal(I.dataUrl(new Uint8Array(0), 'https://x/a.png', btoa), '');
    assert.equal(I.dataUrl(null, 'https://x/a.png', btoa), '');
});

test('mime type from the URL', () => {
    assert.equal(I.mimeFor('https://x/A.JPG?s=1'), 'image/jpeg');
    assert.equal(I.mimeFor('https://x/a.jpeg'), 'image/jpeg');
    assert.equal(I.mimeFor('https://x/a.gif'), 'image/gif');
    assert.equal(I.mimeFor('https://x/a.webp'), 'image/webp');
    assert.equal(I.mimeFor('https://x/avatar'), 'image/png');
});
