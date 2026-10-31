// Settings rows gated by what really applies: the bar pin (auto-hide
// "auto" panels only), corner-toast position with the notch off, the notch
// toast style. Condition `some` (modules/settings/SchemaUtil.js).
const { test } = require('node:test');
const assert = require('node:assert/strict');
const path = require('node:path');
const { loadLibrary } = require('./lib/qmljs.cjs');

const repo = path.join(__dirname, '..');
const lib = rel => loadLibrary(path.join(repo, rel));
const SchemaUtil = lib('modules/settings/SchemaUtil.js');
const Defaults = lib('modules/settings/SettingsDefaults.js');
const Categories = lib('modules/settings/schema/Categories.js');
const Reason = lib('modules/settings/DisabledReason.js');

const entry = key => SchemaUtil.flatten(Categories.categories).map(x => x.entry).find(e => e.key === key);
const getter = over => k => (k in over ? over[k] : Defaults.get(k));

test('some: a list holds an item whose field is (not) one of the values', () => {
    const cond = { key: 'l', some: { field: 'a', notIn: ['x', true] } };
    assert.equal(SchemaUtil.evalCondition(cond, () => [{ a: 'x' }, { a: true }]), false);
    assert.equal(SchemaUtil.evalCondition(cond, () => [{ a: 'x' }, {}]), true, 'a missing field is not in the list');
    assert.equal(SchemaUtil.evalCondition(cond, () => []), false);
    assert.equal(SchemaUtil.evalCondition({ key: 'l', some: { field: 'a', in: ['y'] } }, () => [{ a: 'y' }]), true);
});

test('the bar pin applies only while some panel auto-hides on "auto"', () => {
    for (const key of ['bar.pinnedOnStartup', 'bar.showPinButton']) {
        const e = entry(key);
        assert.equal(SchemaUtil.evalCondition(e.enabledWhen, getter({})), true, `${key}: single bar`);
        assert.equal(SchemaUtil.evalCondition(e.enabledWhen, getter({ 'bar.panels': [{ autohide: 'never' }, { autohide: 'always' }] })), false, key);
        assert.equal(SchemaUtil.evalCondition(e.enabledWhen, getter({ 'bar.panels': [{ autohide: 'never' }, { edge: 'left' }] })), true, key);
        const note = Reason.explain(e, getter({ 'bar.panels': [{ autohide: false }] }), () => null, k => k);
        assert.equal(note.text, 'prefs.bar.pin.reason');
    }
});

test('corner position shows while toasts really go to the corner', () => {
    const e = entry('notifications.position');
    const on = over => SchemaUtil.evalCondition(e.visibleWhen, getter(over));
    assert.equal(on({ 'notifications.presentation': 'corner' }), true);
    assert.equal(on({ 'notifications.presentation': 'notch', 'notch.enabled': true }), false);
    assert.equal(on({ 'notifications.presentation': 'notch', 'notch.enabled': false }), true);
    assert.equal(on({ 'notifications.presentation': 'strips' }), false);
});

test('the notch toast style is hidden for corner / strips and greyed with the notch off', () => {
    const e = entry('notifications.notchStyle');
    assert.equal(SchemaUtil.evalCondition(e.visibleWhen, getter({ 'notifications.presentation': 'strips' })), false);
    assert.equal(SchemaUtil.evalCondition(e.visibleWhen, getter({ 'notifications.presentation': 'auto' })), true);
    assert.equal(SchemaUtil.evalCondition(e.enabledWhen, getter({ 'notch.enabled': false })), false);
});
