const assert = require('node:assert/strict');
const { test } = require('node:test');
const { loadLibrary } = require('./lib/qmljs.cjs');
const M = loadLibrary('modules/services/ai/ToolMedia.js');
const Hints = loadLibrary('modules/services/ai/ToolHints.js');
const Rows = loadLibrary('modules/services/ai/ChatRows.js');
const P = loadLibrary('modules/services/ai/Permissions.js');
const T = loadLibrary('modules/aicenter/transcript/Transcript.js');
const Timeline = loadLibrary('modules/services/ai/AgentTimeline.js');

const plain = v => JSON.parse(JSON.stringify(v));

test('undo descriptors come from successful JSON results only', () => {
    const text = JSON.stringify({ timer: { id: 't3' }, undo: { tool: 'timer_control', args: { id: 't3', action: 'cancel' } } });
    assert.deepEqual(plain(M.undoFrom('yozakura', text, false)), { server: 'yozakura', tool: 'timer_control', args: { id: 't3', action: 'cancel' } });
    assert.equal(M.undoFrom('yozakura', text, true), null, 'failed calls are not undoable');
    assert.equal(M.undoFrom('yozakura', 'Toggled launcher', false), null);
    assert.equal(M.undoFrom('yozakura', '{"undo":{"args":{}}}', false), null);
    assert.equal(M.undoFrom('yozakura', '{broken', false), null);
    // binds_undo carries a token (E1 advisor)
    const binds = JSON.stringify({ combo: 'SUPER+B', undo: { tool: 'binds_undo', args: { token: 'abc' }, cli: 'x' } });
    assert.equal(M.undoFrom('yozakura', binds, false).tool, 'binds_undo');
});

test('our tools are recognised under every agent naming', () => {
    for (const n of ['mcp__yozakura__timer_start', 'yozakura.timer_start', 'yozakura__binds_set', 'yozakura/x'])
        assert.ok(M.isYozakuraTool(n), n);
    for (const n of ['Bash', 'mcp__github__x', 'yozakurax.y', ''])
        assert.ok(!M.isYozakuraTool(n), n);
});

test('tool images become a user message for vision models', () => {
    const imgs = plain(M.images([{ type: 'text', text: 'hi' }, { type: 'image', data: 'QUJD', mimeType: 'image/jpeg' }]));
    assert.deepEqual(imgs, [{ type: 'image', mimeType: 'image/jpeg', base64: 'QUJD', name: 'tool-image-2' }]);
    const rows = [
        { role: 'user', content: 'what is on screen?' },
        { role: 'assistant', content: '', toolCalls: JSON.stringify([{ id: 'c1', name: 'screen_look', status: 'done', result: 'Screenshot' }]) }
    ];
    const without = plain(Rows.toMessages(rows));
    assert.deepEqual(without.map(m => m.role), ['user', 'assistant', 'tool']);
    const withImgs = plain(Rows.toMessages(rows, { images: { c1: imgs } }));
    assert.deepEqual(withImgs.map(m => m.role), ['user', 'assistant', 'tool', 'user']);
    assert.equal(withImgs[3].attachments[0].base64, 'QUJD');
    assert.match(withImgs[3].content, /screen_look/);
    assert.equal(M.canSee({ images: true }, { images: true }), true);
    assert.equal(M.canSee({ images: false }, { images: true }), false);
    assert.equal(M.canSee({}, { images: false }), false);
});

test('system prompt hints name the tool families the session has', () => {
    const tools = [{ server: 'yozakura', tool: 'binds_search' }, { server: 'yozakura', tool: 'routine_save' }, { server: 'github', tool: 'timer_start' }];
    const out = Hints.withHints('Be brief.', tools);
    assert.match(out, /^Be brief\.\n\nDesktop tools you have:/);
    assert.match(out, /binds_suggest/);
    assert.match(out, /save this as a routine/);
    assert.doesNotMatch(out, /timer_start/, 'only our own server counts');
    assert.equal(Hints.withHints('Be brief.', []), 'Be brief.');
    assert.equal(Hints.withHints('', [{ server: 'yozakura', tool: 'timer_start' }]).indexOf('Desktop tools'), 0);
});

test('keybind writes, closing apps and deleting routines always ask', () => {
    for (const name of ['binds_set', 'binds_remove', 'app_close', 'routine_delete']) {
        const tool = { name, server: 'yozakura' };
        assert.equal(P.decide(tool, { autoApprove: ['read', 'write', 'mcp'], sessionRules: { ['yozakura/' + name]: true } }), 'ask', name);
        assert.equal(P.decide(tool, { yolo: true }), 'ask', name + ' even in yolo');
    }
    assert.equal(P.decide({ name: 'routine_save', server: 'yozakura' }, { autoApprove: ['read', 'write', 'mcp'] }), 'allow');
    assert.equal(P.decide({ name: 'system_info', server: 'yozakura', annotations: { readOnlyHint: true } }, {}), 'allow');
    assert.equal(P.category({ name: 'screen_look', server: 'yozakura', readOnly: true }), 'mcp', 'screen pixels are private');
    assert.equal(P.mustConfirm({ name: 'binds_set', server: 'other' }), false);
});

test('a confirm-only call gets a card without "for session"', () => {
    const rows = plain(T.build('chat', [{ role: 'assistant', content: '', toolCalls: JSON.stringify([
        { id: 'a', name: 'binds_set', tool: 'binds_set', status: 'ask', confirm: true },
        { id: 'b', name: 'dnd_set', tool: 'dnd_set', status: 'ask' }]) }]));
    const perms = rows.filter(r => r.kind === 'permission');
    assert.deepEqual(JSON.parse(perms[0].options), ['allow', 'deny']);
    assert.deepEqual(JSON.parse(perms[1].options), ['allow', 'allow_session', 'deny']);
});

test('agent timelines pick up undo from our tool results', () => {
    const state = Timeline.newState();
    Timeline.apply(state, { kind: 'tool_call', id: 't1', tool: 'mcp__yozakura__timer_start', input: { duration: '10m' } });
    Timeline.apply(state, { kind: 'tool_result', id: 't1', output: '{"undo":{"tool":"timer_control","args":{"id":"t1","action":"cancel"}}}' });
    const block = state.blocks[state.byKey['tool:t1']];
    assert.equal(JSON.parse(block.undo).tool, 'timer_control');
    const row = plain(T.fromBlock(block, 0))[0];
    assert.equal(T.undoOf(row).tool, 'timer_control');

    Timeline.apply(state, { kind: 'tool_call', id: 't2', tool: 'Bash', input: { command: 'ls' } });
    Timeline.apply(state, { kind: 'tool_result', id: 't2', output: '{"undo":{"tool":"rm"}}' });
    assert.equal(state.blocks[state.byKey['tool:t2']].undo, '', 'other tools never get an undo');
});
