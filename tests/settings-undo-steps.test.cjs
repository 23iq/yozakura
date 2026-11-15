// The settings window's undo steps (modules/settings/UndoModel.js): what a
// push did (added / merged / cancelled, with the step's id for the undo
// pill), multi-key steps that merge (a macro slider drag is one step), and
// the checks that keep an undo from writing a stale value.
const { test } = require('node:test');
const assert = require('node:assert/strict');
const path = require('node:path');
const { loadLibrary } = require('./lib/qmljs.cjs');

const repo = path.join(__dirname, '..');
const Undo = loadLibrary(path.join(repo, 'modules/settings/UndoModel.js'));
const SchemaUtil = loadLibrary(path.join(repo, 'modules/settings/SchemaUtil.js'));
const eq = SchemaUtil.equal;
const plain = v => JSON.parse(JSON.stringify(v));

function step(label, id, ...changes) {
    let list = [];
    for (const [key, before, after] of changes)
        list = Undo.addChange(list, key, before, after);
    return { id, label, changes: list };
}

test('a macro slider dragged over several points is one step', () => {
    let s = [];
    // Roundness: every point moves the radius, some also the corners
    s = Undo.push(s, step('prefs.macro.roundness', 1, ['theme.roundness', 4, 8], ['theme.enableCorners', false, true]), 1000, eq);
    s = Undo.push(s, step('prefs.macro.roundness', 2, ['theme.roundness', 8, 12]), 1100, eq);
    s = Undo.push(s, step('prefs.macro.roundness', 3, ['theme.roundness', 12, 16], ['theme.enableCorners', true, false]), 1200, eq);
    s = Undo.push(s, step('prefs.macro.roundness', 4, ['theme.roundness', 16, 20], ['theme.enableCorners', false, true]), 1300, eq);
    assert.equal(s.length, 1);
    assert.equal(s[0].id, 1, 'the merged step keeps its id');
    assert.deepEqual(plain(s[0].changes.map(c => [c.key, c.before, c.after])),
        [['theme.roundness', 4, 20], ['theme.enableCorners', false, true]]);
});

test('multi-key steps merge only with the same label, overlapping keys, in the window', () => {
    let s = Undo.push([], step('prefs.macro.depth', 1, ['theme.shadowOpacity', 0, 0.2], ['theme.lighting.strength', 0, 1]), 1000, eq);
    s = Undo.push(s, step('prefs.macro.glass', 2, ['theme.glass.enabled', false, true], ['theme.glass.amount', -1, 0.5]), 1100, eq);
    assert.equal(s.length, 2, 'another macro is another step');
    s = Undo.push(s, step('prefs.macro.glass', 3, ['theme.glass.amount', 0.5, 0.7]), 1100 + Undo.COALESCE_MS + 1, eq);
    assert.equal(s.length, 3, 'the same macro later is another step');
    s = Undo.push(s, step('prefs.undo.surface_moved', 4, ['layout.launcher.host', 'auto', 'sheet']), 5000, eq);
    s = Undo.push(s, step('prefs.undo.surface_moved', 5, ['layout.dashboard.host', 'auto', 'sheet']), 5100, eq);
    assert.equal(s.length, 5, 'the same label on unrelated keys is another step');
});

test('pushResult says what happened, with the id the pill names', () => {
    let r = Undo.pushResult([], step('prefs.bar.compact', 7, ['bar.compact', false, true]), 1000, eq);
    assert.equal(r.outcome, 'added');
    assert.equal(r.step.id, 7);
    r = Undo.pushResult(r.stack, step('workspaces', 8, ['workspaces.shown', 10, 9]), 1200, eq);
    r = Undo.pushResult(r.stack, step('workspaces', 9, ['workspaces.shown', 9, 8]), 1300, eq);
    assert.equal(r.outcome, 'merged');
    assert.equal(r.step.id, 8);
    // the switch flipped back: the step is gone, and says which one
    r = Undo.pushResult(r.stack, step('workspaces', 10, ['workspaces.shown', 8, 10]), 1400, eq);
    assert.equal(r.outcome, 'cancelled');
    assert.equal(r.step.id, 8);
    assert.equal(r.stack.length, 1);
    assert.equal(r.stack[0].id, 7, 'the older step stays on top');
    r = Undo.pushResult(r.stack, { id: 11, label: 'x', changes: [] }, 1500, eq);
    assert.equal(r.outcome, 'none');
});

test('holds: a step undoes only while its keys still hold what it set', () => {
    const s = step('prefs.bar.ws_shown', 1, ['workspaces.shown', 10, 5]);
    const now = { 'workspaces.shown': 5 };
    const get = k => now[k];
    assert.equal(Undo.holds(s, 'after', get, eq), true);
    now['workspaces.shown'] = 7;
    assert.equal(Undo.holds(s, 'after', get, eq), false, 'changed elsewhere since');
    assert.equal(Undo.holds(s, 'after', get, eq, k => k === 'workspaces.shown'), true, 'a trusted key is not checked');
    now['workspaces.shown'] = 10;
    assert.equal(Undo.holds(s, 'before', get, eq), true, 'redo checks the value it starts from');
});

test('consistent: a reload that changed a value the history expects is noticed', () => {
    const undo = [
        step('a', 1, ['bar.compact', false, true]),
        step('b', 2, ['bar.compact', true, false], ['bar.clockShowDate', false, true]),
    ];
    const redo = [step('c', 3, ['dock.position', 'bottom', 'left'])];
    const now = { 'bar.compact': false, 'bar.clockShowDate': true, 'dock.position': 'bottom', 'bar.other': 1 };
    const get = k => now[k];
    const bar = k => k.startsWith('bar.');
    assert.equal(Undo.consistent(undo, redo, get, eq, bar), true, 'the newest step of each key matches');
    now['bar.other'] = 2;
    assert.equal(Undo.consistent(undo, redo, get, eq, bar), true, 'a key the history never touched');
    now['bar.compact'] = true;
    assert.equal(Undo.consistent(undo, redo, get, eq, bar), false);
    now['bar.compact'] = false;
    now['dock.position'] = 'top';
    assert.equal(Undo.consistent(undo, redo, get, eq, bar), true, 'another domain is not checked');
    assert.equal(Undo.consistent(undo, redo, get, eq), false, 'the next redo no longer starts there');
});
