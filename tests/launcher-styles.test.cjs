// Launcher result styles: registry, grid navigation, preview registry.
const test = require('node:test');
const assert = require('node:assert/strict');
const path = require('node:path');
const { loadLibrary } = require('./lib/qmljs.cjs');

const DIR = path.join(__dirname, '..', 'modules/widgets/launcher');
const S = loadLibrary(path.join(DIR, 'ResultStyles.js'));
const P = loadLibrary(path.join(DIR, 'previews/PreviewRegistry.js'));
const apps = n => Array.from({ length: n }, (_, i) => ({ provider: 'apps', key: 'a' + i }));

test('effective: grid only for app results, unknown style is list', () => {
    assert.equal(S.effective('grid', apps(3)), 'grid');
    assert.equal(S.effective('grid', [...apps(2), { provider: 'files' }]), 'list');
    assert.equal(S.effective('grid', []), 'list');
    assert.equal(S.effective('cards', [{ provider: 'files' }]), 'cards');
    assert.equal(S.effective('bogus', apps(2)), 'list');
});

test('rowHeight: cards are 1.5x the base row', () => {
    assert.equal(S.rowHeight('list', 48), 48);
    assert.equal(S.rowHeight('cards', 48), 72);
    assert.equal(S.rowHeight('cards', 41), 62);
});

test('columns: fits the width, at least one', () => {
    assert.equal(S.columns(464, 88), 5);
    assert.equal(S.columns(40, 88), 1);
});

test('gridMove: 2D arrows, clamped, partial last row', () => {
    // 7 items, 3 columns: rows [0 1 2] [3 4 5] [6]
    assert.equal(S.gridMove(0, 'right', 3, 7), 1);
    assert.equal(S.gridMove(2, 'right', 3, 7), 3);
    assert.equal(S.gridMove(6, 'right', 3, 7), 6);
    assert.equal(S.gridMove(0, 'left', 3, 7), 0);
    assert.equal(S.gridMove(3, 'left', 3, 7), 2);
    assert.equal(S.gridMove(1, 'down', 3, 7), 4);
    assert.equal(S.gridMove(5, 'down', 3, 7), 6);
    assert.equal(S.gridMove(6, 'down', 3, 7), 6);
    assert.equal(S.gridMove(4, 'up', 3, 7), 1);
    assert.equal(S.gridMove(1, 'up', 3, 7), 1);
    assert.equal(S.gridMove(-1, 'down', 3, 7), 0);
    assert.equal(S.gridMove(0, 'down', 3, 0), -1);
});

test('previewFor: provider support, inert rows excluded', () => {
    assert.equal(P.previewFor({ provider: 'files', data: { path: '/a/b.png' } }).kind, 'file');
    assert.equal(P.previewFor({ provider: 'files', inert: true }), null);
    assert.equal(P.previewFor({ provider: 'calculator', key: 'calc', title: '84' }).kind, 'calc');
    assert.equal(P.previewFor({ provider: 'calculator', key: 'hint' }), null);
    assert.equal(P.previewFor({ provider: 'clipboard', data: { preview: 'x' } }).kind, 'clipboard');
    assert.equal(P.previewFor({ provider: 'apps' }), null);
    assert.equal(P.previewFor(null), null);
});

test('hasDetail: every runnable result, never hint rows', () => {
    assert.equal(P.hasDetail({ provider: 'apps', title: 'Firefox' }), true);
    assert.equal(P.hasDetail({ provider: 'calculator', key: 'hint', inert: true }), false);
    assert.equal(P.hasDetail(null), false);
});

test('actions: provider options, else the main action from the hint', () => {
    const opts = [{ id: '', text: 'Launch' }, { id: 'pin', text: 'Pin' }];
    assert.equal(P.actions({ hint: 'Launch' }, opts), opts);
    assert.equal(JSON.stringify(P.actions({ hint: 'Run', icon: 'x' }, [])), '[{"id":"","text":"Run","icon":"x"}]');
    assert.equal(P.actions({}, []).length, 0);
    assert.equal(P.actions(null, null).length, 0);
});

test('sections: a label above each provider run', () => {
    const items = [{ provider: 'calculator' }, { provider: 'apps' }, { provider: 'apps' }, { provider: 'files' }];
    const s = S.sections(items);
    assert.deepEqual([...s.starts], [true, true, false, true]);
    assert.deepEqual([...s.before], [1, 2, 2, 3]);
    assert.equal(S.sections([]).starts.length, 0);
    assert.equal(S.sections(null).before.length, 0);
});

test('fileKind and firstLines', () => {
    assert.equal(P.fileKind('/x/a.PNG'), 'image');
    assert.equal(P.fileKind('/x/a.md'), 'text');
    assert.equal(P.fileKind('/x/a.bin'), 'other');
    assert.equal(P.fileKind('/x/Makefile'), 'text');
    assert.equal(P.firstLines('a\nb\nc', 2), 'a\nb');
    assert.equal(P.firstLines('', 2), '');
});
