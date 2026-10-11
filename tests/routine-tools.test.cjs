// Tool steps of the routine editor: the argument form derived from a tool's
// JSON schema, validation, new-step defaults and the step sentence
// (modules/routines/RoutineTools.js + RoutineModel.stepSummary).
const assert = require('node:assert/strict');
const { test } = require('node:test');
const { loadLibrary } = require('./lib/qmljs.cjs');
const R = loadLibrary('modules/routines/RoutineModel.js');
const T = loadLibrary('modules/routines/RoutineTools.js');

const plain = v => JSON.parse(JSON.stringify(v));
const none = () => '';

const DND = {
    name: 'dnd_set', title: 'Do Not Disturb', description: 'Silence notifications. Omit to toggle.', category: 'focus',
    summary: '{enabled|true=Turn on|false=Turn off|unset=Toggle} Do Not Disturb',
    schema: { type: 'object', properties: { enabled: { type: 'boolean' } }, additionalProperties: false },
};
const VOLUME = {
    name: 'volume_set', title: 'Set volume', description: 'Volume.', category: 'media',
    summary: '[Set volume to {percent}%][, change volume by {delta}%][, {mute|true=mute|false=unmute|toggle=toggle mute}]',
    schema: {
        type: 'object', additionalProperties: false, properties: {
            percent: { type: 'number', minimum: 0, maximum: 150 }, delta: { type: 'number', minimum: -100, maximum: 100 },
            mute: { type: ['boolean', 'string'] }, source: { type: 'boolean', default: false },
        },
    },
};
const MEDIA = {
    name: 'media_control', title: 'Control media', description: 'Media.', category: 'media',
    summary: '{action|play=Play media|next=Skip to the next track}',
    schema: { type: 'object', properties: { action: { type: 'string', enum: ['play', 'pause', 'next'] }, player: { type: 'string' } }, required: ['action'] },
};
const FOCUS = {
    name: 'focus_start', title: 'Start focus mode', description: 'Focus.', category: 'focus',
    summary: 'Start focus mode[ for {minutes} min]',
    schema: { type: 'object', properties: { minutes: { type: 'integer', minimum: 1, maximum: 480 } } },
};
const CATALOG = [DND, VOLUME, MEDIA, FOCUS];

test('fields follow the schema: enum, tri-state, switch, slider, text', () => {
    const f = Object.fromEntries(T.fields(VOLUME).map(x => [x.key, x]));
    assert.equal(f.percent.kind, 'slider');
    assert.deepEqual([f.percent.min, f.percent.max, f.percent.unit], [0, 150, '%']);
    assert.equal(f.mute.kind, 'triple', 'boolean | string is on / off / toggle');
    assert.equal(f.source.kind, 'switch', 'a boolean with a default is a plain switch');
    assert.equal(T.fields(DND)[0].kind, 'tristate', 'an optional boolean can be left out (toggle)');
    const m = T.fields(MEDIA);
    assert.equal(m[0].kind, 'enum');
    assert.deepEqual(plain(m[0].options), ['play', 'pause', 'next']);
    assert.equal(m[0].required, true);
    assert.equal(m[1].kind, 'text');
    assert.equal(T.fields(FOCUS)[0].integer, true);
    assert.equal(T.fields({ name: 'x', schema: { properties: { v: {} } } })[0].kind, 'json');
    assert.deepEqual(plain(T.fields({ name: 'x' })), []);
});

test('a new tool step starts with friendly, valid arguments', () => {
    assert.deepEqual(plain(T.newStep(DND)), { kind: 'tool', tool: 'dnd_set', args: { enabled: true } });
    assert.deepEqual(plain(R.newStep('tool', VOLUME)).args, { percent: 50 });
    assert.deepEqual(plain(R.newStep('tool', MEDIA)).args, { action: 'play-pause' }, 'listed default wins');
    assert.deepEqual(plain(T.defaultArgs({ name: 'other', schema: MEDIA.schema })), { action: 'play' }, 'required enum: first value');
    assert.deepEqual(plain(R.newStep('tool')), { kind: 'tool', tool: '', args: {} }, 'no tool yet: the picker opens');
});

test('withArg drops empty values and never mutates', () => {
    const a = { percent: 40 };
    assert.deepEqual(plain(T.withArg(a, 'mute', true)), { percent: 40, mute: true });
    assert.deepEqual(plain(T.withArg(a, 'percent', undefined)), {});
    assert.deepEqual(plain(T.withArg(a, 'percent', '')), {});
    assert.deepEqual(a, { percent: 40 });
});

test('validate: required, range, choice, type, unknown', () => {
    const codes = (tool, args) => plain(T.validate(tool, args)).map(p => p.key + ':' + p.code);
    assert.deepEqual(codes(MEDIA, {}), ['action:required']);
    assert.deepEqual(codes(MEDIA, { action: 'dance' }), ['action:enum']);
    assert.deepEqual(codes(MEDIA, { action: 'play' }), []);
    assert.deepEqual(codes(VOLUME, { percent: 200 }), ['percent:max']);
    assert.deepEqual(codes(VOLUME, { percent: -1 }), ['percent:min']);
    assert.deepEqual(codes(VOLUME, { percent: 'x' }), ['percent:type']);
    assert.deepEqual(codes(DND, { enabled: 'yes' }), ['enabled:type']);
    assert.deepEqual(codes(DND, { nope: 1 }), ['nope:unknown']);
    assert.deepEqual(codes(DND, {}), [], 'omitted optional boolean is fine');
});

