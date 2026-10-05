const { test } = require('node:test');
const assert = require('node:assert/strict');
const fs = require('node:fs');
const vm = require('node:vm');
const path = require('node:path');

const cov = {};
vm.runInNewContext(fs.readFileSync(path.join(__dirname, '../modules/widgets/dashboard/wallpapers/WallpaperCoverage.js'), 'utf8').replace(/^\.pragma library\s*/, ''), cov);

const mon = { id: 0, x: 0, y: 0, width: 2560, height: 1440, scale: 1, transform: 0, activeWorkspace: { id: 1 } };
const win = (x, y, w, h, extra) => Object.assign({ monitor: 0, workspace: { id: 1 }, hidden: false, at: [x, y], size: [w, h] }, extra || {});

test('rectCovered: exact union, gaps and overlaps', () => {
    const t = { x: 0, y: 0, w: 100, h: 100 };
    assert.equal(cov.rectCovered(t, [{ x: 0, y: 0, w: 100, h: 100 }]), true);
    assert.equal(cov.rectCovered(t, [{ x: 0, y: 0, w: 50, h: 100 }, { x: 50, y: 0, w: 50, h: 100 }]), true);
    assert.equal(cov.rectCovered(t, [{ x: 0, y: 0, w: 49, h: 100 }, { x: 50, y: 0, w: 50, h: 100 }]), false);
    assert.equal(cov.rectCovered(t, [{ x: -10, y: -10, w: 70, h: 120 }, { x: 40, y: 0, w: 80, h: 100 }]), true);
    // L-shape leaves a corner uncovered
    assert.equal(cov.rectCovered(t, [{ x: 0, y: 0, w: 100, h: 50 }, { x: 0, y: 50, w: 50, h: 50 }]), false);
    assert.equal(cov.rectCovered(t, []), false);
});

test('a single tiled window with gaps 0 covers; gaps_out leaves the wallpaper visible', () => {
    assert.equal(cov.covered(mon, [win(0, 0, 2560, 1440)], null, 0), true);
    assert.equal(cov.covered(mon, [win(22, 22, 2516, 1396)], null, 2), false);
});

test('borders close a window-sized gap of their own width', () => {
    assert.equal(cov.covered(mon, [win(2, 2, 2556, 1436)], null, 2), true);
    assert.equal(cov.covered(mon, [win(2, 2, 2556, 1436)], null, 0), false);
});

test('two tiled windows: gaps_in 0 covers, gaps_in > border does not', () => {
    assert.equal(cov.covered(mon, [win(0, 0, 1280, 1440), win(1280, 0, 1280, 1440)], null, 0), true);
    assert.equal(cov.covered(mon, [win(0, 0, 1275, 1440), win(1285, 0, 1275, 1440)], null, 2), false);
});

test('monocle: stacked windows covering the area count', () => {
    assert.equal(cov.covered(mon, [win(0, 44, 2560, 1396), win(0, 44, 2560, 1396)], { top: 44 }, 0), true);
});

test('shell insets: a reserved strip counts only when the caller says it is opaque', () => {
    const w = [win(0, 44, 2560, 1396)];
    assert.equal(cov.covered(mon, w, { top: 44 }, 0), true);
    assert.equal(cov.covered(mon, w, null, 0), false);
});

test('other workspaces, other monitors and hidden windows are ignored', () => {
    assert.equal(cov.covered(mon, [win(0, 0, 2560, 1440, { workspace: { id: 2 } })], null, 0), false);
    assert.equal(cov.covered(mon, [win(0, 0, 2560, 1440, { monitor: 1 })], null, 0), false);
    assert.equal(cov.covered(mon, [win(0, 0, 2560, 1440, { hidden: true })], null, 0), false);
    assert.equal(cov.covered(null, [win(0, 0, 2560, 1440)], null, 0), false);
});

test('monitor offset, scale and rotation', () => {
    const m2 = { id: 1, x: 2560, y: 0, width: 3840, height: 2160, scale: 1.5, transform: 0, activeWorkspace: { id: 7 } };
    const w2 = (x, y, w, h) => win(x, y, w, h, { monitor: 1, workspace: { id: 7 } });
    assert.equal(cov.covered(m2, [w2(2560, 0, 2560, 1440)], null, 0), true);
    assert.equal(cov.covered(m2, [w2(0, 0, 2560, 1440)], null, 0), false);
    const rot = Object.assign({}, m2, { transform: 1 });
    assert.equal(cov.covered(rot, [w2(2560, 0, 1440, 2560)], null, 0), true);
});
