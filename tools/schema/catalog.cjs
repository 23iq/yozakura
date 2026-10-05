// Builds the settings catalog (JSON Schema 2020-12) from the three sources
// of truth: config/defaults/*.js (keys, defaults, types), the settings v2
// schema modules/settings/schema/*.js (labels, descriptions, options,
// ranges, visibleWhen) and config/meta/*.js (everything the settings UI does
// not declare). Pure: build(repo) returns {files: {name: object}, errors}.
// CLI: tools/schema/gen_schema.cjs.
'use strict';
const fs = require('node:fs');
const path = require('node:path');

const DRAFT = 'https://json-schema.org/draft/2020-12/schema';

function loader(repo) {
    const { loadLibrary } = require(path.join(repo, 'tests/lib/qmljs.cjs'));
    const cache = new Map();
    return rel => loadLibrary(path.join(repo, rel), cache);
}

function kindOf(v) {
    if (v === null || v === undefined) return 'null';
    if (Array.isArray(v)) return 'array';
    return typeof v === 'object' ? 'object' : typeof v;
}

function plain(v) {
    return v === undefined ? undefined : JSON.parse(JSON.stringify(v));
}

// One path segment of a meta pattern: "*" matches any segment, "sr*" any
// segment starting with "sr".
function segMatch(pat, seg) {
    if (!pat.includes('*')) return pat === seg;
    const re = new RegExp('^' + pat.split('*').map(s => s.replace(/[.+?^${}()|[\]\\]/g, '\\$&')).join('.*') + '$');
    return re.test(seg);
}

// Exact paths win over patterns; among patterns the one with fewer wildcard
// segments, then the one with more literal characters ("sr*" beats "*").
function metaFor(keys, p) {
    if (Object.prototype.hasOwnProperty.call(keys, p)) return keys[p];
    const parts = p.split('.');
    let best = null;
    let bestRank = Infinity;
    for (const pat of Object.keys(keys)) {
        if (!pat.includes('*')) continue;
        const pp = pat.split('.');
        if (pp.length !== parts.length) continue;
        if (!pp.every((seg, i) => segMatch(seg, parts[i]))) continue;
        const rank = pp.filter(s => s.includes('*')).length * 1000 - pat.replace(/\*/g, '').length;
        if (rank < bestRank) {
            best = keys[pat];
            bestRank = rank;
        }
    }
    return best;
}

function patternMatchesSomething(defaults, pat) {
    const walk = (node, segs) => {
        if (!segs.length) return true;
        if (kindOf(node) !== 'object') return false;
        const [head, ...rest] = segs;
        return Object.keys(node).some(k => segMatch(head, k) && walk(node[k], rest));
    };
    return walk(defaults, pat.split('.'));
}

// Settings entries indexed by config key: {entry, primary, category, section}.
function settingsIndex(lib) {
    const Categories = lib('modules/settings/schema/Categories.js');
    const SchemaUtil = lib('modules/settings/SchemaUtil.js');
    const out = {};
    for (const { entry, section, category } of SchemaUtil.flatten(Categories.categories)) {
        SchemaUtil.entryKeys(entry).forEach(key => {
            if (out[key] && out[key].primary) return;
            out[key] = { entry, primary: entry.key === key, category, section };
        });
    }
    const categories = Categories.categories.map(c => ({ id: c.id, title: c.title, description: c.description }));
    return { byKey: out, categories, groups: Categories.groups };
}

function humanize(name) {
    const words = name.replace(/_/g, ' ').replace(/([a-z0-9])([A-Z])/g, '$1 $2').toLowerCase();
    return words.charAt(0).toUpperCase() + words.slice(1);
}

function inferItems(arr) {
    if (!arr.length) return undefined;
    const kinds = new Set(arr.map(kindOf));
    if (kinds.size !== 1) return undefined;
    const k = [...kinds][0];
    return k === 'null' ? undefined : { type: k };
}

