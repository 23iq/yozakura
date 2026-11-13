// Every config domain can be written on demand. SettingsStore writes a
// domain explicitly when its auto-save is paused (a live settings change in
// a domain the setup wizard is staging, a service's hold) through
// Config.saveDomain(name), which needs the domain's ConfigFile; the staged
// apply (GlobalStates.apply*Changes) calls Config.save<Domain>(). A domain
// without either would keep such an edit in memory only.
const { test } = require('node:test');
const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');

const repo = path.join(__dirname, '..');
const config = fs.readFileSync(path.join(repo, 'config/Config.qml'), 'utf8');
const store = fs.readFileSync(path.join(repo, 'modules/settings/store/SettingsStore.qml'), 'utf8');
const domains = fs.readdirSync(path.join(repo, 'config/defaults'))
    .filter(f => f.endsWith('.js'))
    .map(f => f.slice(0, -3));
const cap = s => s.charAt(0).toUpperCase() + s.slice(1);

test('every domain has a ConfigFile (Config.saveDomain finds it)', () => {
    assert.ok(domains.length > 10);
    const missing = domains.filter(d => !new RegExp(`ConfigFile \\{[^}]*?name: "${d}"`, 's').test(config));
    assert.deepEqual(missing, []);
});

test('every domain has Config.save<Domain>()', () => {
    const missing = domains.filter(d => !config.includes(`function save${cap(d)}()`));
    assert.deepEqual(missing, [], 'theme included');
});

test('Config.saveDomain writes through the ConfigFile, and SettingsStore uses it', () => {
    assert.match(config, /function saveDomain\(name\)/);
    assert.match(config, /f\.writeSynced\(\)/);
    assert.match(store, /Config\.saveDomain\(domain\)/);
});
