const { test } = require('node:test');
const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');
const qmljs = require('./lib/qmljs.cjs');
const Presets = require('./lib/presetsets.cjs');

const ROOT = path.join(__dirname, '..');
const fonts = qmljs.loadLibrary(path.join(ROOT, 'modules/theme/BundledFonts.js'));
const themeDefaults = qmljs.loadLibrary(path.join(ROOT, 'config/defaults/theme.js')).data;
const UI = path.join(ROOT, fonts.ROOT);

// Families the installers pull in (install.sh, nix/packages/fonts.nix):
// presets may name these besides the bundled ones and the defaults.
const PACKAGED = [
    'Roboto', 'Roboto Condensed', 'Roboto Mono', 'DejaVu Sans', 'DejaVu Serif', 'DejaVu Sans Mono',
    'Liberation Sans', 'Liberation Serif', 'Liberation Mono', 'Noto Sans', 'Noto Serif', 'Noto Sans Mono',
    'Noto Sans CJK JP', 'Noto Serif CJK JP', 'League Gothic', 'Terminus'
];

const fontFile = f => /\.(ttf|otf)$/i.test(f);

test('every file under assets/fonts/ui is registered and every entry exists', () => {
    const listed = new Set(fonts.files());
    for (const dir of fs.readdirSync(UI)) {
        for (const f of fs.readdirSync(path.join(UI, dir)).filter(fontFile))
            assert.ok(listed.has(`${fonts.ROOT}${dir}/${f}`), `${dir}/${f} is not in BundledFonts.js`);
    }
    for (const f of listed)
        assert.ok(fs.existsSync(path.join(ROOT, f)), `${f} is registered but missing`);
});

test('every bundled family ships an OFL or Apache licence', () => {
    for (const f of fonts.FONTS) {
        const lic = path.join(UI, f.dir, f.licence);
        assert.ok(fs.existsSync(lic), `${f.family}: ${f.licence} missing`);
        const text = fs.readFileSync(lic, 'utf8');
        assert.match(text, /SIL OPEN FONT LICENSE|Apache License/i, `${f.family}: not OFL/Apache`);
        assert.ok(['sans', 'serif', 'mono', 'display'].includes(f.kind), `${f.family}: kind`);
    }
    assert.equal(new Set(fonts.families()).size, fonts.FONTS.length, 'duplicate family');
});

test('bundled fonts stay small (subset them with pyftsubset)', () => {
    for (const f of fonts.files()) {
        const kb = fs.statSync(path.join(ROOT, f)).size / 1024;
        assert.ok(kb < 600, `${f} is ${Math.round(kb)} KB`);
    }
});

test('built-in presets only name bundled, packaged or default fonts', () => {
    const allowed = new Set([...fonts.families(), ...PACKAGED, themeDefaults.font, themeDefaults.monoFont, '']);
    for (const name of Presets.listSets()) {
        const set = Presets.composeSet(name);
        const theme = set.theme || {};
        const ws = set.workspaces || {};
        const named = {
            'theme.font': theme.font, 'theme.monoFont': theme.monoFont, 'theme.type.heading': (theme.type || {}).heading,
            'workspaces.numeralFont': ws.numeralFont, 'workspaces.specialWorkspaceFont': ws.specialWorkspaceFont
        };
        for (const [key, family] of Object.entries(named)) {
            if (family === undefined)
                continue;
            assert.ok(allowed.has(family), `${name}: ${key} "${family}" is neither bundled nor packaged`);
        }
    }
});
