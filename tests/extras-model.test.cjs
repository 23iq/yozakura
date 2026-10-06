'use strict';
const test = require('node:test');
const assert = require('node:assert');
const fs = require('node:fs');
const path = require('node:path');

const src = fs.readFileSync(path.join(__dirname, '..', 'modules/extras/ExtrasModel.js'), 'utf8').replace('.pragma library', '');
const M = new Function(src + '; return {parseSize, formatSize, selectionSize, cardState, visibleEntries, preselect, selectedIds, parseError, groupByCategory, activeJobs, cancellable, accentIndex, toggled};')();

const catalog = {
    categories: [
        { id: 'agents', name: 'extras.cat.agents', icon: 'robot' },
        { id: 'games', name: 'extras.cat.games', icon: 'gamepad' },
        { id: 'browsers', name: 'extras.cat.browsers', icon: 'globe' },
    ],
    entries: [
        { id: 'claude-code', category: 'agents', name: 'Claude Code', icon: 'robot', size: '200 MB', recommended: true },
        { id: 'nodejs', category: 'agents', name: 'Node.js', icon: 'code', hidden: true },
        { id: 'steam', category: 'games', name: 'Steam', icon: 'gamepad', size: '1.2 GB', multilib: true },
        { id: 'firefox', category: 'browsers', name: 'Firefox', icon: 'firefox', recommended: true },
        { id: 'ghostty', category: 'browsers', name: 'Ghostty', icon: 'terminal', recommended: true },
    ],
};
const status = {
    'claude-code': { id: 'claude-code', state: 'missing' },
    nodejs: { id: 'nodejs', state: 'missing' },
    steam: { id: 'steam', state: 'missing' },
    firefox: { id: 'firefox', state: 'installed', source: 'pkg' },
    ghostty: { id: 'ghostty', state: 'unavailable', reason: 'only_distro' },
};
const ids = list => list.map(e => e.id);

test('parseSize / formatSize', () => {
    assert.strictEqual(M.parseSize('80 MB'), 80e6);
    assert.strictEqual(M.parseSize('1.2 GB'), 1.2e9);
    assert.strictEqual(M.parseSize('512 KB'), 512e3);
    assert.strictEqual(M.parseSize(''), 0);
    assert.strictEqual(M.parseSize(undefined), 0);
    assert.strictEqual(M.parseSize('huge'), 0);
    assert.strictEqual(M.formatSize(0), '');
    assert.strictEqual(M.formatSize(280e6), '280 MB');
    assert.strictEqual(M.formatSize(4e9), '4 GB');
    assert.strictEqual(M.formatSize(12.34e9), '12 GB');
});

test('selectionSize sums human sizes of selected entries', () => {
    const entries = [{ id: 'a', size: '80 MB' }, { id: 'b', size: '1.2 GB' }, { id: 'c', size: '4 GB' }, { id: 'd' }];
    assert.strictEqual(M.selectionSize(entries, { a: true, b: true }), '1.3 GB');
    assert.strictEqual(M.selectionSize(entries, { a: true, d: true }), '80 MB');
    assert.strictEqual(M.selectionSize(entries, { d: true }), '');
    assert.strictEqual(M.selectionSize(entries, { c: false }), '');
});

test('cardState maps status and live progress', () => {
    assert.strictEqual(M.cardState({ state: 'installed' }, null), 'installed');
    assert.strictEqual(M.cardState({ state: 'missing' }, null), 'selectable');
    assert.strictEqual(M.cardState(undefined, null), 'selectable');
    assert.strictEqual(M.cardState({ state: 'installing' }, null), 'installing');
    assert.strictEqual(M.cardState({ state: 'failed', reason: 'network' }, null), 'failed');
    assert.strictEqual(M.cardState({ state: 'unavailable' }, null), 'unavailable');
    assert.strictEqual(M.cardState({ state: 'missing' }, { state: 'running', percent: 10 }), 'installing');
    assert.strictEqual(M.cardState({ state: 'missing' }, { state: 'queued' }), 'installing');
    assert.strictEqual(M.cardState({ state: 'missing' }, { state: 'failed' }), 'failed');
    assert.strictEqual(M.cardState({ state: 'missing' }, { state: 'cancelled' }), 'selectable');
    // a finished job wins over a stale status until the next status event
    assert.strictEqual(M.cardState({ state: 'missing' }, { state: 'done' }), 'installed');
    // detection says installed: never offered again
    assert.strictEqual(M.cardState({ state: 'installed' }, { state: 'failed' }), 'installed');
});

