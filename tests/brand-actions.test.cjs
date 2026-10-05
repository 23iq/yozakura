const test = require('node:test');
const assert = require('node:assert');
const { loadLibrary } = require('./lib/qmljs.cjs');

const brand = loadLibrary('modules/globals/BrandActions.js');
const actions = loadLibrary('config/KeybindActions.js');

test('legacy action ids dispatch', () => {
    assert.strictEqual(brand.normalizeAction('ambxst.launcher'), 'yozakura.launcher');
    assert.strictEqual(brand.normalizeAction('yozakura.dashboard'), 'yozakura.dashboard');
    assert.strictEqual(brand.normalizeAction('custom.thing'), 'custom.thing');
});

test('legacy ids resolve to catalog entries', () => {
    const spec = actions.getActionById('ambxst.launcher');
    assert.ok(spec, 'legacy launcher id must resolve');
    assert.strictEqual(spec.id, 'yozakura.launcher');
    const resolved = actions.resolveAction({ id: 'ambxst.dashboard', args: {} });
    assert.strictEqual(resolved.argument, 'yozakura run dashboard');
});

test('legacy CLI commands map back to actions', () => {
    assert.strictEqual(actions.actionFromLegacy('exec', 'ambxst brightness +5', '').id, 'brightness.up');
    assert.strictEqual(actions.actionFromLegacy('exec', 'yozakura brightness -5', '').id, 'brightness.down');
});
