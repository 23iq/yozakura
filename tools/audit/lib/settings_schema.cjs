// Dump the settings schema for tools/audit/checks/settings_schema.py:
// every category with its validation problems, keys, legacy sources and
// registry files. Usage: node settings_schema.cjs <repo>
const path = require('node:path');
const repo = process.argv[2];
const { loadLibrary } = require(path.join(repo, 'tests/lib/qmljs.cjs'));
const lib = rel => loadLibrary(path.join(repo, rel));

const Categories = lib('modules/settings/schema/Categories.js');
const SchemaUtil = lib('modules/settings/SchemaUtil.js');
const Defaults = lib('modules/settings/SettingsDefaults.js');
const Registry = lib('modules/settings/Registry.js');
const en = require(path.join(repo, 'translations/en.json'));
const tr = k => (k in en ? en[k] : null);

const grouped = new Set();
for (const g of Categories.groups)
    for (const id of g.categories) grouped.add(id);

const out = {
    groups: Categories.groups.map(g => ({ id: g.id, title: g.title, categories: g.categories })),
    registry: Object.values(Registry.EDITORS).concat(Object.values(Registry.PREVIEWS)),
    categories: Categories.categories.map(c => ({
        id: c.id,
        grouped: grouped.has(c.id),
        legacy: c.legacy ? c.legacy.source : null,
        problems: SchemaUtil.validateCategory(c, Defaults.get, tr, Registry),
        keys: SchemaUtil.flatten([c]).flatMap(x => SchemaUtil.entryKeys(x.entry)),
        links: SchemaUtil.flatten([c]).map(x => x.entry.target).filter(Boolean),
    })),
};
for (const g of Categories.groups)
    for (const id of g.categories)
        if (!Categories.byId(id)) out.categories.push({ id, problems: [`group ${g.id} lists unknown category '${id}'`], keys: [], links: [] });
console.log(JSON.stringify(out));
