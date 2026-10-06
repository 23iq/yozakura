const { test } = require('node:test');
const assert = require('node:assert/strict');
const path = require('node:path');
const qmljs = require('./lib/qmljs.cjs');

const loadLibrary = file => qmljs.loadLibrary(path.join(__dirname, file));
const P = loadLibrary('../modules/notifications/NotificationPolicy.js');
const defaults = JSON.parse(JSON.stringify(loadLibrary('../config/defaults/notifications.js').data));
const plain = v => JSON.parse(JSON.stringify(v));

// 2026-10-05 is a Monday
const at = (day, hh, mm) => new Date(2026, 9, 4 + day, hh, mm);

const PanelStyles = loadLibrary('../modules/bar/panels/PanelStyles.js');

test('every presentation style mapping names a real panel style', () => {
    const ids = PanelStyles.STYLES.map(st => st.id);
    for (const style of Object.keys(P.STYLE_PRESENTATION)) assert.ok(ids.includes(style), style);
});

test('defaults are valid policy values', () => {
    assert.ok(P.PRESENTATIONS.includes(defaults.presentation));
    assert.ok(P.POSITIONS.includes(defaults.position));
    assert.equal(P.parseTime(defaults.dnd.schedule.from) >= 0, true);
    assert.equal(P.parseTime(defaults.dnd.schedule.to) >= 0, true);
    assert.deepEqual(defaults.rules, []);
});

test('presentation: explicit wins, auto follows the bar style', () => {
    assert.equal(P.resolvePresentation('corner', { barStyle: 'islands' }), 'corner');
    assert.equal(P.resolvePresentation('notch', { barStyle: 'statusline' }), 'notch');
    assert.equal(P.resolvePresentation('auto', { barStyle: 'islands', barPosition: 'bottom', notchPosition: 'top' }), 'notch');
    assert.equal(P.resolvePresentation('auto', { barStyle: 'statusline' }), 'corner');
    assert.equal(P.resolvePresentation('auto', { barStyle: 'menubar', barPosition: 'top', notchPosition: 'top' }), 'corner');
    assert.equal(P.resolvePresentation('auto', { barStyle: 'corners' }), 'notch');
    assert.equal(P.resolvePresentation('auto', { barStyle: '', barPosition: 'top', notchPosition: 'top' }), 'notch', 'no panel (notch only)');
    // classic: notch when it sits on the bar's edge, corner for a bottom taskbar
    assert.equal(P.resolvePresentation('auto', { barStyle: 'classic', barPosition: 'top', notchPosition: 'top' }), 'notch');
    assert.equal(P.resolvePresentation('auto', { barStyle: 'classic', barPosition: 'bottom', notchPosition: 'top' }), 'corner');
    assert.equal(P.resolvePresentation('auto', { barStyle: 'classic', barPosition: 'left', notchPosition: 'top' }), 'corner');
    assert.equal(P.resolvePresentation('bogus', {}), 'notch', 'unknown value behaves like auto');
});

test('corner position and anchors', () => {
    assert.equal(P.resolvePosition('auto', { barPosition: 'bottom' }), 'bottom-right');
    assert.equal(P.resolvePosition('auto', { barPosition: 'top' }), 'top-right');
    assert.equal(P.resolvePosition('top-left', { barPosition: 'bottom' }), 'top-left');
    assert.deepEqual(plain(P.anchorsOf('bottom-left')), { vertical: 'bottom', horizontal: 'left' });
    assert.deepEqual(plain(P.anchorsOf('top')), { vertical: 'top', horizontal: 'center' });
});

test('screens filter: empty = every screen', () => {
    assert.equal(P.showsOnScreen([], 'DP-1'), true);
    assert.equal(P.showsOnScreen(['HDMI-A-1'], 'DP-1'), false);
    assert.equal(P.showsOnScreen(['HDMI-A-1'], 'HDMI-A-1'), true);
});

test('rules match app name or desktop entry, case-insensitive, with wildcards', () => {
    const n = { appName: 'Discord', desktopEntry: 'vesktop.desktop' };
    assert.equal(P.ruleMatches('discord', n), true);
    assert.equal(P.ruleMatches('VESKTOP', n), true);
    assert.equal(P.ruleMatches('disc', n), false, 'no accidental substring matches');
    assert.equal(P.ruleMatches('*cord', n), true);
    assert.equal(P.ruleMatches('', n), false);
    const flags = plain(P.matchRules([{ app: 'discord', action: 'mute' }, { app: 'vesktop', action: 'soundOff' }, { app: 'x', action: 'priority' }, { app: 'discord', action: 'bogus' }], n));
    assert.deepEqual(flags, { mute: true, priority: false, alwaysShow: false, soundOff: true });
});

