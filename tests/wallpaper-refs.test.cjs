const { test } = require('node:test');
const assert = require('node:assert/strict');
const path = require('node:path');

const qmljs = require('./lib/qmljs.cjs');
const R = qmljs.loadLibrary(path.join(__dirname, '../modules/widgets/dashboard/wallpapers/WallpaperRefs.js'));
const plain = v => JSON.parse(JSON.stringify(v));

const NOW = '/nix/store/new-yozakura-shell-0.3.0/assets/wallpapers_example';
const OLD = '/nix/store/b5h1p7l034y542p8wqby71z1xffh43k6-yozakura-shell-0.2.0/assets/wallpapers_example';
const BUNDLED = [NOW + '/wallpaper-01.png', NOW + '/wallpaper-08.png', NOW + '/sub/loop.mp4'];

test('bundled wallpapers are stored by a store-independent id', () => {
    assert.equal(R.toStored(NOW + '/wallpaper-08.png', NOW), 'bundled:wallpaper-08.png');
    assert.equal(R.toStored(NOW + '/sub/loop.mp4', NOW + '/'), 'bundled:sub/loop.mp4');
    // An older store copy maps to the same id.
    assert.equal(R.toStored(OLD + '/wallpaper-08.png', NOW), 'bundled:wallpaper-08.png');
    assert.equal(R.toStored('bundled:wallpaper-08.png', NOW), 'bundled:wallpaper-08.png');
});

test('user wallpapers are stored as they are', () => {
    assert.equal(R.toStored('/home/u/Pictures/a.mp4', NOW), '/home/u/Pictures/a.mp4');
    assert.equal(R.toStored('', NOW), '');
    // A folder merely named like the bundled one is not inside it.
    assert.equal(R.toStored(NOW + '2/x.png', NOW), NOW + '2/x.png');
});

test('stored ids and legacy store paths resolve into the running shell', () => {
    assert.equal(R.fromStored('bundled:wallpaper-08.png', NOW), NOW + '/wallpaper-08.png');
    assert.equal(R.fromStored(OLD + '/wallpaper-08.png', NOW), NOW + '/wallpaper-08.png');
    assert.equal(R.fromStored('/home/u/a.jpg', NOW), '/home/u/a.jpg');
    assert.equal(R.fromStored('', NOW), '');
});

test('resolveSaved matches a vanished bundled file by basename', () => {
    assert.equal(R.resolveSaved('bundled:wallpaper-08.png', NOW, BUNDLED), NOW + '/wallpaper-08.png');
    // Moved into a subfolder in a later release.
    assert.equal(R.resolveSaved(OLD + '/old/loop.mp4', NOW, BUNDLED), NOW + '/sub/loop.mp4');
    assert.equal(R.resolveSaved('bundled:gone.png', NOW, BUNDLED), '');
    // Unknown bundled set: resolve without checking.
    assert.equal(R.resolveSaved('bundled:gone.png', NOW, []), NOW + '/gone.png');
    assert.equal(R.resolveSaved('/home/u/a.jpg', NOW, BUNDLED), '/home/u/a.jpg');
});

test('per-screen maps convert both ways', () => {
    const stored = R.mapScreens({ 'DP-1': OLD + '/wallpaper-01.png', 'HDMI-A-1': '/w/a.jpg' }, NOW, R.toStored);
    assert.deepEqual(plain(stored), { 'DP-1': 'bundled:wallpaper-01.png', 'HDMI-A-1': '/w/a.jpg' });
    assert.deepEqual(plain(R.mapScreens(stored, NOW, R.fromStored)), { 'DP-1': NOW + '/wallpaper-01.png', 'HDMI-A-1': '/w/a.jpg' });
    assert.deepEqual(plain(R.mapScreens(undefined, NOW, R.fromStored)), {});
});

test('fallback prefers still images, then GIFs, over videos', () => {
    assert.equal(R.preferredIndex([]), -1);
    assert.equal(R.preferredIndex(['/w/a.mp4', '/w/b.webm', '/w/c.JPG']), 2);
    assert.equal(R.preferredIndex(['/w/a.mp4', '/w/b.gif']), 1);
    assert.equal(R.preferredIndex(['/w/a.mp4', '/w/b.mkv']), 0);
});

test('choose keeps the saved wallpaper, a saved bundled one outside the folders, or falls back', () => {
    const walls = ['/w/a.mp4', '/w/b.png'];
    assert.deepEqual(plain(R.choose(walls, '/w/b.png', BUNDLED)), { paths: walls, index: 1, found: true });
    // The reported case: a bundled pick while wallPath is the user's folder.
    assert.deepEqual(plain(R.choose(['/w/a.mp4'], NOW + '/wallpaper-08.png', BUNDLED)),
        { paths: ['/w/a.mp4', NOW + '/wallpaper-08.png'], index: 1, found: true });
    assert.deepEqual(plain(R.choose(walls, '/w/gone.jpg', BUNDLED)), { paths: walls, index: 1, found: false });
    assert.deepEqual(plain(R.choose(walls, '', BUNDLED)), { paths: walls, index: 1, found: false });
    assert.deepEqual(plain(R.choose([], '', [])), { paths: [], index: -1, found: false });
});

test('partition splits the scanned folders from the bundled set', () => {
    const files = ['/w/a.png', NOW + '/wallpaper-01.png', '/x/b.jpg', '', '/other/c.png'];
    assert.deepEqual(plain(R.partition(files, ['/w', '/x/'], NOW)),
        { wallpapers: ['/w/a.png', '/x/b.jpg'], bundled: [NOW + '/wallpaper-01.png'] });
    // Bundled folder is the wallpaper folder: files are in both lists.
    assert.deepEqual(plain(R.partition([NOW + '/wallpaper-01.png'], [NOW], NOW)),
        { wallpapers: [NOW + '/wallpaper-01.png'], bundled: [NOW + '/wallpaper-01.png'] });
});

test('kind', () => {
    assert.equal(R.kind('/a/b.WEBP'), 'image');
    assert.equal(R.kind('/a/b.gif'), 'gif');
    assert.equal(R.kind('/a/b.mkv'), 'video');
    assert.equal(R.kind('/a/b'), 'unknown');
});