test('visibleEntries never shows hidden entries; unavailable only on a matching search', () => {
    assert.deepStrictEqual(ids(M.visibleEntries(catalog, status, '', '')), ['claude-code', 'steam', 'firefox']);
    assert.deepStrictEqual(ids(M.visibleEntries(catalog, status, 'node', '')), []);
    assert.deepStrictEqual(ids(M.visibleEntries(catalog, status, 'ghost', '')), ['ghostty']);
    assert.deepStrictEqual(ids(M.visibleEntries(catalog, status, '', 'games')), ['steam']);
    assert.deepStrictEqual(ids(M.visibleEntries(catalog, status, '', ['agents', 'browsers'])), ['claude-code', 'firefox']);
    assert.deepStrictEqual(ids(M.visibleEntries(catalog, status, 'STEAM', 'agents')), []);
    // extra searchable text (translated description)
    const text = e => (e.id === 'steam' ? 'Game store and launcher' : '');
    assert.deepStrictEqual(ids(M.visibleEntries(catalog, status, 'launcher', '', text)), ['steam']);
    assert.deepStrictEqual(M.visibleEntries(null, status, '', ''), []);
});

test('preselect: onboarding picks recommended missing entries, settings nothing', () => {
    assert.deepStrictEqual(M.preselect(catalog, status, 'onboarding'), { 'claude-code': true });
    assert.deepStrictEqual(M.preselect(catalog, status, 'settings'), {});
});

test('selectedIds keeps selected entries that are still selectable', () => {
    const sel = { 'claude-code': true, steam: true, firefox: true, ghostty: true, nodejs: false };
    assert.deepStrictEqual(M.selectedIds(catalog, status, {}, sel), ['claude-code', 'steam']);
    assert.deepStrictEqual(M.selectedIds(catalog, status, { steam: { state: 'running' } }, sel), ['claude-code']);
    assert.deepStrictEqual(M.selectedIds(catalog, status, { steam: { state: 'failed' } }, sel), ['claude-code']);
});

test('toggled returns a new map', () => {
    const a = { x: true };
    const b = M.toggled(a, 'y');
    assert.deepStrictEqual(b, { x: true, y: true });
    assert.deepStrictEqual(M.toggled(b, 'x'), { y: true });
    assert.deepStrictEqual(a, { x: true });
});

test('parseError splits coded IPC errors', () => {
    assert.deepStrictEqual(M.parseError('needs_confirm: {"kind":"multilib","entries":["steam"]}'),
        { code: 'needs_confirm', data: { kind: 'multilib', entries: ['steam'] }, message: '' });
    assert.deepStrictEqual(M.parseError('unavailable: {"reasons":{"zen-browser":"needs_aur_helper"}}').data.reasons,
        { 'zen-browser': 'needs_aur_helper' });
    assert.deepStrictEqual(M.parseError('boom'), { code: '', data: null, message: 'boom' });
    assert.deepStrictEqual(M.parseError('x: {broken'), { code: '', data: null, message: 'x: {broken' });
    assert.deepStrictEqual(M.parseError(null), { code: '', data: null, message: '' });
});

test('groupByCategory keeps catalog category order', () => {
    const g = M.groupByCategory(catalog, M.visibleEntries(catalog, status, '', ''));
    assert.deepStrictEqual(g.map(x => [x.category.id, ids(x.entries)]),
        [['agents', ['claude-code']], ['games', ['steam']], ['browsers', ['firefox']]]);
});

test('activeJobs lists queued and running jobs, running first', () => {
    const jobs = {
        'system-1': { job: 'system-1', state: 'queued', entries: ['steam'] },
        'npm-2': { job: 'npm-2', state: 'running', entries: ['codex'], percent: 40 },
        'flatpak-3': { job: 'flatpak-3', state: 'done', entries: ['spotify'] },
    };
    assert.deepStrictEqual(M.activeJobs(jobs).map(j => j.job), ['npm-2', 'system-1']);
    assert.deepStrictEqual(M.activeJobs(null), []);
});

test('cancellable: queued always, running only for user-level kinds', () => {
    assert.strictEqual(M.cancellable({ state: 'queued', kind: 'system' }), true);
    assert.strictEqual(M.cancellable({ state: 'running', kind: 'system' }), false);
    assert.strictEqual(M.cancellable({ state: 'running', kind: 'aur' }), false);
    assert.strictEqual(M.cancellable({ state: 'running', kind: 'flatpak' }), true);
    assert.strictEqual(M.cancellable({ state: 'running', kind: 'npm' }), true);
    assert.strictEqual(M.cancellable({ state: 'done', kind: 'npm' }), false);
    assert.strictEqual(M.cancellable(null), false);
});

test('accentIndex is stable per category', () => {
    assert.strictEqual(M.accentIndex(catalog, 'agents'), 0);
    assert.strictEqual(M.accentIndex(catalog, 'games'), 1);
    assert.strictEqual(M.accentIndex(catalog, 'browsers'), 2);
    assert.strictEqual(M.accentIndex(catalog, 'nope'), 0);
});
