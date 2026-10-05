const { test } = require('node:test');
const assert = require('node:assert/strict');
const path = require('node:path');

const qmljs = require('./lib/qmljs.cjs');
const lib = file => qmljs.loadLibrary(path.join(__dirname, '..', file));
const plain = v => JSON.parse(JSON.stringify(v));

const Model = lib('modules/settings/PanelsModel.js');
const Sketch = lib('modules/settings/PanelSketch.js');
const SchemaUtil = lib('modules/settings/SchemaUtil.js');
const barDefaults = plain(lib('config/defaults/bar.js').data);

test('the first edit turns the legacy bar into bar.panels', () => {
    assert.equal(Model.isLegacy(barDefaults), true);
    const panels = Model.panelsOf(barDefaults);
    const next = plain(Model.setField(panels, 0, 'style', 'islands'));
    assert.equal(next.length, 1);
    assert.equal(next[0].style, 'islands');
    assert.deepEqual(next[0].groups.start, barDefaults.layout.left);
    assert.equal(Model.isLegacy({ ...barDefaults, panels: next }), false);
});

test('add / remove panels pick a free edge and unique ids', () => {
    let list = plain(Model.panelsOf(barDefaults));
    list = plain(Model.addPanel(Model.panelsOf({ panels: list }), 'classic'));
    assert.equal(list.length, 2);
    assert.equal(list[1].edge, 'bottom');
    list = plain(Model.addPanel(Model.panelsOf({ panels: list }), 'dock'));
    assert.equal(list[2].id, 'dock');
    assert.deepEqual(list[2].groups.center, ['taskbar']);
    list = plain(Model.removePanel(Model.panelsOf({ panels: list }), 0));
    assert.deepEqual(list.map(p => p.id), ['panel', 'dock']);
});

test('style and edge changes keep a valid pair', () => {
    const panels = Model.panelsOf({ panels: [{ id: 'a', edge: 'left', style: 'classic' }] });
    const menubar = plain(Model.setField(panels, 0, 'style', 'menubar'))[0];
    assert.equal(menubar.edge, 'top');
    assert.equal(menubar.flat, true);
    const rail = Model.panelsOf({ panels: [{ id: 'r', edge: 'left', style: 'rail' }] });
    assert.equal(plain(Model.setField(rail, 0, 'edge', 'top'))[0].style, 'classic');
});

test('modules move between groups, the palette lists the rest', () => {
    const panels = Model.panelsOf({ panels: [{ id: 'a', style: 'islands', groups: { start: ['launcher'], end: ['clock'] } }] });
    const moved = Model.panelsOf({ panels: plain(Model.moveModule(panels, 0, 'clock', 'gapEnd', 0)) });
    assert.deepEqual(plain(moved[0].groups.gapEnd), ['clock']);
    assert.deepEqual(plain(Model.locate(moved[0], 'clock')), { group: 'gapEnd', index: 0 });
    assert.ok(Model.unused(moved[0]).includes('taskbar'));
    const removed = Model.panelsOf({ panels: plain(Model.moveModule(moved, 0, 'launcher', 'available', -1)) });
    assert.equal(Model.locate(removed[0], 'launcher').group, 'available');
    assert.deepEqual(plain(Model.groupsOf({ style: 'statusline' })), ['start', 'center', 'end']);
});

test('sketch: shapes per style, mapped to the edge', () => {
    const W = 640, H = 360, unit = 18;
    const panel = s => Model.panelsOf({ panels: [s] })[0];
    const band = Sketch.sketch(panel({ edge: 'bottom', style: 'statusline', groups: { start: ['clock'] } }), W, H, unit);
    assert.equal(band.shapes.length, 1);
    assert.equal(band.shapes[0].kind, 'band');
    assert.equal(band.shapes[0].y + band.shapes[0].h, H);
    assert.equal(band.icons.length, 1);
    const tabs = Sketch.sketch(panel({ edge: 'top', style: 'corners', groups: { start: ['launcher'], end: ['clock', 'power'] } }), W, H, unit);
    assert.equal(tabs.shapes.length, 2);
    assert.equal(tabs.shapes[1].x + tabs.shapes[1].w, W);
    const dock = Sketch.sketch(panel({ edge: 'bottom', style: 'dock', groups: { center: ['taskbar'], end: ['downloads'] } }), W, H, unit);
    assert.equal(dock.shapes[0].kind, 'dock');
    assert.ok(Math.abs(dock.shapes[0].x + dock.shapes[0].w / 2 - W / 2) < 1, 'centered');
    const rail = Sketch.sketch(panel({ edge: 'left', style: 'rail', groups: { start: ['launcher'] } }), W, H, unit);
    assert.equal(rail.shapes[0].x, 0);
    assert.equal(rail.shapes[0].h, H);
    assert.ok(rail.depth > 0);
    assert.equal(Sketch.sketch(panel({ edge: 'top', style: 'islands', autohide: 'always', groups: { start: ['clock'] } }), W, H, unit).depth, 0);
});

test('schema condition `empty` for list keys', () => {
    const get = k => ({ 'bar.panels': [], 'x.y': [1] })[k];
    assert.equal(SchemaUtil.evalCondition({ key: 'bar.panels', empty: true }, get), true);
    assert.equal(SchemaUtil.evalCondition({ key: 'x.y', empty: true }, get), false);
    assert.equal(SchemaUtil.evalCondition({ key: 'missing', empty: true }, get), true);
});