function applySettings(node, s, tr, isLeaf) {
    const e = s.entry;
    const got = { title: !!tr(e.label), description: !!tr(e.description) };
    const x = { category: s.category.id, section: s.section.id };
    if (e.label) x.label = e.label;
    if (!s.primary) {
        // Composite entry (one control for several keys): keep the key's own
        // title/description, link the entry.
        x.entry = e.id || e.key;
        if (tr(e.label)) x.entryTitle = tr(e.label);
        if (e.keywords) x.keywords = e.keywords;
        node['x-settings'] = x;
        return { title: false, description: false };
    }
    if (tr(e.label)) node.title = tr(e.label);
    if (tr(e.description)) node.description = tr(e.description);
    x.control = e.type;
    for (const f of ['component', 'preview', 'step', 'unit', 'keywords', 'visibleWhen', 'enabledWhen'])
        if (e[f] !== undefined) x[f] = plain(e[f]);
    if (e.min !== undefined) x.min = e.min;
    if (e.max !== undefined) x.max = e.max;
    if (e.specialValues) x.specialValues = e.specialValues.map(v => ({ value: v.value, label: tr(v.label) || v.label }));
    node['x-settings'] = x;
    if (isLeaf && e.options && e.options.length) {
        const labels = Object.fromEntries(e.options.map(o => [String(o.value), tr(o.label) || o.label]));
        if (e.type === 'multiselect') {
            // An array of option values (e.g. weekdays)
            node.items = { enum: e.options.map(o => o.value) };
            node.uniqueItems = true;
            node['x-itemLabels'] = labels;
        } else {
            node.enum = e.options.map(o => o.value);
            node['x-enumLabels'] = labels;
        }
    }
    if (isLeaf && (e.type === 'slider' || e.type === 'number')) {
        if (e.min !== undefined) node.minimum = e.min;
        if (e.max !== undefined) node.maximum = e.max;
    }
    return got;
}

// The settings schema's translated label/description win over config/meta.
function applyMeta(node, m, where, errors, fromSettings) {
    if (m.title && !(fromSettings && fromSettings.title)) node.title = m.title;
    if (m.description && !(fromSettings && fromSettings.description)) node.description = m.description;
    if (m.enum) {
        const vals = plain(m.enum);
        if (node.enum && JSON.stringify([...node.enum].sort()) !== JSON.stringify([...vals].sort()))
            errors.push(`${where}: config/meta enum ${JSON.stringify(vals)} differs from the settings options ${JSON.stringify(node.enum)}`);
        if (!node.enum) node.enum = vals;
    }
    if (m.min !== undefined) node.minimum = m.min;
    if (m.max !== undefined) node.maximum = m.max;
    if (m.unit) node['x-unit'] = m.unit;
    if (m.pattern) node.pattern = m.pattern;
    if (m.format) node.format = m.format;
    if (m.items) node.items = plain(m.items);
    if (m.uniqueItems) node.uniqueItems = true;
    if (m.secret) node['x-secret'] = true;
    if (m.local) node['x-local'] = true;
    if (m.readOnly) node.readOnly = true;
    if (m.special) node['x-specialValues'] = plain(m.special).map(v => (typeof v === 'object' ? v : { value: v, label: '' }));
}

// Sentinel values (e.g. -1 = inherit/auto) allowed besides the range or enum.
function specialsOf(node) {
    const out = [];
    for (const list of [node['x-settings'] && node['x-settings'].specialValues, node['x-specialValues']])
        for (const v of list || []) if (!out.some(o => o === v.value)) out.push(v.value);
    return out;
}

// JSON Schema form of "range or sentinel": when a sentinel lies outside the
// range, the range moves into anyOf (x-range keeps it readable for tools).
function applySpecials(node) {
    const specials = specialsOf(node);
    if (!specials.length || node.enum) return;
    const lo = node.minimum;
    const hi = node.maximum;
    const outside = specials.filter(v => typeof v === 'number' && ((lo !== undefined && v < lo) || (hi !== undefined && v > hi)));
    if (!outside.length) return;
    const range = { type: 'number' };
    if (lo !== undefined) range.minimum = lo;
    if (hi !== undefined) range.maximum = hi;
    node.anyOf = [range, { enum: outside }];
    node['x-range'] = { min: lo, max: hi };
    delete node.minimum;
    delete node.maximum;
}

function checkDefault(node, where, errors) {
    const d = node.default;
    if (specialsOf(node).includes(d)) return;
    if (node.enum && !node.enum.includes(d)) errors.push(`${where}: default ${JSON.stringify(d)} is not in enum ${JSON.stringify(node.enum)}`);
    if (typeof d === 'number') {
        if (node.minimum !== undefined && d < node.minimum) errors.push(`${where}: default ${d} < minimum ${node.minimum}`);
        if (node.maximum !== undefined && d > node.maximum) errors.push(`${where}: default ${d} > maximum ${node.maximum}`);
    }
    if (Array.isArray(d) && node.items && node.items.enum)
        d.filter(v => !node.items.enum.includes(v)).forEach(v => errors.push(`${where}: default item ${JSON.stringify(v)} is not in items.enum`));
}