test('DND schedule windows, including past midnight', () => {
    const s = { enabled: true, from: '22:00', to: '07:00', days: [1, 2, 3, 4, 5] }; // starts Mon-Fri
    assert.equal(P.inSchedule(s, at(1, 23, 0)), true, 'Monday night');
    assert.equal(P.inSchedule(s, at(2, 6, 59)), true, 'Tuesday morning continues Monday window');
    assert.equal(P.inSchedule(s, at(2, 7, 0)), false, 'ends at 07:00');
    assert.equal(P.inSchedule(s, at(1, 6, 0)), false, 'Monday morning: Sunday window not enabled');
    assert.equal(P.inSchedule(s, at(6, 23, 0)), false, 'Saturday night not scheduled');
    assert.equal(P.inSchedule(s, at(6, 3, 0)), true, 'Saturday early morning continues Friday');
    const day = { enabled: true, from: '09:00', to: '17:30', days: [0, 1, 2, 3, 4, 5, 6] };
    assert.equal(P.inSchedule(day, at(3, 12, 0)), true);
    assert.equal(P.inSchedule(day, at(3, 17, 30)), false);
    assert.equal(P.inSchedule({ ...day, enabled: false }, at(3, 12, 0)), false);
    assert.equal(P.inSchedule({ ...day, from: '9am' }, at(3, 12, 0)), false, 'malformed time never matches');
    assert.equal(P.inSchedule({ enabled: true, from: '00:00', to: '00:00', days: [3] }, at(3, 15, 0)), true, 'from == to is all day');
    assert.equal(P.dndActive({ dnd: { enabled: true } }, at(3, 12, 0)), true);
    assert.equal(P.parseTime('24:00'), -1);
    assert.equal(P.parseTime('7:05'), 425);
});

test('decide: popups, DND bypass, sound and timeouts', () => {
    const cfg = { timeout: 5000, rules: [{ app: 'spam', action: 'mute' }, { app: 'pager', action: 'priority' }, { app: 'family', action: 'alwaysShow' }, { app: 'radio', action: 'soundOff' }], sound: { enabled: true }, dnd: { allowCritical: true } };
    const d = (n, dnd) => plain(P.decide(cfg, n, dnd));
    assert.deepEqual(d({ appName: 'app', expireTimeout: -1 }, false), { popup: true, sound: true, priority: false, timeout: 5000 });
    assert.equal(d({ appName: 'app', expireTimeout: 12000 }, false).timeout, 12000, 'app timeout wins');
    assert.equal(d({ appName: 'app', expireTimeout: 0 }, false).timeout, 0, 'app asks for a persistent toast');
    assert.deepEqual(d({ appName: 'spam' }, false), { popup: false, sound: false, priority: false, timeout: 5000 });
    assert.equal(d({ appName: 'app' }, true).popup, false, 'DND hides');
    assert.equal(d({ appName: 'app', urgency: 2 }, true).popup, true, 'critical passes DND');
    assert.equal(d({ appName: 'app', urgency: 'critical' }, true).popup, true);
    assert.equal(plain(P.decide({ ...cfg, dnd: { allowCritical: false } }, { appName: 'app', urgency: 2 }, true)).popup, false);
    assert.deepEqual(d({ appName: 'pager' }, true), { popup: true, sound: true, priority: true, timeout: 0 });
    assert.equal(d({ appName: 'family' }, true).popup, true);
    assert.equal(d({ appName: 'radio' }, false).sound, false);
    assert.equal(plain(P.decide({ ...cfg, sound: { enabled: false } }, { appName: 'app' }, false)).sound, false);
});

test('grouping key, visible limit and history trim', () => {
    assert.equal(P.groupKey({ appName: 'a', id: 3 }, true), 'a');
    assert.equal(P.groupKey({ appName: 'a', id: 3 }, false), 'a#3');
    const popups = [{ id: 1, time: 1 }, { id: 2, time: 2, historyPriority: 1 }, { id: 3, time: 3 }, { id: 4, time: 4 }];
    assert.deepEqual(plain(P.overflowPopups(popups, 2)), [1, 3], 'oldest normal popups go first');
    assert.deepEqual(plain(P.overflowPopups(popups, 10)), []);
    const list = [{ id: 1, time: 1 }, { id: 2, time: 2, popup: true }, { id: 3, time: 3 }, { id: 4, time: 4 }];
    assert.deepEqual(plain(P.trimHistory(list, 2)), [1, 3], 'visible popups are never dropped');
    assert.deepEqual(plain(P.trimHistory(list, 0)), [1, 3, 4]);
    assert.deepEqual(plain(P.trimHistory(list, 100)), []);
});

test('soundRequest: suppress-sound, sound-name, sound-file, none', () => {
    const r = h => plain(P.soundRequest(h));
    assert.equal(P.soundRequest({ 'suppress-sound': true }), null);
    assert.equal(P.soundRequest({ 'suppress-sound': 1, 'sound-file': '/a.wav' }), null);
    assert.equal(P.soundRequest({ 'suppress-sound': 'true' }), null);
    assert.deepEqual(r({ 'suppress-sound': false }), {});
    assert.deepEqual(r({ 'sound-name': 'message-new-instant' }), { name: 'message-new-instant' });
    assert.deepEqual(r({ 'sound-name': 'x; rm -rf ~' }), {});
    assert.deepEqual(r({ 'sound-file': '/usr/share/sounds/a.oga' }), { file: '/usr/share/sounds/a.oga' });
    assert.deepEqual(r({ 'sound-file': 'file:///home/u/My%20Tone.ogg' }), { file: '/home/u/My Tone.ogg' });
    assert.deepEqual(r({ 'sound-file': 'relative.wav' }), {});
    assert.deepEqual(r({ 'sound-name': 'bell', 'sound-file': '/a.wav' }), { name: 'bell' });
    assert.deepEqual(r(undefined), {});
    assert.deepEqual(r({}), {});
});
