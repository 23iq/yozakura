const { test } = require('node:test');
const assert = require('node:assert/strict');
const path = require('node:path');
const fs = require('node:fs');

const qmljs = require('./lib/qmljs.cjs');
const lib = file => qmljs.loadLibrary(path.join(__dirname, '..', file));
const plain = v => JSON.parse(JSON.stringify(v));

const Layout = lib('modules/bar/panels/PanelLayout.js');
const Styles = lib('modules/bar/panels/PanelStyles.js');
const Modules = lib('modules/bar/BarModuleRegistry.js');
const BarLayout = lib('modules/bar/BarLayout.js');
const barDefaults = plain(lib('config/defaults/bar.js').data);
const validator = lib('config/ConfigValidator.js');

test('empty bar.panels is the legacy bar, identical to bar.layout', () => {
    const r = plain(Layout.normalize(barDefaults));
    assert.equal(r.legacy, true);
    assert.deepEqual(r.warnings, []);
    assert.equal(r.panels.length, 1);
    const p = r.panels[0];
    assert.equal(p.edge, 'top');
    assert.equal(p.style, 'classic');
    assert.deepEqual(p.groups.start, barDefaults.layout.left);
    assert.deepEqual(p.groups.end, barDefaults.layout.right);
    assert.equal(p.autohide, 'auto');
    assert.equal(p.reserve, true);
});

test('legacy keys map: position, style, drawer and screenList', () => {
    const r = plain(Layout.normalize({ position: 'left', screenList: ['HDMI-A-1'], layout: { style: 'islands', left: ['clock'], right: [], drawer: ['power'] } }));
    const p = r.panels[0];
    assert.equal(p.edge, 'left');
    assert.equal(p.style, 'islands');
    assert.deepEqual(p.groups.drawer, ['power']);
    assert.deepEqual(p.screens, ['HDMI-A-1']);
});

test('default vertical classic keeps the historical three groups', () => {
    const p = Layout.fromLegacy({ position: 'right', layout: barDefaults.layout });
    const g = plain(Layout.resolveGroups(p));
    assert.deepEqual(g.center, ['layoutSelector', 'workspaces', 'pin']);
    const custom = Layout.fromLegacy({ position: 'right', layout: { style: 'classic', left: ['clock'], right: [] } });
    assert.deepEqual(plain(Layout.resolveGroups(custom)).start, ['clock']);
});

test('panels are normalized field by field with warnings, never throwing', () => {
    const r = plain(Layout.normalize({ panels: [
        { id: 'a', edge: 'diagonal', style: 'rail', groups: { start: ['clock', 'nope', 'clock'] }, autohide: true, size: -4 },
        { id: 'a', edge: 'top', style: 'bogus' },
        42,
    ] }));
    assert.equal(r.legacy, false);
    assert.equal(r.panels.length, 3);
    const [a, b, c] = r.panels;
    assert.equal(a.edge, 'left', 'rail falls back to its natural edge');
    assert.deepEqual(a.groups.start, ['clock']);
    assert.equal(a.autohide, 'always');
    assert.equal(a.size, 0);
    assert.equal(a.flat, true, 'rail modules are flat by default');
    assert.equal(b.id, 'a-2');
    assert.equal(b.style, 'classic');
    assert.equal(c.id, 'panel-3');
    assert.ok(r.warnings.length >= 5);
});

test('style edge constraints and dock defaults', () => {
    const r = plain(Layout.normalize({ panels: [{ style: 'menubar', edge: 'left' }, { style: 'dock', edge: 'bottom' }] }));
    assert.equal(r.panels[0].edge, 'top');
    assert.equal(r.panels[1].align, 'center');
});

test('screens filter: names, primary, secondary, disabled', () => {
    const all = Layout.normalize({ panels: [
        { id: 'main', screens: ['primary'] },
        { id: 'mini', screens: ['secondary'] },
        { id: 'tv', screens: ['HDMI-A-1'] },
        { id: 'off', enabled: false },
        { id: 'every' },
    ] }).panels;
    const ids = (name, i) => Layout.forScreen(all, name, i).map(p => p.id);
    assert.deepEqual(plain(ids('DP-1', 0)), ['main', 'every']);
    assert.deepEqual(plain(ids('HDMI-A-1', 1)), ['mini', 'tv', 'every']);
});

test('primary panel pairs with the notch edge', () => {
    const panels = Layout.normalize({ panels: [{ id: 'dock', style: 'dock', edge: 'bottom' }, { id: 'bar', edge: 'top' }] }).panels;
    assert.equal(Layout.primaryIndex(panels, 'top'), 1);
    assert.equal(Layout.primaryIndex(panels, 'left'), 0);
    assert.equal(Layout.primaryIndex([], 'top'), -1);
    assert.equal(Layout.primaryEdge({ panels: [{ edge: 'bottom' }] }, 'top'), 'bottom');
    assert.equal(Layout.primaryEdge({ position: 'left' }, 'top'), 'left');
});

