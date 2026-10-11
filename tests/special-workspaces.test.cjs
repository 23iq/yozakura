const { test } = require('node:test');
const assert = require('node:assert/strict');
const fs = require('node:fs');
const vm = require('node:vm');
const path = require('node:path');
const parser = {};
vm.runInNewContext(fs.readFileSync(path.join(__dirname, '../modules/bar/workspaces/SpecialWorkspaces.js'), 'utf8').replace(/^\.pragma library\s*/, ''), parser);
const names = monitors => JSON.parse(JSON.stringify(parser.namesFromMonitors(monitors)));

test('closed or missing special workspaces have no label', () => {
    assert.deepEqual(names([]), {});
    assert.deepEqual(names([{name: 'DP-1'}, {name: 'DP-2', specialWorkspace: {id: 0, name: ''}}]), {});
});
test('names are parsed separately for each monitor', () => {
    assert.deepEqual(names([
        {name: 'DP-1', specialWorkspace: {id: -94, name: 'special:Telegram'}},
        {name: 'DP-2', specialWorkspace: {id: -95, name: 'special:Dev'}},
        {name: 'DP-3', specialWorkspace: {id: -96, name: 'special:Discord'}}
    ]), {'DP-1': 'Telegram', 'DP-2': 'Dev', 'DP-3': 'Discord'});
});
test('only the leading prefix is removed; Unicode and colons survive', () => {
    assert.deepEqual(names([{name: 'DP-1', specialWorkspace: {id: -2, name: 'special:Разработка:special:API'}}]), {'DP-1': 'Разработка:special:API'});
});
test('the unnamed scratchpad gets a readable fallback', () => {
    assert.deepEqual(names([{name: 'DP-1', specialWorkspace: {id: -99, name: 'special:'}}]), {'DP-1': 'special'});
});
test('regular workspaces are never treated as special', () => {
    assert.deepEqual(names([{name: 'DP-1', specialWorkspace: {id: 2, name: 'Dev'}}]), {});
});
test('the shown workspace is the open special, else the active one', () => {
    const shown = (ws, id, special) => parser.isShown(ws, id, special);
    assert.equal(shown({id: 1, name: '1'}, 1, ''), true);
    assert.equal(shown({id: 2, name: '2'}, 1, ''), false);
    assert.equal(shown({id: -96, name: 'special:Dev'}, 1, ''), false);
    assert.equal(shown({id: -96, name: 'special:Dev'}, 1, 'Dev'), true);
    assert.equal(shown({id: 1, name: '1'}, 1, 'Dev'), false, 'the special covers the active workspace');
    assert.equal(shown({id: -97, name: 'special:Telegram'}, 1, 'Dev'), false);
    assert.equal(shown({id: -99, name: 'special:'}, 1, 'special'), true);
    assert.equal(shown(null, 1, ''), false);
});
