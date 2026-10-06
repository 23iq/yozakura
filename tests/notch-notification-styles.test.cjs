const { test } = require('node:test');
const assert = require('node:assert/strict');
const path = require('node:path');
const { loadLibrary } = require('./lib/qmljs.cjs');
const B = loadLibrary(path.join(__dirname, '../modules/notch/NotificationBody.js'));
const S = loadLibrary(path.join(__dirname, '../modules/notch/NotchNotificationStyles.js'));
const E = loadLibrary(path.join(__dirname, '../config/meta/notifications.js'));

test('notchStyle resolves card/compact and falls back to card', () => {
    assert.equal(S.resolve('compact'), 'compact');
    assert.equal(S.resolve('card'), 'card');
    assert.equal(S.resolve('pill'), 'card');
    assert.equal(S.resolve(undefined), 'card');
    assert.equal(S.isCompact('compact'), true);
    assert.equal(S.isCompact('card'), false);
});
test('the settings enum matches the registry', () => {
    assert.deepEqual([...E.keys.notchStyle.enum], [...S.STYLES]);
});
test('chromium link paragraphs are dropped, line breaks kept', () => {
    assert.equal(B.clean('<a href="x">site</a>\n\nHello\nthere', 'Brave'), 'Hello\nthere');
    assert.equal(B.clean('<a href="x">site</a>\n\nHello', 'Firefox'), '<a href="x">site</a>\n\nHello');
    assert.equal(B.clean('', 'Chrome'), '');
    assert.equal(B.clean(null), '');
});
test('compact text is one line: summary · body, tags and whitespace folded', () => {
    assert.equal(B.oneLine('New  mail', 'From <b>Ann</b>\n\nHi!', 'Mail'), 'New mail · From Ann Hi!');
    assert.equal(B.oneLine('Only summary', '', ''), 'Only summary');
    assert.equal(B.oneLine('', 'Only body', ''), 'Only body');
    assert.equal(B.oneLine('', '', ''), '');
});
