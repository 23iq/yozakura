// Free-form config maps ("var" in config/meta/AdapterTypes.js) keep the
// user's keys through the first-load validation (config/ConfigValidator.js
// validateDomain, called by config/ConfigFile.qml). Keys the defaults know
// are still validated as before.
const { test } = require('node:test');
const assert = require('node:assert/strict');
const path = require('node:path');
const { loadLibrary } = require('./lib/qmljs.cjs');

const ROOT = path.join(__dirname, '..');
const lib = file => loadLibrary(path.join(ROOT, file));
const plain = value => JSON.parse(JSON.stringify(value));

const validator = lib('config/ConfigValidator.js');
const JsonUtil = lib('config/JsonUtil.js');
const compositorDefaults = plain(lib('config/defaults/compositor.js').data);
const barDefaults = plain(lib('config/defaults/bar.js').data);
const notchDefaults = plain(lib('config/defaults/notch.js').data);

const overrides = { windows: { curve: 'snappy', speed: 3 }, workspaces: { style: 'fade' } };

test('compositor.motionOverrides keeps its entries', () => {
    const user = Object.assign(plain(compositorDefaults), { motionOverrides: overrides });
    const out = plain(validator.validateDomain(user, compositorDefaults, 'compositor'));
    assert.deepEqual(out.motionOverrides, overrides);
    // Nothing changed, so ConfigFile does not rewrite the file.
    assert.ok(JsonUtil.deepEqual(user, out));
});

test('extra bar.moduleOptions keys survive, known ones are still validated', () => {
    const user = plain(barDefaults);
    user.moduleOptions.myModule = { size: 3 };
    user.moduleOptions.clock.extraFlag = true;
    user.moduleOptions.clock.showWeather = 'yes';  // wrong type: default as before
    const out = plain(validator.validateDomain(user, barDefaults, 'bar'));
    assert.deepEqual(out.moduleOptions.myModule, { size: 3 });
    assert.equal(out.moduleOptions.clock.extraFlag, true);
    assert.equal(out.moduleOptions.clock.showWeather, barDefaults.moduleOptions.clock.showWeather);
});

test('keys outside free-form paths are still dropped', () => {
    const user = Object.assign(plain(barDefaults), { notAKey: 1 });
    const out = plain(validator.validateDomain(user, barDefaults, 'bar'));
    assert.equal('notAKey' in out, false);
    const comp = Object.assign(plain(compositorDefaults), { bogus: true });
    assert.equal('bogus' in plain(validator.validateDomain(comp, compositorDefaults, 'compositor')), false);
});

test('a free-form path with the wrong shape falls back to the default', () => {
    const user = Object.assign(plain(compositorDefaults), { motionOverrides: 'nope' });
    assert.deepEqual(plain(validator.validateDomain(user, compositorDefaults, 'compositor')).motionOverrides, {});
    const arr = Object.assign(plain(compositorDefaults), { motionOverrides: [1] });
    assert.deepEqual(plain(validator.validateDomain(arr, compositorDefaults, 'compositor')).motionOverrides, {});
});

test('known keys inside a free-form map keep their checks (notch.liveActivities)', () => {
    const user = plain(notchDefaults);
    user.liveActivities.maxVisible = 40;
    user.liveActivities.presentation = 'bogus';
    user.liveActivities.sources.myProvider = false;
    const out = plain(validator.validateDomain(user, notchDefaults, 'notch'));
    assert.equal(out.liveActivities.maxVisible, 8);
    assert.equal(out.liveActivities.presentation, 'notch');
    assert.equal(out.liveActivities.sources.myProvider, false);
});

test('a domain without free-form paths validates exactly like validate()', () => {
    const user = Object.assign(plain(barDefaults), { notAKey: 1 });
    assert.deepEqual(plain(validator.validateDomain(user, barDefaults, 'nosuchdomain')),
        plain(validator.validate(user, barDefaults)));
    assert.deepEqual(plain(validator.validateDomain(undefined, compositorDefaults, 'compositor')), compositorDefaults);
});

// Keys named like Object.prototype members are ordinary user keys inside a
// free-form map; "__proto__" is never copied (assigning it would replace
// the prototype of the validated map).
test('prototype-named keys in a free-form map are kept, __proto__ is dropped', () => {
    const user = plain(compositorDefaults);
    user.motionOverrides = JSON.parse('{"constructor": {"curve": "snappy"}, "toString": {"speed": 2},'
        + ' "hasOwnProperty": {"style": "fade"}, "__proto__": {"evil": true}, "windows": {"speed": 3}}');
    const raw = validator.validateDomain(user, compositorDefaults, 'compositor').motionOverrides;
    assert.equal('evil' in raw, false, 'the prototype was not replaced');
    assert.equal(Object.prototype.hasOwnProperty.call(raw, '__proto__'), false, '__proto__ is not copied');
    assert.deepEqual(plain(raw), {
        constructor: { curve: 'snappy' }, toString: { speed: 2 }, hasOwnProperty: { style: 'fade' }, windows: { speed: 3 }
    });
});

test('overlay copies prototype-named keys and never __proto__', () => {
    const over = JSON.parse('{"constructor": 1, "toString": {"a": 1}, "__proto__": {"evil": true}, "x": {"y": 2}}');
    const out = validator.overlay({ x: { z: 1 } }, over);
    assert.equal('evil' in out, false);
    assert.equal(Object.prototype.hasOwnProperty.call(out, '__proto__'), false);
    assert.deepEqual(plain(out), { x: { z: 1, y: 2 }, constructor: 1, toString: { a: 1 } });
});
