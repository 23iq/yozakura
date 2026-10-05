const { test } = require('node:test');
const assert = require('node:assert/strict');
const path = require('node:path');
const { loadLibrary } = require('./lib/qmljs.cjs');

const slot = loadLibrary(path.join(__dirname, '../modules/bar/workspaces/WorkspaceSlot.js'));

// The inline expressions Workspaces.qml used before the slot was extracted;
// the helpers must agree with them for every combination.
const legacy = {
    number: (w, win) => !!(w.alwaysShowNumbers || ((w.showNumbers && (!w.showAppIcons || !win || w.alwaysShowNumbers)) || (w.alwaysShowNumbers && !w.showAppIcons))),
    dot: (w, win, active, occupied) => (w.showNumbers || w.alwaysShowNumbers || (w.showAppIcons && win)) ? 0 : (active || occupied ? 1 : 0.5),
    iconFull: w => !!(!w.alwaysShowNumbers && w.showAppIcons),
    icon: (w, win, shrinked) => !w.showAppIcons ? 0 : (win && !w.alwaysShowNumbers && w.showAppIcons) ? 1 : win ? shrinked : 0,
};

function* combos() {
    for (const showNumbers of [false, true])
        for (const alwaysShowNumbers of [false, true])
            for (const showAppIcons of [false, true])
                for (const win of [false, true])
                    for (const active of [false, true])
                        for (const occupied of [false, true])
                            yield { ws: { showNumbers, alwaysShowNumbers, showAppIcons }, win, active, occupied };
}

test('slot layer visibility matches the pre-refactor expressions', () => {
    for (const { ws, win, active, occupied } of combos()) {
        const tag = JSON.stringify({ ws, win, active, occupied });
        assert.equal(slot.numberVisible(ws, win), legacy.number(ws, win), 'number ' + tag);
        assert.equal(slot.dotOpacity(ws, win, active, occupied), legacy.dot(ws, win, active, occupied), 'dot ' + tag);
        assert.equal(slot.iconFullSize(ws), legacy.iconFull(ws), 'iconFull ' + tag);
        assert.equal(slot.iconOpacity(ws, win, 0.7), legacy.icon(ws, win, 0.7), 'icon ' + tag);
    }
});

test('numbers only on empty workspaces when app icons are on', () => {
    const ws = { showNumbers: true, alwaysShowNumbers: false, showAppIcons: true };
    assert.equal(slot.numberVisible(ws, false), true);
    assert.equal(slot.numberVisible(ws, true), false);
    assert.equal(slot.numberVisible({ ...ws, showAppIcons: false }, true), true);
});
