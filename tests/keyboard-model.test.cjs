'use strict';
const test = require('node:test');
const assert = require('node:assert');
const fs = require('node:fs');
const path = require('node:path');

const src = fs.readFileSync(path.join(__dirname, '..', 'modules/services/KeyboardModel.js'), 'utf8').replace('.pragma library', '');
const M = new Function(src + '; return {shortName, toSettings, hasOption, setOption, addLayout, removeLayout, moveLayout, setVariant, searchLayouts, variantOptions, groupOptions, defaultsForLocale, effective, planEdit, fromConfig, touchesCompositor};')();
const migSrc = fs.readFileSync(path.join(__dirname, '..', 'config/KeyboardMigration.js'), 'utf8').replace('.pragma library', '');
const Mig = new Function(migSrc + '; return {legacyManaged};')();
const defSrc = fs.readFileSync(path.join(__dirname, '..', 'config/defaults/keyboard.js'), 'utf8').replace('.pragma library', '');
const DEFAULTS = new Function(defSrc + '; return data;')();

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

// --- keyboard.managed (ruling K-1) ---
const cfg = { layouts: [{ layout: 'us', variant: '' }], switchBind: 'alt_shift', options: [], repeatRate: 25, repeatDelay: 600 };
const current = { available: true, layouts: [{ layout: 'us', variant: '' }, { layout: 'ru', variant: '' }], switchBind: 'alt_shift', options: ['caps:escape'], repeatRate: 111, repeatDelay: 175 };

test('effective: the compositor values until managed, the domain after', () => {
    const before = M.effective(false, cfg, current);
    assert.deepStrictEqual(before.layouts.map(l => l.layout), ['us', 'ru']);
    assert.strictEqual(before.repeatRate, 111);
    assert.deepStrictEqual(before.options, ['caps:escape']);
    assert.deepStrictEqual(M.effective(true, cfg, current), M.fromConfig(cfg));
    assert.deepStrictEqual(M.effective(false, cfg, null), M.fromConfig(cfg), 'unknown current: the domain');
    assert.deepStrictEqual(M.effective(false, cfg, { available: false, layouts: [] }), M.fromConfig(cfg), 'niri/mango: the domain');
});

test('planEdit: the first compositor edit copies the current values in and sets managed', () => {
    const w = M.planEdit(false, current, { repeatRate: 120 });
    assert.strictEqual(w.managed, true);
    assert.deepStrictEqual(w.layouts.map(l => l.layout), ['us', 'ru']);
    assert.strictEqual(w.repeatRate, 120, 'the edit wins over the copied value');
    assert.strictEqual(w.repeatDelay, 175);
    assert.deepStrictEqual(w.options, ['caps:escape']);
    assert.strictEqual(w.switchBind, 'alt_shift');
});

test('planEdit: managed edits and showIndicator write only the patch', () => {
    assert.deepStrictEqual(M.planEdit(true, current, { repeatRate: 30 }), { repeatRate: 30 });
    assert.deepStrictEqual(M.planEdit(false, current, { showIndicator: false }), { showIndicator: false });
});

test('planEdit: out-of-range or unknown compositor values keep the configured ones', () => {
    const w = M.planEdit(false, Object.assign({}, current, { repeatRate: 0, repeatDelay: 5000, switchBind: 'weird' }), { layouts: [{ layout: 'de', variant: '' }] });
    assert.ok(!('repeatRate' in w) && !('repeatDelay' in w) && !('switchBind' in w));
    assert.deepStrictEqual(w.layouts, [{ layout: 'de', variant: '' }]);
    assert.strictEqual(w.managed, true);
    // a compositor that cannot report: only the patch + managed
    assert.deepStrictEqual(M.planEdit(false, { available: false, layouts: [] }, { switchBind: 'caps' }), { managed: true, switchBind: 'caps' });
});

