const { test } = require('node:test');
const assert = require('node:assert/strict');
const crypto = require('node:crypto');
const fs = require('node:fs');
const os = require('node:os');
const path = require('node:path');
const { execFileSync } = require('node:child_process');

const qmljs = require('./lib/qmljs.cjs');
const F = qmljs.loadLibrary(path.join(__dirname, '../modules/widgets/dashboard/wallpapers/WallpaperFolders.js'));
const plain = v => JSON.parse(JSON.stringify(v));
const md5 = s => crypto.createHash('md5').update(s).digest('hex');

test('normalize / effective / extras', () => {
    assert.equal(F.normalize('/a/b///'), '/a/b');
    assert.equal(F.normalize('/'), '/');
    assert.deepEqual(plain(F.effective('/w/', ['/x', '/w', '', '/x/'])), ['/w', '/x']);
    assert.deepEqual(plain(F.extras('/w', ['/w/', '/y'])), ['/y']);
    assert.deepEqual(plain(F.extras('', ['/y'])), ['/y']);
});

test('rootOf picks the deepest folder and never matches name prefixes', () => {
    assert.equal(F.rootOf('/w/sub/a.jpg', ['/w', '/w/sub']), '/w/sub');
    assert.equal(F.rootOf('/walls2/a.jpg', ['/walls']), '');
    assert.equal(F.countIn(['/w/a.jpg', '/w/b/c.png', '/x/d.jpg'], '/w/'), 2);
});

test('primary thumbnails keep the historical layout', () => {
    // Same computation the old Wallpaper.qml getThumbnailPath did.
    const legacy = (file, dir) => {
        const base = dir.endsWith('/') ? dir : dir + '/';
        const parts = file.replace(base, '').split('/');
        const name = parts.pop();
        return '/c/thumbnails/' + parts.join('/') + '/' + name + '.jpg';
    };
    for (const [file, dir] of [['/w/a.jpg', '/w/'], ['/w/s/t/b.mp4', '/w'], ['/w/c.png', '/w']])
        assert.equal(F.thumbnailPath(file, dir, [], '/c', md5), legacy(file, dir));
});

test('extra-folder thumbnails match the backend layout', () => {
    const p = F.thumbnailPath('/home/u/Pictures/Walls/sub/x.png', '/w', ['/home/u/Pictures/Walls'], '/c', md5);
    // backend/cmd/yozakura/thumbs_extra_test.go pins md5(root)[:12] = 3061c730b7cc
    assert.equal(p, '/c/thumbnails/_extra/3061c730b7cc/sub/x.png.jpg');
    // A primary folder nested inside an extra one wins for its own files.
    assert.equal(F.thumbnailPath('/e/w/a.jpg', '/e/w', ['/e'], '/c', md5), '/c/thumbnails//a.jpg.jpg');
});

test('find command scans every folder and survives missing ones', () => {
    const tmp = fs.mkdtempSync(path.join(os.tmpdir(), 'wallfolders-'));
    const mk = rel => {
        fs.mkdirSync(path.dirname(path.join(tmp, rel)), { recursive: true });
        fs.writeFileSync(path.join(tmp, rel), 'x');
    };
    ['a/one.jpg', 'a/sub/two.MP4', 'a/.hidden/three.png', 'b/four.webp', 'b/notes.txt', 'b/five.mkv'].forEach(mk);
    const cmd = F.findCommand([path.join(tmp, 'a'), path.join(tmp, 'missing'), path.join(tmp, 'b')]);
    const out = execFileSync(cmd[0], cmd.slice(1), { encoding: 'utf8' }).trim().split('\n').map(f => path.relative(tmp, f)).sort();
    // Matching is case sensitive like the original scan (two.MP4 skipped).
    assert.deepEqual(out, ['a/one.jpg', 'b/five.mkv', 'b/four.webp']);
    fs.rmSync(tmp, { recursive: true, force: true });
    // No folder at all must not fall back to scanning the working directory.
    assert.deepEqual(plain(F.findCommand([])), ['true']);
});
