const { test } = require('node:test');
const assert = require('node:assert/strict');
const path = require('node:path');

const qmljs = require('./lib/qmljs.cjs');
const lib = file => qmljs.loadLibrary(path.join(__dirname, '..', file));
const plain = v => JSON.parse(JSON.stringify(v));

const Edit = lib('modules/bar/panels/PanelEdit.js');
const Layout = lib('modules/bar/panels/PanelLayout.js');
const Model = lib('modules/shell/LayoutModel.js');

const base = (o) => plain(Layout.normalizePanel(Object.assign({ id: 'a', edge: 'top', style: 'classic', groups: { start: ['launcher'], center: ['clock'], end: ['power'], drawer: ['tools'] } }, o || {}), 0, []));

test('a style pick resets align, flat and size, and clears enabled=false', () => {
    const p = base({ style: 'dock', edge: 'bottom', align: 'center', size: 40, enabled: false });
    const r = Edit.apply(p, 'style', 'classic');
    assert.equal(r.align, 'fill');
    assert.equal(r.flat, false);
    assert.equal(r.size, 0);
    assert.equal(r.enabled, true);
});

test('menubar to classic does not keep the flat look', () => {
    const r = Edit.apply(base({ style: 'menubar' }), 'style', 'classic');
    assert.equal(r.flat, false);
});

test('a style the edge does not support moves the edge; an unsupported edge moves the style to classic', () => {
    assert.equal(Edit.apply(base({ edge: 'left' }), 'style', 'menubar').edge, 'top');
    const r = Edit.apply(base({ style: 'menubar', edge: 'top' }), 'edge', 'left');
    assert.equal(r.style, 'classic');
    assert.equal(r.edge, 'left');
});

test('modules of groups the new style does not render are kept, moved to its end group', () => {
    const r = Edit.apply(base({ style: 'classic' }), 'style', 'statusline');
    assert.deepEqual(plain(r.groups.drawer), []);
    assert.ok(r.groups.end.includes('tools'));
    const all = [].concat(r.groups.start, r.groups.center, r.groups.end);
    ['launcher', 'clock', 'power', 'tools'].forEach(id => assert.ok(all.includes(id), id));
});

test('layout model and panels editor agree on the same edit', () => {
    const panels = [base({ style: 'menubar' })];
    const viaLayout = plain(Model.edit({ bar: { panels } }, 'bar', 'edge', 'left'))[0].value[0];
    assert.equal(viaLayout.style, 'classic');
    assert.equal(viaLayout.edge, 'left');
});

test('legacy bar: an edge/style pair is written complete', () => {
    const w = plain(Model.edit({ bar: { position: 'top', layout: { style: 'menubar' } } }, 'bar', 'edge', 'left'));
    assert.deepEqual(w, [{ key: 'bar.position', value: 'left' }, { key: 'bar.layout.style', value: 'classic' }]);
});

test('edgesFor / stylesFor list what a selector may offer', () => {
    assert.deepEqual(plain(Edit.edgesFor('menubar')), ['top', 'bottom']);
    assert.ok(plain(Edit.stylesFor('left')).includes('classic'));
    assert.ok(!plain(Edit.stylesFor('left')).includes('menubar'));
});

test('the dock has no top edge in the layout model', () => {
    assert.deepEqual(plain(Model.edgesOf('dock')).sort(), ['bottom', 'left', 'right']);
    assert.equal(Model.fromConfig({ dock: { position: 'top' } }).dock.edge, 'bottom');
});
