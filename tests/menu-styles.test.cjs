// MenuStyles.js: registry of the off-notch menu styles + cursor parsing.
const { test } = require('node:test');
const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');
const { loadLibrary } = require('./lib/qmljs.cjs');
const DIR = path.join(__dirname, '../modules/widgets/menus');
const S = loadLibrary(path.join(DIR, 'MenuStyles.js'));
const R = loadLibrary(path.join(__dirname, '../modules/shell/hosts/HostRouter.js'));

test('every overlay style has an existing file; notch styles have none', () => {
    for (const module of Object.keys(R.MENU_STYLES)) {
        for (const style of R.MENU_STYLES[module]) {
            const f = S.fileFor(module, style);
            if (style === 'notch') {
                assert.equal(f, '', `${module}/${style}`);
                continue;
            }
            assert.ok(f, `${module}/${style}`);
            assert.ok(fs.existsSync(path.join(DIR, f)), f);
        }
    }
    assert.equal(S.fileFor('tools', 'fullscreen'), '');
    assert.equal(S.fileFor('bogus', 'radial'), '');
});

test('radial opens at the cursor, fullscreen does not', () => {
    assert.equal(S.atCursor('radial'), true);
    assert.equal(S.atCursor('fullscreen'), false);
});

test('cursor output is mapped onto the screen', () => {
    const p = S.parseCursor('{\n  "x": 2500,\n  "y": 300\n}\n', { x: 1920, y: 0 });
    assert.equal(p.x, 580);
    assert.equal(p.y, 300);
    assert.equal(S.parseCursor('error: no compositor', { x: 0, y: 0 }), null);
    assert.equal(S.parseCursor('', null), null);
});
