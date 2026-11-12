const { test } = require('node:test');
const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');
const { loadLibrary } = require('./lib/qmljs.cjs');
const Permissions = loadLibrary(path.join(__dirname, '../modules/services/ai/Permissions.js'));

// Read the Go list from source so the two never drift apart.
const goSrc = fs.readFileSync(path.join(__dirname, '../backend/pkg/svc/routines/confirm.go'), 'utf8');
const block = goSrc.match(/var ConfirmTools = map\[string\]bool\{([\s\S]*?)\n\}/)[1];
const goTools = [...block.matchAll(/"([a-z_]+)":\s*true/g)].map(m => m[1]);

test('Permissions.js confirms every Go ConfirmTools entry', () => {
    assert.ok(goTools.length >= 6, `parsed ${goTools.length} Go entries`);
    for (const name of goTools)
        assert.equal(Permissions.mustConfirm({ name, server: 'yozakura' }, {}, []), true, name);
    assert.equal(Permissions.mustConfirm({ name: 'extras_install', server: 'other' }, {}, []), false);
});

// Command-capable calls: the key list and the shared cases match Go
// (routines.CommandConfigKeys / ConfirmCall).
const callsSrc = fs.readFileSync(path.join(__dirname, '../backend/pkg/svc/routines/confirm_calls.go'), 'utf8');
const keysBlock = callsSrc.match(/var CommandConfigKeys = \[\]string\{([\s\S]*?)\n\}/)[1];
const goKeys = [...keysBlock.matchAll(/"([^"]+)"/g)].map(m => m[1]);
const cases = JSON.parse(fs.readFileSync(path.join(__dirname, 'fixtures/ai-confirm-calls.json'), 'utf8'));

test('Permissions.js command config keys equal the Go list', () => {
    assert.ok(goKeys.length >= 6, `parsed ${goKeys.length} Go keys`);
    assert.deepEqual([...Permissions.COMMAND_CONFIG_KEYS], goKeys);
});

test('command-capable calls always ask, harmless ones follow the policy', () => {
    assert.ok(cases.length >= 20);
    for (const c of cases) {
        const tool = { name: c.tool, server: 'yozakura' };
        assert.equal(Permissions.mustConfirm(tool, c.args, []), c.confirm, `${c.tool} ${JSON.stringify(c.args)}`);
        const yolo = Permissions.decide(Object.assign({ args: c.args }, tool), { yolo: true });
        assert.equal(yolo, c.confirm ? 'ask' : 'allow', `yolo ${c.tool} ${JSON.stringify(c.args)}`);
    }
    assert.equal(Permissions.mustConfirm({ name: 'config_set', server: 'other' }, { key: 'general.terminalCommand', value: 'x' }, []), false);
});

test('a routine step that writes a command asks', () => {
    const steps = [{ kind: 'tool', tool: 'config_set', args: { key: 'system.idle.listeners', value: [] } }];
    assert.deepEqual([...Permissions.routineConfirmSteps(steps, [])], ['config_set']);
    const harmless = [{ kind: 'tool', tool: 'config_set', args: { key: 'bar.position', value: 'top' } }];
    assert.deepEqual([...Permissions.routineConfirmSteps(harmless, [])], []);
    assert.equal(Permissions.mustConfirm({ name: 'routine_save', server: 'yozakura' }, { steps }, []), true);
});
