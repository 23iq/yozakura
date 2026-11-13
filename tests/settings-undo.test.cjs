// The settings window's undo history (modules/settings/UndoModel.js) and the
// pages it keeps alive (modules/settings/PageCache.js).
const { test } = require('node:test');
const assert = require('node:assert/strict');
const path = require('node:path');
const { loadLibrary } = require('./lib/qmljs.cjs');

const repo = path.join(__dirname, '..');
const Undo = loadLibrary(path.join(repo, 'modules/settings/UndoModel.js'));
const Cache = loadLibrary(path.join(repo, 'modules/settings/PageCache.js'));
const SchemaUtil = loadLibrary(path.join(repo, 'modules/settings/SchemaUtil.js'));
const Categories = loadLibrary(path.join(repo, 'modules/settings/schema/Categories.js'));
const plain = v => JSON.parse(JSON.stringify(v));
const eq = SchemaUtil.equal;
const one = (key, before, after, label) => ({ label: label || key, changes: Undo.addChange([], key, before, after) });

test('a change is one step; undo writes the value it replaced', () => {
    const s = Undo.push([], one('bar.compact', false, true), 1000, eq);
    assert.equal(s.length, 1);
    assert.deepEqual(plain(Undo.reverted(s[0])), [{ key: 'bar.compact', value: false }]);
    assert.deepEqual(plain(Undo.replayed(s[0])), [{ key: 'bar.compact', value: true }]);
});

test('a slider drag (the same setting, quickly) is one step from its start', () => {
    let s = [];
    for (let i = 1; i <= 20; i++)
        s = Undo.push(s, one('theme.roundness', 10 + i - 1, 10 + i), 1000 + i * 16, eq);
    assert.equal(s.length, 1);
    assert.deepEqual(plain(s[0].changes), [{ key: 'theme.roundness', before: 10, after: 30 }]);
});

test('the same setting later, or another setting, is a new step', () => {
    let s = Undo.push([], one('bar.compact', false, true), 1000, eq);
    s = Undo.push(s, one('bar.compact', true, false), 1000 + Undo.COALESCE_MS + 1, eq);
    s = Undo.push(s, one('bar.position', 'top', 'left'), 1000 + Undo.COALESCE_MS + 2, eq);
    assert.equal(s.length, 3);
});

test('dragged back to where it started: nothing to undo', () => {
    let s = Undo.push([], one('theme.roundness', 10, 12), 1000, eq);
    s = Undo.push(s, one('theme.roundness', 12, 10), 1100, eq);
    assert.equal(s.length, 0);
});

test('a transaction (reset page, a macro) keeps every key once, first value first', () => {
    let changes = Undo.addChange([], 'theme.roundness', 4, 16);
    changes = Undo.addChange(changes, 'theme.enableCorners', false, true);
    changes = Undo.addChange(changes, 'theme.roundness', 16, 24);
    const s = Undo.push([], { label: 'prefs.macro.roundness', changes }, 1000, eq);
    assert.deepEqual(plain(s[0].changes.map(c => [c.key, c.before, c.after])), [['theme.roundness', 4, 24], ['theme.enableCorners', false, true]]);
    // undone in reverse order
    assert.deepEqual(plain(Undo.reverted(s[0]).map(w => w.key)), ['theme.enableCorners', 'theme.roundness']);
});

test('values are copied: a later edit of the object does not change the history', () => {
    const layout = { left: ['clock'] };
    const s = Undo.push([], one('bar.layout', layout, { left: [] }), 1000, eq);
    layout.left.push('power');
    assert.deepEqual(plain(Undo.reverted(s[0])[0].value), { left: ['clock'] });
});

test('the history is bounded', () => {
    let s = [];
    for (let i = 0; i < Undo.LIMIT + 10; i++)
        s = Undo.push(s, one('k' + i, 0, 1), i * 10000, eq);
    assert.equal(s.length, Undo.LIMIT);
    assert.equal(s[0].changes[0].key, 'k10');
});

test('a key is named by its entry, a nested key by its parent entry', () => {
    const index = Undo.labelIndex(Categories.categories);
    assert.equal(Undo.labelFor(index, 'bar.compact'), 'prefs.bar.compact');
    assert.equal(Undo.labelFor(index, 'theme.fontSize'), 'settings.theme.ui_font');
    assert.equal(Undo.labelFor(index, 'bar.moduleOptions.clock.face.extra'), 'prefs.bar.clock_face');
    assert.equal(Undo.labelFor(index, 'nothing.here'), '');
});

test('page cache: a revisit moves the page to the front, the oldest beyond `keep` goes', () => {
    let pages = [];
    const dropped = [];
    for (const id of ['bar', 'look', 'dock', 'island', 'bar', 'launcher']) {
        const r = Cache.visit(pages, id, Cache.find(pages, id) || { name: id }, 4);
        pages = r.pages;
        dropped.push(...r.dropped.map(i => i.name));
    }
    assert.deepEqual(plain(pages.map(p => p.id)), ['launcher', 'bar', 'island', 'dock']);
    assert.deepEqual(dropped, ['look']);
    assert.equal(Cache.find(pages, 'look'), null);
    assert.equal(Cache.find(pages, 'bar').name, 'bar', 'a kept page is the same object');
});
