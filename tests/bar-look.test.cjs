// Rules of the bar's kit look (modules/bar/look/BarLookRules.js).
const { test } = require('node:test');
const assert = require('node:assert/strict');
const path = require('node:path');

const qmljs = require('./lib/qmljs.cjs');
const Rules = qmljs.loadLibrary(path.join(__dirname, '..', 'modules/bar/look/BarLookRules.js'));

test('bar surface: a visible strip or a containing frame', () => {
    assert.equal(Rules.barSurface(0, false, false), false);
    assert.equal(Rules.barSurface(0.6, false, false), true);
    assert.equal(Rules.barSurface(0, true, false), false, 'containBar needs the frame');
    assert.equal(Rules.barSurface(0, true, true), true);
    assert.equal(Rules.barSurface(undefined, false, true), false);
});

test('rest look of a module box per language', () => {
    assert.equal(Rules.restLook('ink', true, true, false), 'none', 'flat modules have no box');
    assert.equal(Rules.restLook('classic', false, true, false), 'surface', 'classic keeps the bg pill');
    assert.equal(Rules.restLook('ink', false, true, false), 'group', 'on a visible bar: the group box');
    assert.equal(Rules.restLook('glass', false, true, false), 'group');
    assert.equal(Rules.restLook('ink', false, false, false), 'surface', 'transparent bar: the pill is the surface');
    assert.equal(Rules.restLook('glass', false, false, false), 'surface');
    assert.equal(Rules.restLook('tiles', false, false, true), 'group', 'solid tiles stand on their own');
});

test('module text role and glyph size', () => {
    assert.equal(Rules.textRole(36, 32), 'body');
    assert.equal(Rules.textRole(26, 32), 'secondary');
    assert.equal(Rules.iconSize(17, 36), 17);
    assert.ok(Rules.iconSize(17, 26) < 17 && Rules.iconSize(17, 26) >= 8);
    assert.equal(Rules.iconSize(4, 10), 8, 'never below 8 px');
});
