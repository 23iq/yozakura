// Settings catalog generator (tools/schema/catalog.cjs -> assets/schema).
const test = require('node:test');
const assert = require('node:assert');
const path = require('node:path');
const { execFileSync } = require('node:child_process');
const { build, metaFor, humanize } = require('../tools/schema/catalog.cjs');

const repo = path.join(__dirname, '..');

test('meta patterns: exact path wins, then the most specific pattern', () => {
    const keys = { 'sr*.opacity': { d: 'glob' }, '*.opacity': { d: 'star' }, 'srBg.opacity': { d: 'exact' } };
    assert.strictEqual(metaFor(keys, 'srBg.opacity').d, 'exact');
    assert.strictEqual(metaFor(keys, 'srPopup.opacity').d, 'glob');
    assert.strictEqual(metaFor(keys, 'other.opacity').d, 'star');
    assert.strictEqual(metaFor(keys, 'srBg.label'), null);
});

test('humanize turns key names into titles', () => {
    assert.strictEqual(humanize('hoverRegionHeight'), 'Hover region height');
    assert.strictEqual(humanize('lock_cmd'), 'Lock cmd');
});

test('catalog builds without errors and describes every key', () => {
    const { files, errors } = build(repo);
    assert.deepStrictEqual(errors, []);
    const combined = Object.values(files).find(f => f.$defs);
    assert.ok(combined, 'combined schema present');
    let leaves = 0;
    const walk = (node, key) => {
        if (node.type === 'object') {
            assert.strictEqual(node.additionalProperties, false, key);
            for (const [k, v] of Object.entries(node.properties)) walk(v, `${key}.${k}`);
            return;
        }
        leaves++;
        assert.ok(node.title && node.description, `${key} has a title and description`);
        assert.ok('default' in node, `${key} has a default`);
        if (node.enum) assert.ok(node.enum.includes(node.default), `${key} default is allowed`);
    };
    for (const [d, def] of Object.entries(combined.$defs)) {
        assert.strictEqual(files[`${d}.schema.json`].$schema, 'https://json-schema.org/draft/2020-12/schema');
        for (const [k, v] of Object.entries(def.properties)) walk(v, `${d}.${k}`);
    }
    assert.ok(leaves > 500, `${leaves} keys`);
    const bar = combined.$defs.bar.properties;
    assert.deepStrictEqual(bar.position.enum, ['top', 'bottom', 'left', 'right']);
    assert.strictEqual(bar.frameThickness['x-settings'].visibleWhen.key, 'bar.frameEnabled');
    assert.strictEqual(bar.layout.properties.style['x-settings'].component, 'BarStyleCards');
});

test('generated files in assets/schema are up to date (make schema)', () => {
    execFileSync('node', [path.join(repo, 'tools/schema/gen_schema.cjs'), '--check'], { stdio: 'pipe' });
});