test('edge zones: deepest reserving panel per edge', () => {
    const z = plain(Layout.edgeZones([
        { edge: 'top', size: 44, reserving: true },
        { edge: 'top', size: 30, reserving: true },
        { edge: 'bottom', size: 80, reserving: false },
        { edge: 'left', size: 48.4, reserving: true },
    ]));
    assert.deepEqual(z, { top: 44, bottom: 0, left: 48, right: 0 });
    assert.equal(Layout.reserves({ reserve: true, autohide: 'auto' }, false), false);
    assert.equal(Layout.reserves({ reserve: true, autohide: 'auto' }, true), true);
    assert.equal(Layout.reserves({ reserve: true, autohide: 'always' }, false), true);
    assert.equal(Layout.reserves({ reserve: false, autohide: 'never' }, true), false);
});

test('serialize round-trips through normalize', () => {
    const first = Layout.normalize({ panels: [{ id: 'x', edge: 'bottom', style: 'ribbon', groups: { start: ['weather'], center: ['worldClocks'] } }] }).panels;
    const again = Layout.normalize({ panels: plain(Layout.serialize(first)) }).panels;
    assert.deepEqual(plain(again), plain(first));
    assert.equal(plain(Layout.serialize(first))[0].legacy, undefined);
});

test('style registry: every style has its component file and valid metadata', () => {
    const dir = path.join(__dirname, '..', 'modules/bar/panels');
    for (const s of Styles.STYLES) {
        assert.ok(s.hidden ? s.file === '' : fs.existsSync(path.join(dir, s.file)), s.file);
        assert.ok(s.edges.length > 0 && s.edges.every(e => Layout.EDGES.includes(e)), s.id);
        assert.ok(s.groups.every(g => Styles.GROUPS.includes(g)), s.id);
        assert.ok(['tab', 'pill'].includes(s.activity), s.id);
    }
    assert.deepEqual(plain(BarLayout.STYLES), plain(Styles.ids()));
});

test('module registry: unique ids, files exist, legacy ids kept', () => {
    const ids = plain(Modules.ids());
    assert.equal(new Set(ids).size, ids.length);
    for (const legacy of ['launcher', 'workspaces', 'layoutSelector', 'pin', 'presets', 'tools', 'systray', 'controls', 'battery', 'clock', 'power'])
        assert.ok(ids.includes(legacy), legacy);
    for (const m of Modules.MODULES) {
        if (m.file)
            assert.ok(fs.existsSync(path.join(__dirname, '..', 'modules/bar', m.file)), m.file);
    }
    assert.deepEqual(plain(BarLayout.MODULE_IDS), ids);
});

test('config: panels default, validator keeps panel arrays and any registry style', () => {
    assert.deepEqual(barDefaults.panels, []);
    const v = plain(validator.validate({ panels: [{ id: 'a', style: 'dock' }], layout: { style: 'menubar' } }, barDefaults));
    assert.equal(v.panels[0].style, 'dock');
    assert.equal(v.layout.style, 'menubar');
    assert.equal(plain(validator.validate({ layout: { style: 'nope' } }, barDefaults)).layout.style, 'classic');
});

test('separators interleave modules', () => {
    assert.deepEqual(plain(BarLayout.withSeparators(['a', 'b', 'c'])), ['a', '__sep__', 'b', '__sep__', 'c']);
    assert.deepEqual(plain(BarLayout.withSeparators([])), []);
});

test('a panel holding the old default right group gets the keyboard indicator', () => {
    const old = { position: 'right', layout: { style: 'classic', left: ['launcher', 'workspaces', 'layoutSelector', 'pin'], right: ['presets', 'tools', 'systray', 'controls', 'battery', 'clock', 'power'], drawer: [] } };
    const g = plain(Layout.resolveGroups(Layout.fromLegacy(old)));
    assert.deepEqual(g.center, ['layoutSelector', 'workspaces', 'pin']);
    assert.ok(g.end.includes('keyboardLayout'));
    const h = plain(Layout.resolveGroups(Layout.fromLegacy({ ...old, position: 'top' })));
    assert.ok(h.end.includes('keyboardLayout'));
});

test('estimateDepth: explicit thickness, then size, then the style size; plus the explicit margin', () => {
    assert.equal(Layout.estimateDepth({ style: 'classic', thickness: 40, size: 0, margin: 6 }, 30), 46);
    assert.equal(Layout.estimateDepth({ style: 'classic', thickness: 0, size: 32, margin: -1 }, 30), 32);
    assert.equal(Layout.estimateDepth({ style: 'menubar', thickness: 0, size: 0, margin: -1 }, 30), 26);
    assert.equal(Layout.estimateDepth({ style: 'classic', thickness: 0, size: 0, margin: 4 }, 30), 34);
});
