'use strict';
const test = require('node:test');
const assert = require('node:assert');
const fs = require('node:fs');
const path = require('node:path');

const src = fs.readFileSync(path.join(__dirname, '..', 'modules/services/KeyboardModel.js'), 'utf8').replace('.pragma library', '');
const M = new Function(src + '; return {shortName, toSettings, hasOption, setOption, addLayout, removeLayout, moveLayout, setVariant, searchLayouts, variantOptions, groupOptions, defaultsForLocale};')();

const catalog = {
    layouts: [
        { name: 'us', description: 'English (US)', variants: [{ name: 'intl', description: 'English (intl.)' }] },
        { name: 'ru', description: 'Russian', variants: [] },
        { name: 'ua', description: 'Ukrainian', variants: [] },
    ],
    groups: [{ name: 'grp', description: 'Switching' }, { name: 'caps', description: 'Caps Lock' }],
    options: [
        { group: 'grp', name: 'grp:alt_shift_toggle', description: 'Alt+Shift' },
        { group: 'caps', name: 'caps:escape', description: 'Caps as Esc' },
        { group: 'compose', name: 'compose:ralt', description: 'Compose' },
    ],
};

test('shortName', () => {
    assert.strictEqual(M.shortName('us'), 'EN');
    assert.strictEqual(M.shortName('ru'), 'RU');
});

test('toSettings merges the switch bind first and dedupes', () => {
    const s = M.toSettings({
        layouts: [{ layout: 'us', variant: '' }, { layout: 'ru', variant: 'phonetic' }, { layout: '', variant: '' }],
        switchBind: 'alt_shift',
        options: ['caps:escape', 'grp:alt_shift_toggle', 'caps:escape'],
    });
    assert.deepStrictEqual(s, { layouts: 'us,ru', variants: ',phonetic', options: 'grp:alt_shift_toggle,caps:escape' });
});

test('toSettings with no bind', () => {
    const s = M.toSettings({ layouts: [{ layout: 'us' }], switchBind: 'none', options: [] });
    assert.deepStrictEqual(s, { layouts: 'us', variants: '', options: '' });
});

test('options toggle', () => {
    assert.deepStrictEqual(M.setOption(['a'], 'b', true), ['a', 'b']);
    assert.deepStrictEqual(M.setOption(['a', 'b'], 'a', false), ['b']);
    assert.strictEqual(M.hasOption(['a'], 'a'), true);
});

test('layout list edits', () => {
    const l = [{ layout: 'us', variant: '' }];
    const two = M.addLayout(l, 'ru');
    assert.strictEqual(two.length, 2);
    assert.strictEqual(M.addLayout(two, 'ru').length, 2);
    assert.deepStrictEqual(M.moveLayout(two, 0, 1).map(x => x.layout), ['ru', 'us']);
    assert.strictEqual(M.removeLayout(l, 0).length, 1);
    assert.deepStrictEqual(M.removeLayout(two, 0).map(x => x.layout), ['ru']);
    assert.strictEqual(M.setVariant(two, 0, 'intl')[0].variant, 'intl');
});

test('searchLayouts', () => {
    assert.deepStrictEqual(M.searchLayouts(catalog, 'ru', ['us']).map(l => l.name), ['ru']);
    assert.deepStrictEqual(M.searchLayouts(catalog, 'ukr', []).map(l => l.name), ['ua']);
    assert.deepStrictEqual(M.searchLayouts(catalog, '', ['us']).map(l => l.name), ['ru', 'ua']);
});

test('variantOptions and groupOptions', () => {
    assert.deepStrictEqual(M.variantOptions(catalog, 'us', 'Default').map(o => o.value), ['', 'intl']);
    assert.deepStrictEqual(M.variantOptions(catalog, 'zz', 'Default').length, 1);
    const g = M.groupOptions(catalog);
    assert.deepStrictEqual(g.map(x => x.name), ['caps', 'compose']);
    assert.strictEqual(g[0].options[0].name, 'caps:escape');
});

test('defaultsForLocale: us plus the layout of the system locale', () => {
    assert.deepStrictEqual(M.defaultsForLocale('ru_RU'), ['us', 'ru']);
    assert.deepStrictEqual(M.defaultsForLocale('en_US'), ['us']);
    assert.deepStrictEqual(M.defaultsForLocale('en_GB.UTF-8'), ['us']);
    assert.deepStrictEqual(M.defaultsForLocale('de_DE'), ['us', 'de']);
    assert.deepStrictEqual(M.defaultsForLocale('uk_UA'), ['us', 'ua']);
    assert.deepStrictEqual(M.defaultsForLocale('ar_EG'), ['us', 'ara']);
    assert.deepStrictEqual(M.defaultsForLocale('pt_BR'), ['us', 'br']);
    assert.deepStrictEqual(M.defaultsForLocale('pt-PT'), ['us', 'pt']);
    assert.deepStrictEqual(M.defaultsForLocale('xx_YY'), ['us'], 'unknown language: us only');
    assert.deepStrictEqual(M.defaultsForLocale(''), ['us']);
    assert.deepStrictEqual(M.defaultsForLocale('C'), ['us']);
});
