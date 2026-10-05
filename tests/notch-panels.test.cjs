const { test } = require('node:test');
const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');
const { loadLibrary: loadQmlJs } = require('./lib/qmljs.cjs');

const loadLibrary = file => loadQmlJs(path.join(__dirname, file));

const plain = value => JSON.parse(JSON.stringify(value));
const P = loadLibrary('../modules/widgets/defaultview/panels/NotchPanels.js');
const N = loadLibrary('../modules/widgets/defaultview/activities/NotchActivities.js');
const notchDefaults = plain(loadLibrary('../config/defaults/notch.js').data);
const validator = loadLibrary('../config/ConfigValidator.js');

test('every registered panel has a file, a unique id and trigger', () => {
    const ids = new Set();
    const triggers = new Set();
    for (const p of P.PANELS) {
        assert.ok(!ids.has(p.id) && !(p.trigger && triggers.has(p.trigger)), p.id);
        assert.ok(p.trigger || p.auto, `${p.id}: a panel without a trigger must open by itself (auto)`);
        ids.add(p.id);
        if (p.trigger)
            triggers.add(p.trigger);
        assert.ok(fs.existsSync(path.join(__dirname, '../modules/widgets/defaultview/panels', p.url)), p.url);
    }
});

test('triggers map to panels', () => {
    assert.equal(P.panelFor('media'), 'media');
    assert.equal(P.panelFor('tasks'), 'transfers');
    assert.equal(P.panelFor('timers'), 'timers');
    assert.equal(P.panelFor('privacy'), 'privacy');
    assert.equal(P.panelFor(''), '');
    assert.equal(P.panelFor('nope'), '');
});

test('availability follows the context', () => {
    const a = plain(P.availability({ player: true, transfers: 0, timers: 2, privacy: 1, voice: false }));
    assert.deepEqual(a, { media: true, transfers: false, timers: true, privacy: true, voice: false });
    assert.deepEqual(plain(P.availability({})), { media: false, transfers: false, timers: false, privacy: false, voice: false });
});

test('auto and modal panels (voice)', () => {
    assert.equal(P.panelFor(''), '', 'no trigger opens the voice panel');
    assert.equal(P.isAuto('voice'), true);
    assert.equal(P.isModal('voice'), true);
    assert.equal(P.isAuto('media'), false);
    assert.equal(P.isModal('media'), false);
    assert.equal(P.autoPanel({ media: true, voice: true }, ''), 'voice');
    assert.equal(P.autoPanel({ media: true, voice: false }, ''), '');
    assert.equal(P.autoPanel({ voice: true }, 'voice'), '', 'a dismissed auto panel stays closed');
    assert.equal(P.autoPanel(null, ''), '');
});

test('click toggling', () => {
    const av = { media: true, transfers: true, privacy: false };
    assert.equal(P.toggled('', 'media', av), 'media');
    assert.equal(P.toggled('media', 'media', av), '');
    assert.equal(P.toggled('media', 'transfers', av), 'transfers', 'switches panels');
    assert.equal(P.toggled('media', 'privacy', av), 'media', 'unavailable panel is ignored');
    assert.equal(P.widthFor('media', 440), 440);
    assert.equal(P.expandMode('click'), 'click');
    assert.equal(P.expandMode('bogus'), 'hover');
});

test('notch.expandOn default and validation', () => {
    assert.equal(notchDefaults.expandOn, 'hover');
    assert.equal(validator.validate({ expandOn: 'click' }, notchDefaults).expandOn, 'click');
    assert.equal(validator.validate({ expandOn: 'bogus' }, notchDefaults).expandOn, 'hover');
});

test('width templates reserve the widest size/speed shape', () => {
    const t = s => N.widthTemplate(s);
    assert.equal(t('38 MB · 4.2 MB/s'), '0000 MB · 0000 MB/s');
    assert.equal(t('980 KB · 12 MB/s'), t('1.2 GB · 4.0 KB/s'));
    assert.equal(t('2 · 7.3 MB/s'), '0 · 0000 MB/s');
    assert.equal(t('5%'), '000%');
    assert.equal(t('18:42'), '00:00');
});
