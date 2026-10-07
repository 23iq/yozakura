const { test } = require('node:test');
const assert = require('node:assert/strict');
const path = require('node:path');
const qmljs = require('./lib/qmljs.cjs');

const m = qmljs.loadLibrary(path.join(__dirname, '../modules/widgets/dashboard/home/HomeModel.js'));
const plain = value => JSON.parse(JSON.stringify(value));
const more = n => n + ' more';

test('formatTime: m:ss, h:mm:ss, junk is 0:00', () => {
    assert.equal(m.formatTime(0), '0:00');
    assert.equal(m.formatTime(104.9), '1:44');
    assert.equal(m.formatTime(3723), '1:02:03');
    assert.equal(m.formatTime(-5), '0:00');
    assert.equal(m.formatTime(undefined), '0:00');
});

test('artistLine skips empty parts', () => {
    assert.equal(m.artistLine('M83', 'Hurry Up'), 'M83 · Hurry Up');
    assert.equal(m.artistLine('M83', ''), 'M83');
    assert.equal(m.artistLine('', ' '), '');
});

test('plainLine strips markup and collapses whitespace', () => {
    assert.equal(m.plainLine('<b>Hi</b>\n  there '), 'Hi there');
    assert.equal(m.plainLine(null), '');
});

test('connectedDevice finds the first connected one', () => {
    assert.equal(m.connectedDevice([{ name: 'A', connected: false }, { name: 'Buds', connected: true }]), 'Buds');
    assert.equal(m.connectedDevice([]), '');
    assert.equal(m.connectedDevice(null), '');
});

test('groupRow: one notification shows summary and body', () => {
    const g = { appName: 'chat', notifications: [{ appName: 'chat', summary: 'Ann', body: 'see <i>you</i>', appIcon: 'chat', image: '' }] };
    assert.deepEqual(plain(m.groupRow(g, more)), { title: 'Ann', body: 'see you', app: 'chat', icon: 'chat', image: '' });
});

test('groupRow: several show the app name and "latest · N more"', () => {
    const n = { appName: 'notify-send', summary: 'test', body: '1', appIcon: '', image: '' };
    const row = m.groupRow({ appName: 'notify-send', notifications: [n, n, n] }, more);
    assert.equal(row.title, 'notify-send');
    assert.equal(row.body, 'test · 2 more');
});

test('groupRow: cached icon and image win; empty group is safe', () => {
    const n = { summary: 's', body: '', appIcon: 'a', cachedAppIcon: '/c/a.png', image: 'x', cachedImage: '/c/x.png' };
    const row = m.groupRow({ appName: 'app', notifications: [n] }, more);
    assert.equal(row.icon, '/c/a.png');
    assert.equal(row.image, '/c/x.png');
    assert.equal(m.groupRow(null, more).title, '');
    assert.equal(m.groupRow({ appName: 'x', notifications: [] }, more).title, 'x');
});

test('avatarSource: image, then themed icon, absolute paths as file URLs', () => {
    assert.equal(m.avatarSource({ image: '/c/x.png', icon: 'a' }), 'file:///c/x.png');
    assert.equal(m.avatarSource({ image: 'file:///x.png', icon: '' }), 'file:///x.png');
    assert.equal(m.avatarSource({ image: '', icon: 'firefox' }), 'image://icon/firefox');
    assert.equal(m.avatarSource({ image: '', icon: 'file:///i.svg' }), 'file:///i.svg');
    assert.equal(m.avatarSource({ image: '', icon: '' }), '');
});

test('chipLabels: all labels when the row fits', () => {
    assert.deepEqual(plain(m.chipLabels([100, 90, 80], [40, 40, 40], [true, false, false], 300, 8)), [true, true, true]);
});

test('chipLabels: inactive chips go icon-only together, active keep labels', () => {
    // 106 + 100 + 99 + 92 + 87 + 4*8 = 516 > 420
    const full = [106, 100, 99, 92, 87];
    const compact = [41, 41, 41, 41, 41];
    assert.deepEqual(plain(m.chipLabels(full, compact, [true, true, false, false, false], 420, 8)),
        [true, true, false, false, false]);
});

test('chipLabels: then active chips from the last back, only as needed', () => {
    const full = [150, 150, 99];
    const compact = [41, 41, 41];
    // inactive dropped: 150 + 150 + 41 + 16 = 357 > 300 -> drop the 2nd active (248)
    assert.deepEqual(plain(m.chipLabels(full, compact, [true, true, false], 300, 8)), [true, false, false]);
    assert.deepEqual(plain(m.chipLabels(full, compact, [true, true, false], 100, 8)), [false, false, false]);
    assert.deepEqual(plain(m.chipLabels([], [], [], 100, 8)), []);
});
