const { test } = require('node:test');
const assert = require('node:assert/strict');
const fs = require('node:fs');
const vm = require('node:vm');
const path = require('node:path');
const out = {};
const file = path.join(__dirname, '../modules/services/YozdOutput.js');
if (fs.existsSync(file)) vm.runInNewContext(fs.readFileSync(file, 'utf8').replace(/^\.pragma library\s*/, ''), out);

test('JSON output parses', () => {
    assert.equal(typeof out.parse, 'function');
    const r = out.parse(' [[{"name":"windows"}],[]]\n');
    assert.equal(r.ok, true);
    assert.equal(r.value.length, 2);
    assert.equal(out.parse('{"id":3}').value.id, 3);
});

test('a daemon error printed with exit 0 is reported, not thrown', () => {
    const r = out.parse('Error connecting to daemon: dial unix /run/user/1000/yozd.sock: connect: connection refused\n');
    assert.equal(r.ok, false);
    assert.equal(r.value, null);
    assert.match(r.error, /Error connecting to daemon/);
});

test('empty and malformed output are reported', () => {
    assert.equal(out.parse('').ok, false);
    assert.equal(out.parse(undefined).ok, false);
    const r = out.parse('{"id":');
    assert.equal(r.ok, false);
    assert.match(r.error, /invalid JSON/);
});
