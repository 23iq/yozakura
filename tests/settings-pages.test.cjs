// Settings information architecture (spec Addendum 3): every sidebar entry
// opens a page, every setting lives on exactly one page (the page of the
// element it controls) and page titles are unique.
const { test } = require('node:test');
const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');

const qmljs = require('./lib/qmljs.cjs');
const repo = path.join(__dirname, '..');
const Categories = qmljs.loadLibrary(path.join(repo, 'modules/settings/schema/Categories.js'));
const shell = fs.readFileSync(path.join(repo, 'modules/settings/SettingsShell.qml'), 'utf8');

// key -> [category ids] of every entry that reads/writes it.
function owners() {
    const out = {};
    for (const cat of Categories.categories) {
        for (const sec of cat.sections || []) {
            for (const e of sec.entries) {
                const keys = new Set(e.keys || []);
                if (e.key)
                    keys.add(e.key);
                for (const k of keys) {
                    out[k] = out[k] || [];
                    if (out[k].indexOf(cat.id) === -1)
                        out[k].push(cat.id);
                }
            }
        }
    }
    return out;
}

test('every sidebar entry resolves to a page', () => {
    for (const g of Categories.groups) {
        assert.ok(Categories.resolve(g.id), g.id);
        for (const id of g.categories) {
            const c = Categories.resolve(id);
            assert.ok(c && c.id === id, id);
            if (c.page)
                assert.match(shell, new RegExp(`"${c.page}":`), `${id}: page ${c.page} is not mapped in SettingsShell`);
            else
                assert.ok(c.sections && c.sections.length > 0, `${id} has no sections`);
        }
    }
});

test('no legacy panels are hosted any more', () => {
    for (const c of Categories.categories)
        assert.equal(c.legacy, undefined, c.id);
    assert.equal(fs.existsSync(path.join(repo, 'modules/settings/LegacyPanelHost.qml')), false);
    for (const f of ['ThemePanel', 'ShellPanel', 'ModsPanel'])
        assert.equal(fs.existsSync(path.join(repo, 'modules/widgets/dashboard/controls', f + '.qml')), false, f);
    assert.doesNotMatch(shell, /legacyTabs/);
});

test('ids of merged pages open the page that took them over', () => {
    assert.equal(Categories.resolve('surfaces').id, 'appearance');
    assert.equal(Categories.resolve('bar-classic').id, 'bar');
    assert.equal(Categories.resolve('sidebar').id, 'ai');
});

test('a setting is declared on one page only', () => {
    const dup = Object.entries(owners()).filter(([, ids]) => ids.length > 1);
    assert.deepEqual(dup, []);
});

test('settings live on the page of the element they control', () => {
    const own = owners();
    const expect = {
        'layout.dashboard.tabs': 'dashboard',
        'performance.dashboardPersistTabs': 'dashboard',
        'layout.osd.style': 'osd',
        'theme.popup.entry': 'menus',
        'system.timers.notchStyle': 'notch',
        'compositor.motionProfile': 'appearance',
        'compositor.motionDurationScale': 'appearance',
        'theme.animDuration': 'appearance',
        'compositor.rounding': 'appearance',
        'prefix.timers': 'launcher',
        'prefix.clipboard': 'launcher',
        'desktop.blurWallpaperOnOverview': 'overview',
        'overview.style': 'overview',
        'ai.sidebarPinnedOnStartup': 'ai',
        'theme.srBg.opacity': 'appearance',
        'theme.shadowOpacity': 'appearance',
        'notch.liveActivities': 'notch'
    };
    for (const [key, page] of Object.entries(expect))
        assert.deepEqual(own[key], [page], key);
});

test('page titles are unique', () => {
    const seen = {};
    for (const c of Categories.categories) {
        assert.ok(!(c.title in seen), `${c.id} and ${seen[c.title]} share the title ${c.title}`);
        seen[c.title] = c.id;
    }
});
