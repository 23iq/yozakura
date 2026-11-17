const { test } = require('node:test');
const assert = require('node:assert/strict');
const path = require('node:path');

const qmljs = require('./lib/qmljs.cjs');
const Scroll = qmljs.loadLibrary(path.join(__dirname, '..', 'modules/bar/workspaces/WorkspaceScroll.js'));

test('wheel down goes to the next workspace, up to the previous one', () => {
    assert.equal(Scroll.target(-120, false), 'workspace r+1');
    assert.equal(Scroll.target(120, false), 'workspace r-1');
});

test('workspaces.invertScroll swaps the directions', () => {
    assert.equal(Scroll.target(-120, true), 'workspace r-1');
    assert.equal(Scroll.target(120, true), 'workspace r+1');
});

test('no vertical step, no switch', () => {
    assert.equal(Scroll.target(0, false), '');
    assert.equal(Scroll.target(0, true), '');
});
