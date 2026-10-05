#!/usr/bin/env node
// Generate the settings catalog into assets/schema/ (see catalog.cjs).
//   node tools/schema/gen_schema.cjs           write the files (`make schema`)
//   node tools/schema/gen_schema.cjs --check   exit 1 if they are stale
//   node tools/schema/gen_schema.cjs --stdout  print the combined schema
'use strict';
const fs = require('node:fs');
const path = require('node:path');
const { build } = require('./catalog.cjs');

const repo = path.resolve(__dirname, '../..');
const outDir = path.join(repo, 'assets/schema');
const mode = process.argv[2] || '';

const { files, errors } = build(repo);
if (errors.length) {
    for (const e of errors) console.error(`error: ${e}`);
    process.exit(2);
}
const text = obj => JSON.stringify(obj, null, 2) + '\n';

if (mode === '--stdout') {
    const combined = Object.keys(files).find(n => files[n].$defs);
    process.stdout.write(text(files[combined]));
    process.exit(0);
}

const existing = fs.existsSync(outDir) ? fs.readdirSync(outDir).filter(f => f.endsWith('.schema.json')) : [];
if (mode === '--check') {
    const stale = Object.keys(files).filter(n => {
        const p = path.join(outDir, n);
        return !fs.existsSync(p) || fs.readFileSync(p, 'utf8') !== text(files[n]);
    });
    const extra = existing.filter(n => !(n in files));
    for (const n of stale) console.log(`stale: assets/schema/${n}`);
    for (const n of extra) console.log(`extra: assets/schema/${n}`);
    process.exit(stale.length || extra.length ? 1 : 0);
}

fs.mkdirSync(outDir, { recursive: true });
for (const n of existing) if (!(n in files)) fs.unlinkSync(path.join(outDir, n));
for (const [n, obj] of Object.entries(files)) fs.writeFileSync(path.join(outDir, n), text(obj));
console.log(`wrote ${Object.keys(files).length} files to assets/schema/`);
