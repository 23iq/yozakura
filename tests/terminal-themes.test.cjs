const { test } = require('node:test');
const assert = require('node:assert/strict');
const path = require('node:path');
const qmljs = require('./lib/qmljs.cjs');

const T = qmljs.loadLibrary(path.join(__dirname, '../modules/theme/TerminalThemes.js'));
const names = ['background', 'overSurface', 'overSurfaceVariant', 'overSecondary', 'secondaryFixedDim', 'surfaceContainerHigh', 'surfaceContainerLowest', 'red', 'green', 'yellow', 'blue', 'magenta', 'cyan', 'lightRed', 'lightGreen', 'lightYellow', 'lightBlue', 'lightMagenta', 'lightCyan', 'outline', 'primary', 'overPrimary', 'primaryContainer', 'overPrimaryContainer', 'secondary', 'tertiary'];
const C = {};
names.forEach((n, i) => { C[n] = '#' + (0x101010 + i * 0x050709).toString(16).padStart(6, '0'); });
C.background = '#ff101418';
const P = JSON.parse(JSON.stringify(T.palette(C)));

test('palette strips alpha and maps ansi slots', () => {
    assert.equal(P.background, '#101418');
    assert.equal(P.normal.length, 8);
    assert.equal(P.bright.length, 8);
    assert.equal(P.normal[1], C.red);
    assert.equal(P.bright[0], C.outline);
});

test('ghostty output', () => {
    const t = T.ghostty(P, { font: 'Fira Code', fontSize: 13, opacity: 0.9 });
    assert.match(t, /^font-family = "Fira Code"\nfont-size = 13\n/);
    assert.match(t, /background-opacity = 0.9\n/);
    assert.equal((t.match(/^palette = \d+=#[0-9a-f]{6}$/gm) || []).length, 22);
    assert.ok(!/font-family/.test(T.ghostty(P, { font: '', opacity: 1 })));
});

test('foot output has no # and 16 colors', () => {
    const t = T.foot(P, { font: 'Fira Code', fontSize: 12, opacity: 0.8 });
    assert.match(t, /font=Fira Code:size=12/);
    assert.match(t, /alpha=0.8/);
    assert.ok(!t.includes('#'));
    assert.equal((t.match(/^(regular|bright)[0-7]=[0-9a-f]{6}$/gm) || []).length, 16);
});

test('alacritty output escapes the font and is sectioned', () => {
    const t = T.alacritty(P, { font: 'A "B"\nC', fontSize: 11, opacity: 0.7 });
    assert.match(t, /family = "A \\"B\\" C"/);
    assert.match(t, /\[window\]\nopacity = 0.7/);
    assert.match(t, /\[colors.bright\]\nblack = "#[0-9a-f]{6}"/);
});