function buildNode(ctx, domain, p, value) {
    const where = `${domain}.${p}`;
    const k = kindOf(value);
    const node = { title: humanize(p.split('.').pop()) };
    const s = ctx.settings.byKey[where];
    const m = metaFor(ctx.metaKeys, p);
    if (k === 'object') {
        node.type = 'object';
        const got = s ? applySettings(node, s, ctx.tr, false) : null;
        if (m) applyMeta(node, m, where, ctx.errors, got);
        node.properties = {};
        for (const key of Object.keys(value)) node.properties[key] = buildNode(ctx, domain, `${p}.${key}`, value[key]);
        node.additionalProperties = false;
        return node;
    }
    if (k !== 'null') node.type = k;
    node.default = plain(value);
    if (k === 'array') {
        const items = inferItems(value);
        if (items) node.items = items;
    }
    const got = s ? applySettings(node, s, ctx.tr, true) : null;
    if (m) applyMeta(node, m, where, ctx.errors, got);
    checkDefault(node, where, ctx.errors);
    applySpecials(node);
    return node;
}

function build(repo) {
    const lib = loader(repo);
    const errors = [];
    const en = JSON.parse(fs.readFileSync(path.join(repo, 'translations/en.json'), 'utf8'));
    const tr = key => (key && Object.prototype.hasOwnProperty.call(en, key) ? en[key] : null);
    const Brand = lib('modules/globals/BrandActions.js');
    const Meta = lib('config/meta/Meta.js');
    const settings = settingsIndex(lib);
    const domains = fs.readdirSync(path.join(repo, 'config/defaults'))
        .filter(f => f.endsWith('.js')).map(f => f.slice(0, -3)).sort();
    const files = {};
    const defs = {};
    for (const domain of domains) {
        const data = plain(lib(`config/defaults/${domain}.js`).data);
        const meta = Meta.domains[domain] || { keys: {} };
        const metaKeys = meta.keys || {};
        for (const pat of Object.keys(metaKeys))
            if (!patternMatchesSomething(data, pat)) errors.push(`config/meta: ${domain}.${pat} matches no key of config/defaults/${domain}.js`);
        const ctx = { settings, metaKeys, tr, errors };
        const props = {};
        for (const key of Object.keys(data)) props[key] = buildNode(ctx, domain, key, data[key]);
        const schema = {
            $schema: DRAFT,
            $id: `urn:${Brand.appId}:config:${domain}`,
            title: domain,
            description: meta.description || `${humanize(domain)} settings.`,
            type: 'object',
            'x-file': `config/${domain}.json`,
            properties: props,
            additionalProperties: false,
        };
        files[`${domain}.schema.json`] = schema;
        defs[domain] = Object.assign({}, schema);
        delete defs[domain].$schema;
    }
    for (const key of Object.keys(settings.byKey)) {
        const domain = key.split('.')[0];
        if (domain !== 'wallpaper' && !domains.includes(domain)) errors.push(`settings schema key ${key}: unknown domain`);
    }
    files[`${Brand.appId}.schema.json`] = {
        $schema: DRAFT,
        $id: `urn:${Brand.appId}:config`,
        title: `${Brand.displayName} configuration`,
        description: `Every config domain of ${Brand.displayName}. One JSON file per domain in $XDG_CONFIG_HOME/${Brand.appId}/config/<domain>.json; keys are addressed as <domain>.<dotted.path>. Generated by tools/schema/gen_schema.cjs - do not edit.`,
        type: 'object',
        properties: Object.fromEntries(domains.map(d => [d, { $ref: `#/$defs/${d}` }])),
        $defs: defs,
        'x-categories': settings.categories.map(c => ({ id: c.id, title: tr(c.title) || c.title, description: tr(c.description) || c.description })),
        'x-groups': settings.groups.map(g => ({ id: g.id, title: tr(g.title) || g.title, categories: g.categories })),
    };
    return { files, errors };
}

module.exports = { build, metaFor, humanize, kindOf };
