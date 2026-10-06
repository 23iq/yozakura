'use strict';
const test = require('node:test');
const assert = require('node:assert');
const fs = require('node:fs');
const path = require('node:path');

const src = fs.readFileSync(path.join(__dirname, '..', 'modules/terminal/TermModel.js'), 'utf8').replace('.pragma library', '');
const M = new Function(src + '; return {spansToRuns, columns, alignRight, layoutRuns, pickFont, hasNerdFont, previewKey, engineExtra, approxNotice, fishState};')();

test('spansToRuns merges adjacent spans of the same style and drops empty ones', () => {
    const runs = M.spansToRuns([
        { text: ' ', fg: '#111111', bg: '#222222' },
        { text: '\uf303', fg: '#111111', bg: '#222222' },
        { text: '' },
        { text: ' ', fg: '#111111', bg: '#222222' },
        { text: '\ue0b0', fg: '#222222', bg: '#333333' },
        { text: 'main', fg: '#111111', bg: '#333333', bold: true },
        { text: '!', fg: '#111111', bg: '#333333', bold: true },
    ]);
    assert.deepStrictEqual(runs.map(r => r.text), [' \uf303 ', '\ue0b0', 'main!']);
    assert.strictEqual(runs[2].bold, true);
    assert.strictEqual(runs[0].italic, false);
    assert.strictEqual(runs[0].bg, '#222222');
    assert.deepStrictEqual(M.spansToRuns(null), []);
});

test('spansToRuns keeps different styles apart', () => {
    const runs = M.spansToRuns([{ text: 'a', fg: '#111111' }, { text: 'b', fg: '#111111', italic: true }, { text: 'c' }]);
    assert.strictEqual(runs.length, 3);
});

test('columns counts code points, not UTF-16 units', () => {
    assert.strictEqual(M.columns([{ text: '\u{f0001}x' }, { text: '\u276f ' }]), 4);
    assert.strictEqual(M.columns([]), 0);
});

test('alignRight gives the gap before the right prompt, -1 when it does not fit', () => {
    const left = [{ text: 'abc ' }];
    const right = [{ text: '12:00' }];
    assert.strictEqual(M.alignRight(left, right, 20), 11);
    assert.strictEqual(M.alignRight(left, right, 9), -1);
    assert.strictEqual(M.alignRight(left, [], 20), 16);
});

test('layoutRuns places runs on whole pixels with no gaps', () => {
    const runs = M.spansToRuns([{ text: 'ab', bg: '#000000' }, { text: 'c', bg: '#111111', bold: true }, { text: 'de' }]);
    const out = M.layoutRuns(runs, (text, bold) => text.length * (bold ? 7.4 : 7.3));
    assert.deepStrictEqual(out.map(r => [r.x, r.width]), [[0, 15], [15, 7], [22, 15]]);
    for (let i = 1; i < out.length; i++)
        assert.strictEqual(out[i].x, out[i - 1].x + out[i - 1].width);
    assert.strictEqual(M.layoutRuns([], () => 0).length, 0);
});

test('pickFont takes the first installed candidate, case-insensitively', () => {
    const fams = ['JetBrainsMono Nerd Font', 'Noto Sans', 'monospace'];
    assert.strictEqual(M.pickFont(['', 'Iosevka Nerd Font Mono', 'jetbrainsmono nerd font'], fams), 'JetBrainsMono Nerd Font');
    assert.strictEqual(M.pickFont(['Missing'], fams), 'monospace');
    assert.strictEqual(M.pickFont([], []), 'monospace');
});

test('previewKey and engineExtra', () => {
    assert.strictEqual(M.previewKey('starship', 'zen'), 'starship:zen');
    assert.strictEqual(M.engineExtra('starship'), 'starship');
    assert.strictEqual(M.engineExtra('ohmyposh'), 'oh-my-posh');
});

test('approxNotice explains an approximate preview and offers the install only for a missing engine', () => {
    assert.strictEqual(M.approxNotice(null), null);
    assert.strictEqual(M.approxNotice({ exact: true }), null);
    assert.deepStrictEqual(M.approxNotice({ exact: false, engine: 'starship', reason: 'engine_missing' }),
        { reason: 'prefs.term.look.approx.engine_missing', install: 'starship' });
    assert.deepStrictEqual(M.approxNotice({ exact: false, engine: 'ohmyposh', reason: 'engine_missing' }),
        { reason: 'prefs.term.look.approx.engine_missing', install: 'oh-my-posh' });
    assert.deepStrictEqual(M.approxNotice({ exact: false, engine: 'starship', reason: 'git_missing' }),
        { reason: 'prefs.term.look.approx.git_missing', install: '' });
    assert.deepStrictEqual(M.approxNotice({ exact: false, engine: 'starship', reason: 'weird' }),
        { reason: 'prefs.term.look.approx.error', install: '' });
});

test('fishState', () => {
    assert.strictEqual(M.fishState(null), 'unknown');
    assert.strictEqual(M.fishState({ fishInstalled: false }), 'missing');
    assert.strictEqual(M.fishState({ fishInstalled: true, fishIsLoginShell: false }), 'notLogin');
    assert.strictEqual(M.fishState({ fishInstalled: true, fishIsLoginShell: true }), 'ok');
});

test('every prompt preset description and approximate reason is translated in every language', () => {
    const root = path.join(__dirname, '..');
    const dir = path.join(root, 'assets/terminal/prompts');
    const keys = fs.readdirSync(dir).filter(f => f.endsWith('.json'))
        .map(f => JSON.parse(fs.readFileSync(path.join(dir, f), 'utf8')).description);
    assert.ok(keys.length >= 10, 'presets found');
    for (const r of ['engine_missing', 'git_missing', 'timeout', 'error'])
        keys.push(M.approxNotice({ exact: false, engine: 'starship', reason: r }).reason);
    const langs = JSON.parse(fs.readFileSync(path.join(root, 'translations/languages.json'), 'utf8'));
    const codes = (Array.isArray(langs) ? langs.map(l => l.code || l) : Object.keys(langs));
    assert.ok(codes.includes('en') && codes.length >= 3, 'languages: ' + codes);
    for (const code of codes) {
        const strings = JSON.parse(fs.readFileSync(path.join(root, 'translations', code + '.json'), 'utf8'));
        for (const k of keys) {
            assert.ok(typeof k === 'string' && (k.startsWith('term.prompt.') || k.startsWith('prefs.term.look.approx.')), 'key shape: ' + k);
            assert.ok(strings[k], code + ': missing ' + k);
        }
    }
});

test('hasNerdFont matches patched and symbols-only Nerd Fonts', () => {
    assert.strictEqual(M.hasNerdFont(['Noto Sans', 'Symbols Nerd Font Mono']), true);
    assert.strictEqual(M.hasNerdFont(['JetBrainsMono NERD Font']), true);
    assert.strictEqual(M.hasNerdFont(['Noto Sans', 'DejaVu Sans Mono']), false);
    assert.strictEqual(M.hasNerdFont(null), false);
});
