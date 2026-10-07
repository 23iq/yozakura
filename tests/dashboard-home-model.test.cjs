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

test('groupRow: one line "summary · body", a count and the ids', () => {
    const g = { appName: 'chat', notifications: [
        { id: 1, appName: 'chat', summary: 'Bob', body: 'old', appIcon: 'chat', image: '' },
        { id: 2, appName: 'chat', summary: 'Ann', body: 'see <i>you</i>', appIcon: 'chat', image: '' }] };
    assert.deepEqual(plain(m.groupRow(g)), { text: 'Ann · see you', count: 2, app: 'chat', icon: 'chat', image: '', ids: [1, 2] });
});

test('groupRow: whichever of summary / body is set, else the app', () => {
    const one = n => m.groupRow({ appName: 'app', notifications: [n] }).text;
    assert.equal(one({ summary: 'Done', body: '' }), 'Done');
    assert.equal(one({ summary: '', body: 'only body' }), 'only body');
    assert.equal(one({ appName: 'x', summary: '', body: '' }), 'x');
});

test('groupRow: cached icon and image win; empty group is safe', () => {
    const n = { summary: 's', body: '', appIcon: 'a', cachedAppIcon: '/c/a.png', image: 'x', cachedImage: '/c/x.png' };
    const row = m.groupRow({ appName: 'app', notifications: [n] });
    assert.equal(row.icon, '/c/a.png');
    assert.equal(row.image, '/c/x.png');
    assert.equal(m.groupRow(null).text, '');
    assert.deepEqual(plain(m.groupRow({ appName: 'x', notifications: [] })), { text: 'x', count: 0, app: 'x', icon: '', image: '', ids: [] });
});

test('avatarSource: the app icon first, then the image; paths as file URLs', () => {
    assert.equal(m.avatarSource({ image: '/c/x.png', icon: 'firefox' }), 'image://icon/firefox');
    assert.equal(m.avatarSource({ image: '/c/x.png', icon: '' }), 'file:///c/x.png');
    assert.equal(m.avatarSource({ image: 'file:///x.png', icon: '' }), 'file:///x.png');
    assert.equal(m.avatarSource({ image: '', icon: 'file:///i.svg' }), 'file:///i.svg');
    assert.equal(m.avatarSource({ image: '', icon: '' }), '');
});

test('meterLevel: peak amplitude on a -60..0 dB scale', () => {
    assert.equal(m.meterLevel(0), 0);
    assert.equal(m.meterLevel(undefined), 0);
    assert.equal(m.meterLevel(1), 1);
    assert.equal(m.meterLevel(2), 1);
    assert.ok(Math.abs(m.meterLevel(0.25) - 0.8) < 0.01);
    assert.ok(Math.abs(m.meterLevel(0.01) - 1 / 3) < 0.01);
});
