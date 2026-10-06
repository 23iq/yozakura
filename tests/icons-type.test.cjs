const { test } = require('node:test');
const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');
const { execFileSync } = require('node:child_process');
const { loadLibrary } = require('./lib/qmljs.cjs');

const ROOT = path.join(__dirname, '..');
const W = loadLibrary(path.join(ROOT, 'modules/theme/IconWeights.js'));
const T = loadLibrary(path.join(ROOT, 'modules/theme/TypeRoles.js'));
const defaults = loadLibrary(path.join(ROOT, 'config/defaults/theme.js')).data;
const themeMeta = fs.readFileSync(path.join(ROOT, 'config/meta/theme.js'), 'utf8');

const hasFcScan = (() => { try { execFileSync('fc-scan', ['--version']); return true; } catch { return false; } })();
const scanFamily = (f) => execFileSync('fc-scan', ['--format', '%{family}', f]).toString().trim();

test('every weight resolves to a bundled font file', () => {
    assert.deepEqual(Array.from(W.weights()), ['regular', 'bold', 'fill']);
    for (const f of W.files()) assert.ok(fs.existsSync(path.join(ROOT, f)), f);
    assert.ok(fs.existsSync(path.join(ROOT, 'assets/fonts/phosphor/LICENSE')));
});

test('the family a file registers is the family its weight resolves to', { skip: !hasFcScan }, () => {
    const files = Array.from(W.files());
    Array.from(W.weights()).forEach((w, i) => {
        assert.equal(scanFamily(path.join(ROOT, files[i])), W.family(w));
    });
});

test('unknown weights fall back to bold; the default is bold', () => {
    for (const bad of ['', 'duotone', null, undefined, 3]) assert.equal(W.family(bad), 'Phosphor-Bold');
    assert.equal(defaults.icons.weight, 'bold');
});

test('the catalog enums equal the registries', () => {
    const enumOf = (key) => {
        const m = themeMeta.match(new RegExp('"' + key.replace('.', '\\.') + '": \\{\\s*"enum": (\\[[^\\]]*\\])'));
        assert.ok(m, key);
        return JSON.parse(m[1]);
    };
    assert.deepEqual(enumOf('icons.weight'), Array.from(W.weights()));
    assert.deepEqual(enumOf('type.headingCase'), Array.from(T.CASES));
});

test('heading case is applied', () => {
    assert.equal(T.applyCase('Hello World', 'upper'), 'HELLO WORLD');
    assert.equal(T.applyCase('Hello World', 'lower'), 'hello world');
    assert.equal(T.applyCase('quick settings-panel', 'title'), 'Quick Settings-Panel');
    assert.equal(T.applyCase('Keep Me', 'none'), 'Keep Me');
    assert.equal(T.applyCase('Keep Me', 'bogus'), 'Keep Me');
    assert.equal(T.applyCase(null, 'upper'), '');
});

test('Icons.qml inlines the same families as IconWeights.js', () => {
    const src = fs.readFileSync(path.join(ROOT, 'modules/theme/Icons.qml'), 'utf8');
    assert.ok(src.includes('|| "' + W.family('bold') + '"'));
    for (const w of ['regular', 'fill']) assert.ok(src.includes('"' + w + '": "' + W.family(w) + '"'), w);
});

test('heading font falls back to the body font', () => {
    assert.equal(T.headingFamily({ heading: '' }, 'Inter'), 'Inter');
    assert.equal(T.headingFamily(null, 'Inter'), 'Inter');
    assert.equal(T.headingFamily({ heading: 'Oswald' }, 'Inter'), 'Oswald');
    assert.equal(defaults.type.headingCase, 'none');
});
