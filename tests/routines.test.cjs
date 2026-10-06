const assert = require('node:assert/strict');
const { test } = require('node:test');
const { loadLibrary } = require('./lib/qmljs.cjs');
const R = loadLibrary('modules/routines/RoutineModel.js');
const Slots = loadLibrary('modules/keybinds/RoutineSlots.js');
const Auto = loadLibrary('modules/services/ai/Automations.js');

const plain = v => JSON.parse(JSON.stringify(v));

test('step edits return new routines', () => {
    const r0 = R.newRoutine('Morning');
    const r1 = R.withStep(r0, R.newStep('delay'));
    const r2 = R.withStep(r1, R.newStep('tool'));
    assert.equal(r0.steps.length, 0, 'the original is untouched');
    assert.deepEqual(plain(r2.steps.map(s => s.kind)), ['delay', 'tool']);
    const r3 = R.withMovedStep(r2, 1, -1);
    assert.deepEqual(plain(r3.steps.map(s => s.kind)), ['tool', 'delay']);
    assert.deepEqual(plain(R.withMovedStep(r3, 0, -1)), plain(r3), 'out of range is a no-op');
    const r4 = R.withStepPatch(r3, 1, { ms: 2500 });
    assert.equal(r4.steps[1].ms, 2500);
    assert.equal(r3.steps[1].ms, 1000);
    assert.equal(R.withoutStep(r4, 0).steps.length, 1);
});

test('problems point at the step to fix', () => {
    assert.deepEqual(plain(R.problems(R.newRoutine(' '))), [{ index: -1, key: 'routines.problem.name' }]);
    const bad = { name: 'x', steps: [{ kind: 'action', action: '' }, { kind: 'tool', tool: 'routine_run' }, { kind: 'delay', ms: 0 }, { kind: 'tool', tool: '' }, { kind: 'nap' }] };
    assert.deepEqual(plain(R.problems(bad)).map(p => p.key), ['routines.problem.action', 'routines.problem.blocked', 'routines.problem.delay', 'routines.problem.tool', 'routines.problem.kind']);
    assert.deepEqual(plain(R.problems(R.fromTemplate('night', k => k))), []);
});

test('templates and args round trip', () => {
    const t = R.fromTemplate('focus', k => 'T:' + k);
    assert.equal(t.name, 'T:routines.template.focus');
    assert.equal(t.icon, 'brain');
    t.steps[0].args.minutes = 1;
    assert.equal(R.TEMPLATES[0].steps[0].args.minutes, 50, 'templates are copied');
    assert.equal(R.argsText({}), '');
    assert.equal(R.argsText({ enabled: true }), '{"enabled":true}');
    assert.deepEqual(plain(R.parseArgs('')), { ok: true, value: {} });
    assert.deepEqual(plain(R.parseArgs('{"a":1}')), { ok: true, value: { a: 1 } });
    assert.equal(R.parseArgs('[1]').ok, false);
    assert.equal(R.parseArgs('{oops').ok, false);
    assert.equal(R.delayText(500), '500 ms');
    assert.equal(R.delayText(1500), '1.5 s');
    assert.equal(R.delayText(90000), '1.5 min');
});

test('launcher search ranks name prefix over keywords', () => {
    const list = [{ id: 'night', name: 'Night', keywords: 'sleep dark' }, { id: 'morning', name: 'Morning', keywords: 'coffee' },
        { id: 'deep', name: 'Deep night work', keywords: '' }];
    assert.deepEqual(plain(R.search(list, 'nig')).map(r => r.id), ['night', 'deep']);
    assert.deepEqual(plain(R.search(list, 'coffee')).map(r => r.id), ['morning']);
    assert.deepEqual(plain(R.search(list, 'zzz')), []);
    assert.equal(R.search(list, '', 2).length, 2);
});

test('run report summary', () => {
    const s = plain(R.reportSummary({ ok: false, steps: [{ index: 0, status: 'ok' }, { index: 1, status: 'failed', label: 'Tool x', error: 'boom' }, { index: 2, status: 'skipped' }] }));
    assert.deepEqual(s, { ok: false, done: 1, total: 3, failed: { index: 1, label: 'Tool x', error: 'boom' } });
    assert.deepEqual(plain(R.reportSummary(null)), { ok: false, done: 0, total: 0, failed: null });
});

test('one keybind slot per routine that nothing runs yet', () => {
    const routines = [{ id: 'morning', name: 'Morning' }, { id: 'night', name: 'Night' }];
    const bound = [{ actions: [{ id: 'utilities.routine', args: { routine: 'night' } }] }];
    const rows = plain(Slots.rows(bound, routines));
    assert.equal(rows.length, 1);
    assert.equal(rows[0].uid, 'slot:routine:morning');
    assert.equal(rows[0].kind, 'slot');
    assert.equal(rows[0].name, 'Morning');
    assert.equal(rows[0].group, 'utilities');
    assert.deepEqual(rows[0].actions[0], { id: 'utilities.routine', args: { routine: 'morning' }, layouts: [] });
    assert.deepEqual(rows[0].keys, [{ modifiers: [], key: '' }]);
    assert.deepEqual(plain(Slots.rows([], null)), []);
    assert.equal(Slots.routineOf({ id: 'utilities.routine', args: { routine: 'night' } }, routines), 'Night');
    assert.equal(Slots.routineOf({ id: 'utilities.routine', args: { routine: 'gone' } }, routines), 'gone');
    assert.equal(Slots.routineOf({ id: 'media.next' }, routines), '');
});

test('automations: the routine output needs a routine, not a prompt', () => {
    const a = plain(Auto.normalize({ id: 'a', enabled: true, trigger: { type: 'login' }, output: 'routine', routine: 'morning' }));
    assert.equal(a.output, 'routine');
    assert.equal(a.routine, 'morning');
    assert.equal(Auto.active([a], 'login').length, 1, 'no prompt needed');
    assert.equal(Auto.active([Object.assign({}, a, { routine: '' })], 'login').length, 0);
    assert.equal(Auto.active([{ id: 'b', enabled: true, trigger: { type: 'login' }, output: 'notify', prompt: '' }], 'login').length, 0);
    assert.equal(plain(Auto.normalize({ output: 'bogus' })).output, 'notify');
});
