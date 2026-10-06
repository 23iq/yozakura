// Keybind action catalog generator (tools/schema/bind_actions.cjs ->
// assets/schema/bind-actions.json, read by backend/pkg/binds).
const test = require('node:test');
const assert = require('node:assert');
const fs = require('node:fs');
const path = require('node:path');
const { build, FILE } = require('../tools/schema/bind_actions.cjs');

const repo = path.join(__dirname, '..');

test('every action has an id, a group and an English label', () => {
    const cat = build(repo);
    assert.ok(cat.actions.length > 40);
    const groups = new Set(cat.groups.map(g => g.id));
    for (const a of cat.actions) {
        assert.ok(a.id, 'id');
        assert.ok(groups.has(a.group), `${a.id}: group ${a.group}`);
        assert.ok(a.labels.en, `${a.id}: English label`);
        assert.strictEqual(typeof a.dispatcher, 'string');
    }
});

test('labels come from every translation, fields carry defaults', () => {
    const cat = build(repo);
    const close = cat.actions.find(a => a.id === 'window.close');
    assert.ok(close.labels.ru && close.labels.ru !== close.labels.en, 'Russian label');
    const sw = cat.actions.find(a => a.id === 'workspace.switch');
    assert.deepStrictEqual(sw.args.map(f => [f.key, f.default]), [['index', '1']]);
    assert.strictEqual(sw.argument, undefined, 'argumentBuilder actions have no static argument');
    const launch = cat.actions.find(a => a.id === 'apps.launch');
    assert.strictEqual(launch.args[0].kind, 'app');
});

test('core binds point at catalog actions', () => {
    const cat = build(repo);
    const ids = new Set(cat.actions.map(a => a.id));
    assert.ok(cat.core.length > 10);
    for (const b of cat.core) {
        assert.ok(ids.has(b.action), `${b.path}: ${b.action}`);
        assert.ok(b.key && Array.isArray(b.modifiers), b.path);
    }
    assert.ok(cat.core.some(b => b.path === 'system.lockscreen' && b.action === 'system.lock'));
});

test('the committed catalog is fresh', () => {
    const disk = fs.readFileSync(path.join(repo, 'assets/schema', FILE), 'utf8');
    assert.strictEqual(disk, JSON.stringify(build(repo), null, 2) + '\n', 'run `make schema`');
});