test('problems checks tool arguments against the catalog', () => {
    const r = { name: 'x', steps: [{ kind: 'tool', tool: 'volume_set', args: { percent: 999 } }, { kind: 'tool', tool: 'mystery', args: { a: 1 } }] };
    assert.deepEqual(plain(R.problems(r)), [], 'without a catalog only structure is checked');
    const p = plain(R.problems(r, CATALOG));
    assert.equal(p.length, 1, 'tools outside the catalog are not blocked');
    assert.deepEqual([p[0].index, p[0].key, p[0].field, p[0].code, p[0].max], [0, 'routines.problem.args', 'percent', 'max', 150]);
});

test('summary sentences', () => {
    const s = (step, tr) => T.summary(step, CATALOG, tr || none, 'fallback');
    assert.equal(s({ tool: 'dnd_set', args: { enabled: true } }), 'Turn on Do Not Disturb');
    assert.equal(s({ tool: 'dnd_set', args: { enabled: false } }), 'Turn off Do Not Disturb');
    assert.equal(s({ tool: 'dnd_set', args: {} }), 'Toggle Do Not Disturb');
    assert.equal(s({ tool: 'volume_set', args: { percent: 40 } }), 'Set volume to 40%');
    assert.equal(s({ tool: 'volume_set', args: { percent: 40, mute: false } }), 'Set volume to 40%, unmute');
    assert.equal(s({ tool: 'volume_set', args: { mute: 'toggle' } }), 'Toggle mute');
    assert.equal(s({ tool: 'volume_set', args: {} }), 'Set volume', 'nothing to say: the title');
    assert.equal(s({ tool: 'focus_start', args: { minutes: 50 } }), 'Start focus mode for 50 min');
    assert.equal(s({ tool: 'focus_start', args: {} }), 'Start focus mode');
    assert.equal(s({ tool: 'media_control', args: { action: 'next' } }), 'Skip to the next track');
    assert.equal(s({ tool: 'nope', args: {} }), 'fallback');
    assert.equal(T.summary({ tool: 'custom_tool' }, CATALOG, none), 'Custom tool');
    const ru = k => (k === 'routines.tool.dnd_set.summary' ? '{enabled|true=Включить|false=Выключить|unset=Переключить} «Не беспокоить»' : '');
    assert.equal(s({ tool: 'dnd_set', args: { enabled: true } }, ru), 'Включить «Не беспокоить»', 'translated template wins');
});

test('alternatives and optional parts of the template language', () => {
    assert.equal(T.render('Close [{app}||{title}||the window]', {}), 'Close the window');
    assert.equal(T.render('Close [{app}||{title}||the window]', { title: 'Docs' }), 'Close Docs');
    assert.equal(T.render('Open {app}[ on workspace {workspace}]', { app: 'firefox', workspace: 2 }), 'Open firefox on workspace 2');
    assert.equal(T.render('Open {app}[ on workspace {workspace}]', { app: 'firefox' }), 'Open firefox');
});

test('stepSummary covers every step kind', () => {
    const tr = k => (k === 'routines.kind.delay' ? 'Wait' : '');
    const label = id => 'Label of ' + id;
    assert.equal(R.stepSummary({ kind: 'tool', tool: 'dnd_set', args: { enabled: true } }, CATALOG, tr, label), 'Turn on Do Not Disturb');
    assert.equal(R.stepSummary({ kind: 'tool', tool: '' }, CATALOG, tr, label), '');
    assert.equal(R.stepSummary({ kind: 'delay', ms: 2000 }, CATALOG, tr, label), 'Wait 2 s');
    assert.equal(R.stepSummary({ kind: 'action', action: 'workspace.switch', args: { index: '3' } }, CATALOG, tr, label), 'Label of workspace.switch · 3');
    assert.equal(R.stepSummary({ kind: 'action', action: 'window.close', args: {} }, CATALOG, tr, label), 'Label of window.close');
});

test('picker groups follow the backend order and filter by translated words', () => {
    const cats = ['media', 'display', 'focus'];
    assert.deepEqual(plain(T.groups(CATALOG, cats, '', none)).map(g => g.category + ':' + g.tools.map(t => t.name).join(',')),
        ['media:volume_set,media_control', 'focus:dnd_set,focus_start']);
    assert.deepEqual(plain(T.groups(CATALOG, cats, 'disturb', none)).map(g => g.category), ['focus']);
    const tr = k => (k === 'routines.tool.volume_set' ? 'Громкость' : '');
    assert.deepEqual(plain(T.groups(CATALOG, cats, 'громк', tr)).map(g => g.tools[0].name), ['volume_set']);
    assert.deepEqual(plain(T.groups(CATALOG, cats, 'zzz', none)), []);
});

test('labels fall back from tool-specific to generic to the key', () => {
    const tr = k => ({ 'routines.field.percent': 'Value', 'routines.field.volume_set.percent': 'Volume', 'routines.enum.next': 'Next' })[k] || '';
    assert.equal(T.fieldLabel('volume_set', 'percent', tr), 'Volume');
    assert.equal(T.fieldLabel('brightness_set', 'percent', tr), 'Value');
    assert.equal(T.fieldLabel('x', 'switchBind', none), 'SwitchBind');
    assert.equal(T.valueLabel('media_control', 'action', 'next', tr), 'Next');
    assert.equal(T.valueLabel('media_control', 'action', 'play-pause', tr), 'play-pause');
});
