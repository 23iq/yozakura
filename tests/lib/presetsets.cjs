// Built-in preset sets for tests (the on-disk format of the backend,
// backend/pkg/presets): assets/presets/{layouts,styles,palettes}/<Name> are
// parts, assets/presets/sets/<Name>/set.json names one of each, plus optional
// domain override files. A set's config = deep merge of layout -> style ->
// palette -> set overrides (objects merge, arrays and scalars replace). A
// folder without set.json is a legacy self-contained set. Mirrored in
// presetsets.py.
const fs = require('node:fs');
const path = require('node:path');

const OFFICIAL = path.join(__dirname, '../../assets/presets');
const KINDS = ['layout', 'style', 'palette'];
const KIND_DIRS = { layout: 'layouts', style: 'styles', palette: 'palettes' };
// Which part owns a key: layout = these domains, palette = wallpaper plus
// theme.lightMode/oledMode, style = everything else.
const LAYOUT_DOMAINS = ['bar', 'notch', 'dock', 'layout', 'overview'];
const PALETTE_THEME_KEYS = ['lightMode', 'oledMode'];
const NOT_DOMAINS = new Set(['info', 'set']);

const isObj = v => v !== null && typeof v === 'object' && !Array.isArray(v);

function deepMerge(base, over) {
    const out = isObj(base) ? { ...base } : {};
    for (const [k, v] of Object.entries(over || {}))
        out[k] = isObj(v) && isObj(out[k]) ? deepMerge(out[k], v) : v;
    return out;
}

const dirs = dir => (fs.existsSync(dir) ? fs.readdirSync(dir).filter(n => fs.statSync(path.join(dir, n)).isDirectory()).sort() : []);
const readJson = f => JSON.parse(fs.readFileSync(f, 'utf8'));

// {domain: object} of a folder's *.json, minus info.json and set.json.
function domains(folder) {
    const out = {};
    for (const f of fs.readdirSync(folder).filter(f => f.endsWith('.json')).sort()) {
        const name = f.slice(0, -5);
        if (!NOT_DOMAINS.has(name))
            out[name] = readJson(path.join(folder, f));
    }
    return out;
}

function info(folder) {
    const f = path.join(folder, 'info.json');
    return fs.existsSync(f) ? readJson(f) : {};
}

// Set folders: <dir>/sets/<Name>, or (no sets/) every <dir>/<Name> as a legacy set.
function setDir(dir) {
    return fs.existsSync(path.join(dir, 'sets')) ? path.join(dir, 'sets') : dir;
}

function listSets(dir = OFFICIAL) {
    return dirs(setDir(dir));
}

function listParts(kind, dir = OFFICIAL) {
    return dirs(path.join(dir, KIND_DIRS[kind]));
}

// A part's folder, matched case-insensitively; null when missing.
function partDir(kind, name, dir = OFFICIAL) {
    const want = String(name).toLowerCase();
    const hit = listParts(kind, dir).find(n => n.toLowerCase() === want);
    return hit === undefined ? null : path.join(dir, KIND_DIRS[kind], hit);
}

// The set.json of a set folder, or null for a legacy set.
function setRefs(folder) {
    const f = path.join(folder, 'set.json');
    return fs.existsSync(f) ? readJson(f) : null;
}

// {refs, domains} of a set folder (the parts come from `dir`).
function composeFolder(folder, dir = OFFICIAL) {
    const refs = setRefs(folder);
    if (!refs)
        return { refs: null, domains: domains(folder) };
    let out = {};
    const layer = d => {
        for (const [dom, obj] of Object.entries(d))
            out[dom] = deepMerge(out[dom], obj);
    };
    for (const kind of KINDS) {
        const p = partDir(kind, refs[kind], dir);
        if (!p)
            throw new Error(`${path.basename(folder)}: ${kind} "${refs[kind]}" not found`);
        layer(domains(p));
    }
    layer(domains(folder));
    return { refs, domains: out };
}

function composeSet(name, dir = OFFICIAL) {
    return composeFolder(path.join(setDir(dir), name), dir).domains;
}

// The part kind that owns domain.key ("" key = the whole domain file).
function ownerOf(domain, key) {
    if (LAYOUT_DOMAINS.includes(domain))
        return 'layout';
    if (domain === 'wallpaper' || (domain === 'theme' && PALETTE_THEME_KEYS.includes(key)))
        return 'palette';
    return 'style';
}

module.exports = {
    OFFICIAL, KINDS, KIND_DIRS, LAYOUT_DOMAINS, PALETTE_THEME_KEYS,
    deepMerge, domains, info, listSets, listParts, partDir, setRefs, composeFolder, composeSet, ownerOf
};
