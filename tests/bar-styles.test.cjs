const { test } = require('node:test');
const assert = require('node:assert/strict');
const path = require('node:path');

const qmljs = require('./lib/qmljs.cjs');
const lib = file => qmljs.loadLibrary(path.join(__dirname, '..', file));
const plain = v => JSON.parse(JSON.stringify(v));

const Layout = lib('modules/bar/panels/PanelLayout.js');
const Styles = lib('modules/bar/panels/PanelStyles.js');
const BarLayout = lib('modules/bar/BarLayout.js');
const EDGES = ['top', 'bottom', 'left', 'right'];

test('bar styles: full (classic), floating, islands, pills, dock-like and none', () => {
    const ids = plain(Styles.barStyles()).map(s => s.id);
    assert.deepEqual(ids, ['classic', 'floating', 'islands', 'pills', 'dock-like', 'none']);
    for (const id of ids) {
        assert.ok(BarLayout.STYLES.includes(id), id + ' is a valid bar.layout.style');
        assert.ok(Styles.get(id).label && Styles.get(id).desc, id + ' has a label');
    }
});

test('every bar style works on all four edges', () => {
    for (const s of plain(Styles.barStyles())) {
        for (const edge of EDGES) {
            const p = plain(Layout.fromLegacy({ position: edge, layout: { style: s.id } }));
            assert.equal(p.edge, edge, s.id + '@' + edge);
            assert.equal(p.style, s.id);
            assert.ok(Styles.supportsEdge(s.id, edge), s.id + ' supports ' + edge);
        }
    }
});

test('dock-like sizes to content and centers; floating and pills fill the edge', () => {
    const at = style => plain(Layout.fromLegacy({ position: 'top', layout: { style } }));
    assert.equal(at('dock-like').align, 'center');
    assert.equal(at('dock-like').flat, false, 'dock-like keeps the module pills');
    assert.equal(at('floating').align, 'fill');
    assert.equal(at('pills').align, 'fill');
    assert.equal(Styles.get('floating').containable, false, 'the frame never swallows a floating bar');
});

test('none: no bar window, nothing on any screen, nothing reserved', () => {
    const r = plain(Layout.normalize({ position: 'left', layout: { style: 'none' } }));
    assert.equal(r.panels.length, 1);
    assert.equal(r.panels[0].enabled, false);
    const shown = plain(Layout.forScreen(r.panels, 'DP-1', 0));
    assert.deepEqual(shown, []);
    assert.equal(Layout.primaryIndex(shown, 'top'), -1);
    assert.equal(Layout.primaryEdge({ position: 'left', layout: { style: 'none' } }, 'top'), 'left');
    const multi = plain(Layout.normalize({ panels: [{ id: 'a', style: 'none' }, { id: 'b', edge: 'bottom' }] }));
    assert.deepEqual(plain(Layout.forScreen(multi.panels, 'DP-1', 0)).map(p => p.id), ['b']);
    assert.deepEqual(multi.warnings, []);
});

test('settings sketch draws each bar style', () => {
    const Sketch = lib('modules/settings/PanelSketch.js');
    const W = 640, H = 360, unit = 18;
    const groups = { start: ['launcher', 'workspaces'], center: ['clock'], end: ['battery', 'power'] };
    const draw = style => {
        const p = plain(Layout.normalize({ panels: [{ id: 'p', edge: 'top', style, groups }] }).panels[0]);
        return plain(Sketch.sketch(p, W, H, unit));
    };
    const classic = draw('classic');
    const floating = draw('floating');
    assert.ok(floating.shapes[0].y > classic.shapes[0].y, 'floating is lifted off the edge');
    assert.ok(floating.shapes[0].w < classic.shapes[0].w);
    const pills = draw('pills');
    assert.equal(pills.shapes.length, 3);
    assert.ok(pills.shapes.every(s => s.y > 0 && s.kind === 'dock'), 'pills float');
    const dockLike = draw('dock-like');
    assert.equal(dockLike.shapes.length, 1);
    assert.ok(Math.abs(dockLike.shapes[0].x * 2 + dockLike.shapes[0].w - W) <= 1, 'dock-like is centered');
    const none = draw('none');
    assert.deepEqual(none.shapes, []);
    assert.equal(none.depth, 0);
});
