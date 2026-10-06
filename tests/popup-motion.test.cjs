const { test } = require('node:test');
const assert = require('node:assert/strict');
const path = require('node:path');
const { loadLibrary } = require('./lib/qmljs.cjs');
const K = loadLibrary(path.join(__dirname, '../modules/components/PopupMotionKinds.js'));

const DIRS = ['down', 'up', 'left', 'right'];
const close = (a, b, msg) => assert.ok(Math.abs(a - b) < 1e-9, `${msg}: ${a} != ${b}`);

test('registry lists the four entry kinds; unknown falls back to fade-scale', () => {
    assert.deepEqual([...K.KINDS], ['fade-scale', 'slide-from-anchor', 'morph-from-bar', 'unfold']);
    assert.equal(K.kind('unfold'), 'unfold');
    assert.equal(K.kind('wobble'), 'fade-scale');
    assert.equal(K.kind(undefined), 'fade-scale');
});

test('the anchor edge is the popup edge facing back toward the anchor', () => {
    assert.equal(K.anchorEdge('down'), 'top');
    assert.equal(K.anchorEdge('up'), 'bottom');
    assert.equal(K.anchorEdge('right'), 'left');
    assert.equal(K.anchorEdge('left'), 'right');
    assert.equal(K.anchorEdge('sideways'), 'top');
});

test('every kind ends at rest (t = 1) and starts hidden (t = 0)', () => {
    for (const kind of K.KINDS) {
        for (const dir of DIRS) {
            const end = K.frame(kind, dir, 1, 16);
            close(end.opacity, 1, `${kind}/${dir} opacity`);
            close(end.scaleX, 1, `${kind}/${dir} scaleX`);
            close(end.scaleY, 1, `${kind}/${dir} scaleY`);
            close(end.dx, 0, `${kind}/${dir} dx`);
            close(end.dy, 0, `${kind}/${dir} dy`);
            close(K.frame(kind, dir, 0, 16).opacity, 0, `${kind}/${dir} starts transparent`);
        }
    }
});

test('slide-from-anchor starts displaced toward the anchor', () => {
    assert.deepEqual(JSON.parse(JSON.stringify(K.frame('slide-from-anchor', 'down', 0, 16))).dy, -16);
    assert.equal(K.frame('slide-from-anchor', 'up', 0, 16).dy, 16);
    assert.equal(K.frame('slide-from-anchor', 'right', 0, 16).dx, -16);
    assert.equal(K.frame('slide-from-anchor', 'left', 0, 16).dx, 16);
    assert.equal(K.frame('slide-from-anchor', 'left', 0, 16).dy, 0);
});

test('unfold and morph grow along the opening axis', () => {
    const v = K.frame('unfold', 'down', 0.5, 16);
    close(v.scaleX, 1, 'unfold down keeps its width');
    assert.ok(v.scaleY < 1);
    const hz = K.frame('unfold', 'right', 0.5, 16);
    close(hz.scaleY, 1, 'unfold right keeps its height');
    assert.ok(hz.scaleX < 1);
    const m = K.frame('morph-from-bar', 'up', 0.25, 16);
    assert.ok(m.scaleY < m.scaleX, 'morph is flatter along the axis than across it');
});

test('opacity is clamped when an OutBack easing overshoots', () => {
    for (const kind of K.KINDS) {
        const f = K.frame(kind, 'down', 1.15, 16);
        assert.ok(f.opacity <= 1 && f.opacity >= 0, kind);
        assert.ok(f.scaleX > 0 && f.scaleY > 0, kind);
    }
});

test('the transform origin sits on the anchor edge', () => {
    assert.deepEqual(JSON.parse(JSON.stringify(K.origin('down', 200, 100, -1))), { x: 100, y: 0 });
    assert.deepEqual(JSON.parse(JSON.stringify(K.origin('up', 200, 100, 30))), { x: 30, y: 100 });
    assert.deepEqual(JSON.parse(JSON.stringify(K.origin('right', 200, 100, -1))), { x: 0, y: 50 });
    assert.deepEqual(JSON.parse(JSON.stringify(K.origin('left', 200, 100, 500))), { x: 200, y: 100 });
});
