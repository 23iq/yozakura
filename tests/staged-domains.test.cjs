// modules/settings/StagedDomains.js: the domains a staging changed (what a
// separate window writes itself when no main shell writes for it) and how
// each is written.
const { test } = require('node:test');
const assert = require('node:assert/strict');
const path = require('node:path');
const { loadLibrary } = require('./lib/qmljs.cjs');

const S = loadLibrary(path.join(__dirname, '../modules/settings/StagedDomains.js'));
const plain = v => JSON.parse(JSON.stringify(v));

function states(config, snapshot, flags) {
    const sections = { bar: ['position'], desktop: ['widgets'], dock: ['enabled'] };
    const snap = () => {
        const out = {};
        for (const d of Object.keys(sections)) {
            out[d] = {};
            for (const p of sections[d]) out[d][p] = JSON.parse(JSON.stringify(config[d][p]));
        }
        return out;
    };
    return Object.assign({
        themeHasChanges: false, compositorHasChanges: false, shellHasChanges: false,
        _shellSections: sections,
        shellSnapshot: snapshot ? snap() : null,
        createShellSnapshot: snap
    }, flags || {});
}

test('only the shell domains that differ from the snapshot', () => {
    const config = { bar: { position: 'top' }, desktop: { widgets: [{ id: 'a', x: 1 }] }, dock: { enabled: true } };
    const gs = states(config, true, { shellHasChanges: true });
    config.bar.position = 'left';
    assert.deepEqual(plain(S.changed(gs)), ['bar']);
    config.desktop.widgets = [{ id: 'a', x: 2 }];
    assert.deepEqual(plain(S.changed(gs)), ['bar', 'desktop']);
    // changed back: not changed
    config.bar.position = 'top';
    assert.deepEqual(plain(S.changed(gs)), ['desktop']);
});

test('theme and compositor by their flags; nothing staged: nothing', () => {
    const config = { bar: { position: 'top' }, desktop: { widgets: [] }, dock: { enabled: true } };
    assert.deepEqual(plain(S.changed(states(config, false))), []);
    assert.deepEqual(plain(S.changed(states(config, false, { themeHasChanges: true, compositorHasChanges: true }))),
        ['theme', 'compositor']);
    // staged without a snapshot to compare with: every shell domain
    assert.deepEqual(plain(S.changed(states(config, false, { shellHasChanges: true }))), ['bar', 'desktop', 'dock']);
    assert.deepEqual(plain(S.changed(null)), []);
});

test('write: the theme through its loader, the rest through save<Domain>', () => {
    const calls = [];
    const config = {
        loader: { writeAdapter: () => calls.push('theme') },
        saveBar: () => calls.push('bar'),
        saveCompositor: () => calls.push('compositor')
    };
    S.write(config, ['theme', 'bar', 'compositor', 'nosuch']);
    assert.deepEqual(calls, ['theme', 'bar', 'compositor']);
});

test('write: only this process\'s changes over the current file where the config can merge', () => {
    const calls = [];
    const file = (name, ok) => ({ writeMerged: () => { calls.push('merged ' + name); return ok; } });
    const files = { theme: file('theme', true), bar: file('bar', true), dock: file('dock', false) };
    const config = {
        configFile: name => files[name] || null,
        loader: { writeAdapter: () => calls.push('theme') },
        saveBar: () => calls.push('bar'),
        saveDock: () => calls.push('dock'),
        saveCompositor: () => calls.push('compositor')
    };
    S.write(config, ['theme', 'bar', 'dock', 'compositor']);
    // dock not loaded / broken (writeMerged false): its save<Domain>; no file: the whole domain
    assert.deepEqual(calls, ['merged theme', 'merged bar', 'merged dock', 'dock', 'compositor']);
});
