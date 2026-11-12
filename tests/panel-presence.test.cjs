const { test } = require('node:test');
const assert = require('node:assert/strict');
const path = require('node:path');
const { loadLibrary } = require('./lib/qmljs.cjs');
const P = loadLibrary(path.join(__dirname, '../modules/shell/PanelPresence.js'));

test('without a fullscreen window the panel always stays mapped', () => {
    assert.deepEqual([...P.reasons({ fullscreen: false })], ['noFullscreen']);
    assert.deepEqual([...P.reasons({})], ['noFullscreen']);
    assert.deepEqual([...P.reasons(undefined)], ['noFullscreen']);
    assert.equal(P.keepMapped({ fullscreen: false }), true);
});

test('under a fullscreen window with nothing to show it may unmap', () => {
    assert.deepEqual([...P.reasons({ fullscreen: true })], []);
    assert.equal(P.keepMapped({ fullscreen: true }), false);
    const allOff = { fullscreen: true };
    for (const r of P.REASONS) allOff[r] = false;
    assert.equal(P.keepMapped(allOff), false);
});

test('every reason alone keeps it mapped', () => {
    for (const r of P.REASONS) {
        const s = { fullscreen: true };
        s[r] = true;
        assert.deepEqual([...P.reasons(s)], [r], r);
        assert.equal(P.keepMapped(s), true, r);
    }
});

test('the reasons cover the panel children and input regions', () => {
    // Bar/notch/dock hover strips, the surfaces, the popups anchored to the
    // window, notifications in every presentation, views, the OSD in the
    // bar or notch, focus grabs and the frame drawn by the panel
    assert.deepEqual([...P.REASONS], ['barRevealOnHover', 'dockRevealOnHover', 'barShown', 'barPopupOpen',
        'notchShown', 'notchOpen', 'dockShown', 'activitiesShown', 'notifications', 'stripsOpen', 'cornerPills',
        'moduleOpen', 'osdInPanel', 'focusGrab', 'frameDrawn']);
});

test('several reasons are all reported, in a stable order', () => {
    const s = { fullscreen: true, focusGrab: true, notifications: true, barShown: 1 };
    assert.deepEqual([...P.reasons(s)], ['barShown', 'notifications', 'focusGrab']);
});
