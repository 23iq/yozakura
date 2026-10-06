const { test } = require('node:test');
const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');
const { loadLibrary } = require('./lib/qmljs.cjs');
const Permissions = loadLibrary(path.join(__dirname, '../modules/services/ai/Permissions.js'));

// Read the Go list from source so the two never drift apart.
const goSrc = fs.readFileSync(path.join(__dirname, '../backend/pkg/svc/routines/confirm.go'), 'utf8');
const block = goSrc.match(/var ConfirmTools = map\[string\]bool\{([\s\S]*?)\n\}/)[1];
const goTools = [...block.matchAll(/"([a-z_]+)":\s*true/g)].map(m => m[1]);

test('Permissions.js confirms every Go ConfirmTools entry', () => {
    assert.ok(goTools.length >= 6, `parsed ${goTools.length} Go entries`);
    for (const name of goTools)
        assert.equal(Permissions.mustConfirm({ name, server: 'yozakura' }, {}, []), true, name);
    assert.equal(Permissions.mustConfirm({ name: 'extras_install', server: 'other' }, {}, []), false);
});
