const { test } = require('node:test');
const assert = require('node:assert/strict');
const path = require('node:path');
const { loadLibrary } = require('./lib/qmljs.cjs');

const V = loadLibrary(path.join(__dirname, '../modules/services/UpdateVersions.js'));

test('versions compare numerically, pre-releases below their release', () => {
    assert.equal(V.isNewer('0.1.10', '0.1.9'), true);
    assert.equal(V.isNewer('0.2', '0.1.9'), true);
    assert.equal(V.isNewer('0.1.2', '0.1.2-rc1'), true);
    assert.equal(V.isNewer('0.1.2-rc2', '0.1.2-rc1'), true);
    assert.equal(V.isNewer('0.1.2-rc1', '0.1.2'), false);
    assert.equal(V.isNewer('0.1.2', '0.1.2'), false);
    assert.equal(V.isNewer('v0.1.3', '0.1.2'), true);
    assert.equal(V.isNewer('nightly', '0.1.2'), false);
});

test('latest picks the highest tag whatever the order; pre-releases only for pre-release installs', () => {
    const tags = [{ name: 'v0.1.1' }, { name: 'v0.2.0-rc1' }, { name: 'v0.1.10' }, { name: 'junk' }, { name: 'v0.1.9' }];
    assert.equal(V.latest(tags, '0.1.2'), '0.1.10');
    assert.equal(V.latest(tags, '0.1.2-rc1'), '0.2.0-rc1');
    assert.equal(V.latest([], '0.1.2'), '');
    assert.equal(V.latest(null, '0.1.2'), '');
});
