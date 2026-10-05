const { test } = require('node:test');
const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');
const qmljs = require('./lib/qmljs.cjs');

const loadLibrary = file => qmljs.loadLibrary(path.join(__dirname, file));
const model = loadLibrary('../modules/services/voice/VoiceModel.js');
const validator = loadLibrary('../config/ConfigValidator.js');
const defaults = JSON.parse(JSON.stringify(loadLibrary('../config/defaults/voice.js').data));
const plain = v => JSON.parse(JSON.stringify(v));

test('elapsed timer and language badge', () => {
    assert.equal(model.formatElapsed(0), '0:00');
    assert.equal(model.formatElapsed(7400), '0:07');
    assert.equal(model.formatElapsed(65000), '1:05');
    assert.equal(model.formatElapsed(-5), '0:00');
    assert.equal(model.languageBadge('auto'), 'AUTO');
    assert.equal(model.languageBadge(''), 'AUTO');
    assert.equal(model.languageBadge('ru'), 'RU');
});

test('status keys per state, target and error', () => {
    assert.equal(model.statusKey({ state: 'listening', target: 'ai' }), 'voice.status.listening');
    assert.equal(model.statusKey({ state: 'listening', target: 'dictation' }), 'voice.status.dictating');
    assert.equal(model.statusKey({ state: 'transcribing' }), 'voice.status.transcribing');
    assert.equal(model.statusKey({ state: 'empty' }), 'voice.status.no_speech');
    assert.equal(model.statusKey({ state: 'error', error: 'not_installed' }), 'voice.error.not_installed');
    assert.equal(model.statusKey({ state: 'error', error: 'pw-record: boom' }), 'voice.error.generic');
    assert.equal(model.statusKey({ state: 'idle' }), '');
    assert.ok(model.isActive('listening') && model.isActive('transcribing') && !model.isActive('done'));
    assert.ok(model.isTerminal('done') && model.isTerminal('error') && !model.isTerminal('idle'));
});

test('every status key is translated', () => {
    const en = JSON.parse(fs.readFileSync(path.join(__dirname, '../translations/en.json'), 'utf8'));
    const keys = ['listening', 'transcribing', 'done', 'empty', 'cancelled'].map(state => model.statusKey({ state, target: 'ai' }))
        .concat(['disabled', 'not_installed', 'model_missing', 'x'].map(e => model.errorKey(e)))
        .concat([model.statusKey({ state: 'listening', target: 'dictation' })]);
    for (const k of keys)
        assert.ok(en[k], `missing translation ${k}`);
});

test('AI routing: sidebar when open, notch otherwise; handleVoice only if present', () => {
    assert.equal(model.aiTarget(true), 'sidebar');
    assert.equal(model.aiTarget(false), 'notch');
    assert.equal(model.tryHandleVoice({}, 'hi', 'notch'), false);
    assert.equal(model.tryHandleVoice(null, 'hi', 'notch'), false);
    const got = [];
    assert.equal(model.tryHandleVoice({ handleVoice: (t, d) => got.push(t + '|' + d) }, 'hi', 'sidebar'), true);
    assert.deepEqual(got, ['hi|sidebar']);
});

test('bands resample to any bar count with a floor, smoothing attacks fast', () => {
    const r = plain(model.resampleBands([0, 1], 4, 0.05));
    assert.equal(r.length, 4);
    assert.ok(r[0] >= 0.05 && r[3] === 1 && r[1] < r[2]);
    assert.deepEqual(plain(model.resampleBands([], 3, 0.1)), [0.1, 0.1, 0.1]);
    assert.deepEqual(plain(model.resampleBands([2, 2], 2, 0)), [1, 1]);
    const s = plain(model.smoothBands([0, 1], [1, 0], 0.5, 0.25));
    assert.deepEqual(s, [0.5, 0.75]);
});

test('voice defaults: enums are valid and the validator rejects bad values', () => {
    assert.ok(model.ACTIVATIONS.includes(defaults.activation));
    assert.ok(model.TYPING_METHODS.includes(defaults.typingMethod));
    assert.ok(model.MODELS.includes(defaults.model));
    assert.ok(model.LANGUAGES.includes(defaults.language));
    const v = plain(validator.validate({ ...defaults, activation: 'shout', typingMethod: 'telepathy', vadSensitivity: 7 }, defaults));
    assert.equal(v.activation, 'push-to-talk');
    assert.equal(v.typingMethod, 'auto');
    assert.equal(v.vadSensitivity, 0.5);
    const ok = plain(validator.validate({ ...defaults, activation: 'toggle', typingMethod: 'ydotool', vadSensitivity: 0.8 }, defaults));
    assert.equal(ok.activation, 'toggle');
    assert.equal(ok.typingMethod, 'ydotool');
    assert.equal(ok.vadSensitivity, 0.8);
});

test('voice defaults match the Go backend defaults', () => {
    const go = fs.readFileSync(path.join(__dirname, '../backend/pkg/svc/voice/config.go'), 'utf8');
    const tags = Object.fromEntries([...go.matchAll(/^\s+(\w+)\s+\w+\s+`json:"(\w+)"`/gm)].map(m => [m[1], m[2]]));
    const body = go.slice(go.indexOf('func DefaultConfig'), go.indexOf('// LoadConfig'));
    const goDefaults = {};
    for (const m of body.matchAll(/^\s+(\w+):\s+(.+),$/gm)) {
        let v = m[2].trim();
        if (v === 'ModePushToTalk') v = '"push-to-talk"';
        goDefaults[tags[m[1]]] = JSON.parse(v);
    }
    assert.deepEqual(Object.keys(goDefaults).sort(), Object.keys(defaults).sort());
    for (const k of Object.keys(defaults))
        assert.equal(goDefaults[k], defaults[k], `default ${k}`);
});
