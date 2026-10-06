// Model of the settings surface-role editor (modules/settings/editors/surfaces/SurfaceRoles.js)
// and its schema fragment (modules/settings/schema/surfaces.js).
const { test } = require('node:test');
const assert = require('node:assert/strict');
const path = require('node:path');
const { loadLibrary } = require('./lib/qmljs.cjs');

const root = path.join(__dirname, '..');
const M = loadLibrary(path.join(root, 'modules/settings/editors/surfaces/SurfaceRoles.js'));
const Theme = loadLibrary(path.join(root, 'config/defaults/theme.js')).data;
const plain = v => JSON.parse(JSON.stringify(v));

test('every sr* variant of the defaults is offered once', () => {
    const fromDefaults = Object.keys(Theme).filter(k => k.startsWith('sr') && typeof Theme[k] === 'object');
    const offered = M.roles().map(r => r.prop);
    assert.deepEqual([...offered].sort(), [...fromDefaults].sort());
    assert.equal(new Set(offered).size, offered.length);
    assert.equal(M.variantId('srPrimaryFocus'), 'primaryfocus');
    assert.deepEqual(plain(M.options(M.GROUPS[0])[0]), { value: 'srBg', label: 'prefs.surfaces.role.bg' });
});

test('keys cover every stored sub-key and exist in the defaults', () => {
    const keys = M.keys(Theme);
    assert.ok(keys.includes('theme.srFrame.inheritBg'));
    assert.ok(!keys.includes('theme.srBg.inheritBg'));
    for (const k of keys) {
        const [, prop, sub] = k.split('.');
        assert.ok(Theme[prop] && Theme[prop][sub] !== undefined, k);
    }
    for (const r of M.roles()) {
        const stored = Object.keys(Theme[r.prop]).filter(s => s !== 'label').map(s => `theme.${r.prop}.${s}`);
        for (const k of stored) assert.ok(keys.includes(k), k);
    }
});

test('the schema fragment lists exactly the editor keys', () => {
    const S = loadLibrary(path.join(root, 'modules/settings/schema/surfaces.js'));
    const entry = S.sections[0].entries.find(e => e.component === 'SurfaceRolesEditor');
    assert.equal(S.sections[0].id, 'surfaces');
    assert.deepEqual([...plain(entry.keys)].sort(), [...M.keys(Theme)].sort());
});

test('fields follow the gradient type and the variant', () => {
    const names = (role, g) => plain(M.fields(role, g).map(f => f.field));
    assert.deepEqual(names(Theme.srBg, 'main'), ['gradient', 'opacity', 'borderColor', 'borderWidth', 'itemColor']);
    assert.equal(names(Theme.srFrame, 'main')[0], 'inheritBg');
    assert.deepEqual(names({ ...Theme.srBg, gradientType: 'radial' }, 'more'), ['gradientType', 'gradientCenterX', 'gradientCenterY']);
    const half = { ...Theme.srBg, gradientType: 'halftone' };
    assert.ok(!names(half, 'main').includes('gradient'));
    assert.ok(names(half, 'more').includes('halftoneDotColor'));
    assert.equal(M.typeOf({ gradientType: 'bogus' }), 'linear');
    for (const f of M.FIELDS) assert.ok(f.label.startsWith('prefs.surfaces.'), f.field);
});

test('reads map stored values to the controls', () => {
    const role = { ...Theme.srPopup, gradient: [['surface', 0], ['primary@0.5', 1]], opacity: 0.8 };
    assert.deepEqual(plain(M.read(role, 'gradient')), ['surface', 'primary@0.5']);
    assert.equal(M.read(role, 'opacity'), 80);
    assert.equal(M.read(role, 'borderColor'), 'surfaceBright');
    assert.equal(M.read(role, 'borderWidth'), 2);
    assert.equal(M.read(role, 'gradientType'), 'linear');
    assert.equal(M.read(null, 'opacity'), undefined);
});

test('writes keep the stored shapes', () => {
    const role = { ...Theme.srPopup, gradient: [['surface', 0], ['primary', 0.7]] };
    assert.deepEqual(plain(M.writes(role, 'opacity', 42)), [{ sub: 'opacity', value: 0.42 }]);
    assert.deepEqual(plain(M.writes(role, 'borderWidth', 3.4)), [{ sub: 'border', value: ['surfaceBright', 3] }]);
    assert.deepEqual(plain(M.writes(role, 'borderColor', 'primary@0.5')), [{ sub: 'border', value: ['primary@0.5', 2] }]);
    // same stop count keeps positions, a new stop spreads them
    assert.deepEqual(plain(M.writes(role, 'gradient', ['error', 'primary'])), [{ sub: 'gradient', value: [['error', 0], ['primary', 0.7]] }]);
    assert.deepEqual(plain(M.writes(role, 'gradient', ['a', 'b', 'c'])[0].value), [['a', 0], ['b', 0.5], ['c', 1]]);
    assert.deepEqual(plain(M.gradientOf(['x'], null)), [['x', 0]]);
    assert.deepEqual(plain(M.writes(role, 'gradientType', 'radial')), [{ sub: 'gradientType', value: 'radial' }]);
    assert.deepEqual(plain(M.writes(role, 'nope', 1)), []);
});

test('editing a variant that follows Background detaches it', () => {
    const frame = { ...Theme.srFrame, inheritBg: true };
    assert.deepEqual(plain(M.writes(frame, 'opacity', 50)), [{ sub: 'inheritBg', value: false }, { sub: 'opacity', value: 0.5 }]);
    assert.deepEqual(plain(M.writes(frame, 'inheritBg', false)), [{ sub: 'inheritBg', value: false }]);
});
