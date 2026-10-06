const { test } = require('node:test');
const assert = require('node:assert/strict');
const path = require('node:path');
const { loadLibrary } = require('./lib/qmljs.cjs');
const Permissions = loadLibrary(path.join(__dirname, '../modules/services/ai/Permissions.js'));
const plain = value => JSON.parse(JSON.stringify(value));

test('built-in approval descriptors describe concrete changes and preserve typed values', () => {
    assert.deepEqual(plain(Permissions.summaryDescriptor('config_set', { domain: 'bar', key: 'enabled', value: false }, 'yozakura')),
        { key: 'ai.permission_config_set', values: ['bar.enabled', 'false'] });
    assert.deepEqual(plain(Permissions.summaryDescriptor('config_set', { domain: 'bar', key: 'layout.left', value: [] }, 'yozakura')),
        { key: 'ai.permission_config_set', values: ['bar.layout.left', '[]'] });
    assert.deepEqual(plain(Permissions.summaryDescriptor('config_set', { key: 'theme.glass', value: { enabled: true } }, 'yozakura')),
        { key: 'ai.permission_config_set', values: ['theme.glass', '{"enabled":true}'] });
    assert.deepEqual(plain(Permissions.summaryDescriptor('preset_apply', { name: 'Sumi-e' }, 'yozakura')),
        { key: 'ai.permission_preset_apply', values: ['Sumi-e'] });
    assert.deepEqual(plain(Permissions.summaryDescriptor('window_move_to_workspace', { id: '42', workspace: 3, follow: true }, 'yozakura')),
        { key: 'ai.permission_window_follow', values: ['42', '3'] });
});

test('summaries translate their descriptions and describe default window targeting', () => {
    const translate = (key, values) => key === 'ai.permission_focused_window' ? 'active window' : `${key}: ${values.join(' / ')}`;
    assert.equal(Permissions.summarize('window_move_to_workspace', { workspace: 'special:scratch' }, translate, 'yozakura'),
        'ai.permission_window_move: active window / special:scratch');
    assert.equal(Permissions.summarize('config_set', { key: 'bar.position', value: 'bottom' }, translate, 'yozakura'),
        'ai.permission_config_set: bar.position / bottom');
});

test('unknown and third-party tools retain their names and raw argument details', () => {
    assert.equal(Permissions.summaryDescriptor('config_set', { key: 'secret', value: 1 }, 'external'), null);
    assert.equal(Permissions.summarize('config_set', { key: 'secret', value: 1 }, null, 'external'),
        'config_set · {"key":"secret","value":1}');
    assert.equal(Permissions.summarize('mystery', { action: 'execute', target: 'example' }),
        'mystery · {"action":"execute","target":"example"}');
});
