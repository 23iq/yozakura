const { test } = require('node:test');
const assert = require('node:assert/strict');
const path = require('node:path');
const { loadLibrary } = require('./lib/qmljs.cjs');
const S = loadLibrary(path.join(__dirname, '../modules/shell/osd/OsdStyles.js'));
const E = loadLibrary(path.join(__dirname, '../modules/shell/EdgeLayout.js'));
const EDGES = ['top', 'bottom', 'left', 'right'];
const env = (bar) => ({ screen: { w: 1920, h: 1080 }, frame: 0,
    bar: { pos: bar, size: 40, visible: true }, dock: { pos: 'bottom', size: 0, visible: false },
    notch: { pos: 'top', height: 36, visible: true } });

test('registry lists the four styles, each with a file', () => {
    assert.deepEqual([...S.STYLES], ['pill', 'edge', 'island', 'bar-inline']);
    for (const s of S.STYLES) assert.match(S.fileFor(s), /^styles\/Osd[A-Za-z]+\.qml$/);
});
test('unknown style falls back to pill', () => {
    assert.equal(S.normalize('minimal'), 'pill');
    assert.equal(S.normalize(undefined), 'pill');
    assert.equal(S.fileFor('nope'), 'styles/OsdPill.qml');
});
test('bar-inline falls back to pill without a bar widget', () => {
    assert.deepEqual({ ...S.resolve('bar-inline', { inlineAvailable: false }) }, { style: 'pill', window: true });
    assert.deepEqual({ ...S.resolve('bar-inline', { inlineAvailable: true }) }, { style: 'bar-inline', window: false });
});
test('island hides the window only when the notch handles it', () => {
    assert.equal(S.resolve('island', { islandHandled: true }).window, false);
    assert.equal(S.resolve('island', { islandHandled: false }).window, true);
    assert.equal(S.resolve('pill', {}).window, true);
});
test('every style on every bar edge stays on screen and off the bar', () => {
    for (const style of ['pill', 'edge', 'island']) for (const bar of EDGES) for (const pref of ['auto', ...EDGES]) {
        const e = env(bar);
        const edge = S.edgePref(style, pref, 'top');
        const probe = E.osdPlacement(e, edge, { w: 10, h: 10 });
        const size = S.sizeFor(style, probe.vertical, 220);
        const p = E.osdPlacement(e, edge, size);
        const w = E.workArea(e);
        const tag = `${style}/${bar}/${pref}`;
        assert.ok(p.x >= w.x && p.y >= w.y && p.x + size.w <= w.x + w.w && p.y + size.h <= w.y + w.h, tag);
        if (pref === 'auto' && style !== 'island') assert.notEqual(p.edge, bar, tag);
    }
});
test('edge style is vertical on side edges and horizontal on top/bottom', () => {
    const v = S.sizeFor('edge', true, 220), h = S.sizeFor('edge', false, 220);
    assert.ok(v.h > v.w && h.w > h.h);
});
test('island follows the notch edge when auto', () => {
    assert.equal(S.edgePref('island', 'auto', 'bottom'), 'bottom');
    assert.equal(S.edgePref('island', 'left', 'bottom'), 'left');
    assert.equal(S.edgePref('pill', 'auto', 'bottom'), 'auto');
});
test('wheel steps and clamping', () => {
    assert.equal(S.wheelStep(120), 0.05);
    assert.equal(S.wheelStep(-120), -0.05);
    assert.equal(S.wheelStep(0), 0);
    assert.equal(S.clamp01(1.4), 1);
    assert.equal(S.clamp01(-1), 0);
    assert.equal(S.percent(0.456), 46);
});
test('device names: description first, then nick, then name; only on a real switch', () => {
    assert.equal(S.deviceName({ description: 'Headphones', nickname: 'x', name: 'y' }), 'Headphones');
    assert.equal(S.deviceName({ nickname: 'x', name: 'y' }), 'x');
    assert.equal(S.deviceName(null), '');
    assert.equal(S.deviceSwitched('a', 'b'), true);
    assert.equal(S.deviceSwitched('', 'b'), false);
    assert.equal(S.deviceSwitched('a', 'a'), false);
});
test('mute is its own visual state', () => {
    assert.equal(S.stateOf('volume', 0.5, true), 'muted');
    assert.equal(S.stateOf('mic', 0.5, true), 'muted');
    assert.equal(S.stateOf('volume', 0, false), 'zero');
    assert.equal(S.stateOf('volume', 0.5, false), 'on');
    assert.equal(S.stateOf('brightness', 0.5, false), 'on');
});