test('migration: a keyboard.json of pure defaults stays unmanaged', () => {
    assert.strictEqual(DEFAULTS.managed, false);
    const legacy = { layouts: [{ layout: 'us', variant: '' }], switchBind: 'alt_shift', options: [], repeatRate: 25, repeatDelay: 600, showIndicator: true };
    assert.strictEqual(Mig.legacyManaged(legacy, DEFAULTS), false);
    assert.strictEqual(Mig.legacyManaged(Object.assign({}, legacy, { showIndicator: false }), DEFAULTS), false, 'showIndicator is not a compositor key');
    assert.strictEqual(Mig.legacyManaged({ layouts: [{ layout: 'us' }] }, DEFAULTS), false, 'missing keys and variant count as defaults');
});

test('migration: a file the user changed (us,ru 111/175) is managed', () => {
    const user = { layouts: [{ layout: 'us', variant: '' }, { layout: 'ru', variant: '' }], switchBind: 'alt_shift', options: [], repeatRate: 111, repeatDelay: 175, showIndicator: true };
    assert.strictEqual(Mig.legacyManaged(user, DEFAULTS), true);
    assert.strictEqual(Mig.legacyManaged({ repeatRate: 30 }, DEFAULTS), true);
    assert.strictEqual(Mig.legacyManaged({ options: ['caps:escape'] }, DEFAULTS), true);
});

test('migration: files that already carry managed are left alone', () => {
    assert.strictEqual(Mig.legacyManaged({ managed: false, repeatRate: 111 }, DEFAULTS), null);
    assert.strictEqual(Mig.legacyManaged({ managed: true }, DEFAULTS), null);
    assert.strictEqual(Mig.legacyManaged([], DEFAULTS), null);
    assert.strictEqual(Mig.legacyManaged(null, DEFAULTS), null);
});

test('touchesCompositor: only keys the compositor sees', () => {
    assert.strictEqual(M.touchesCompositor({ repeatRate: 1 }), true);
    assert.strictEqual(M.touchesCompositor({ layouts: [] }), true);
    assert.strictEqual(M.touchesCompositor({ showIndicator: false }), false);
    assert.strictEqual(M.touchesCompositor({ managed: true }), false);
    assert.deepStrictEqual(M.planEdit(false, { available: false }, { managed: true }), { managed: true }, 'explicit takeover');
});

test('planEdit: adding a 2nd layout with no switch key defaults the switch to alt_shift', () => {
    const one = { available: true, layouts: [{ layout: 'us', variant: '' }], switchBind: 'none', options: [], repeatRate: 25, repeatDelay: 600 };
    const two = [{ layout: 'us', variant: '' }, { layout: 'ru', variant: '' }];
    // unmanaged: the compositor reports one layout and no switch
    const w = M.planEdit(false, one, { layouts: two });
    assert.strictEqual(w.switchBind, 'alt_shift');
    assert.strictEqual(w.managed, true);
    // managed: the configured domain has one layout and switchBind none
    const cfg = { layouts: [{ layout: 'us', variant: '' }], switchBind: 'none', options: [] };
    assert.strictEqual(M.planEdit(true, one, { layouts: two }, cfg).switchBind, 'alt_shift');
});

test('planEdit: the user\'s switch is never replaced by the default', () => {
    const one = { available: true, layouts: [{ layout: 'us', variant: '' }], switchBind: 'caps', options: [], repeatRate: 25, repeatDelay: 600 };
    const two = [{ layout: 'us', variant: '' }, { layout: 'ru', variant: '' }];
    assert.strictEqual(M.planEdit(false, one, { layouts: two }).switchBind, 'caps');
    // an explicit switchBind in the same edit wins
    assert.strictEqual(M.planEdit(false, Object.assign({}, one, { switchBind: 'none' }), { layouts: two, switchBind: 'none' }).switchBind, 'none');
    // already two layouts with none: the user chose no switch key
    const cfg = { layouts: two, switchBind: 'none', options: [] };
    const three = two.concat([{ layout: 'ua', variant: '' }]);
    assert.ok(!('switchBind' in M.planEdit(true, one, { layouts: three }, cfg)));
});
