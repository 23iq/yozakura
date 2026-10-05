const { test } = require('node:test');
const assert = require('node:assert/strict');
const path = require('node:path');
const { loadLibrary } = require('./lib/qmljs.cjs');

const M = loadLibrary(path.join(__dirname, '../modules/widgets/dashboard/tmux/TmuxModel.js'));
const plain = v => JSON.parse(JSON.stringify(v));

test('tmux command lines', () => {
    assert.deepEqual(plain(M.LIST_SESSIONS), ['tmux', 'list-sessions', '-F', '#{session_name}']);
    assert.deepEqual(plain(M.listWindowsCommand('a b')), ['tmux', 'list-windows', '-t', 'a b', '-F', '#{window_index}:#{window_name}:#{window_active}']);
    assert.equal(M.listPanesCommand('s')[5], '#{pane_index}:#{pane_width}:#{pane_height}:#{pane_top}:#{pane_left}:#{pane_active}:#{pane_current_command}');
    assert.deepEqual(plain(M.killCommand('s')), ['tmux', 'kill-session', '-t', 's']);
    assert.deepEqual(plain(M.renameCommand('s', 'n')), ['tmux', 'rename-session', '-t', 's', 'n']);
    assert.deepEqual(plain(M.selectWindowCommand('s', '2')), ['tmux', 'select-window', '-t', 's:2']);
    assert.deepEqual(plain(M.selectPaneCommand('s', 1)), ['tmux', 'select-pane', '-t', 's.1']);
    assert.equal(M.newSessionShell(''), 'tmux');
    assert.equal(M.newSessionShell(undefined), 'tmux');
    // Session names are data (any local process can create one): quoted for sh.
    assert.equal(M.newSessionShell('dev'), "tmux new -s 'dev'");
    assert.equal(M.attachShell('dev'), "tmux attach-session -t 'dev'");
    assert.equal(M.attachShell("a'b $(id)`x`"), "tmux attach-session -t 'a'\\''b $(id)`x`'");
});

test('parsers', () => {
    assert.deepEqual(plain(M.parseSessions(' main \n\nwork\n')), [
        { name: 'main', isCreateButton: false, icon: 'terminal' },
        { name: 'work', isCreateButton: false, icon: 'terminal' }]);
    assert.deepEqual(plain(M.parseSessions('')), []);
    assert.deepEqual(plain(M.parseWindows('0:zsh:1\nbad\n2:a:0')), [
        { index: '0', name: 'zsh', active: true }, { index: '2', name: 'a', active: false }]);
    const panes = plain(M.parsePanes('0:80:24:0:0:1:nvim\n1:79:11:13:81:0:zsh\nshort:1'));
    assert.equal(panes.length, 2);
    assert.deepEqual(panes[1], { index: '1', width: 79, height: 11, top: 13, left: 81, active: false,
                                 command: 'zsh', totalWidth: 160, totalHeight: 24 });
});

test('session list with create row', () => {
    const s = M.parseSessions('main\nwork\nWorkshop');
    const names = l => plain(l).map(x => x.name);
    assert.deepEqual(names(M.buildSessionList(s, '', true)), ['Create new session', 'main', 'work', 'Workshop']);
    assert.deepEqual(names(M.buildSessionList(s, '', false)), ['main', 'work', 'Workshop']);
    const specific = plain(M.buildSessionList(s, 'wor', true));
    assert.deepEqual(specific.map(x => x.name), ['Create session "wor"', 'work', 'Workshop']);
    assert.equal(specific[0].isCreateSpecificButton, true);
    assert.equal(specific[0].sessionNameToCreate, 'wor');
    const exact = plain(M.buildSessionList(s, 'WORK', true));
    assert.equal(exact[0].isCreateButton, true);
    assert.deepEqual(exact.map(x => x.name).slice(1), ['work', 'Workshop']);
    assert.equal(s.length, 3, 'input untouched');
    assert.deepEqual(plain(M.modelRow(exact[0])), { sessionId: '__create__', sessionData: exact[0] });
    assert.equal(M.modelRow(exact[1]).sessionId, 'work');
    assert.equal(M.isCreateRow(exact[1]), false);
    assert.equal(M.isCreateRow(null), false);
});

test('row geometry', () => {
    assert.equal(M.expandedRowHeight(), 168);
    assert.equal(M.rowHeight(2, 2, false), 168);
    assert.equal(M.rowHeight(2, 2, true), 48);
    assert.equal(M.rowHeight(1, 2, false), 48);
    assert.equal(M.rowY(3, 1, false, 10), 48 + 168 + 48);
    assert.equal(M.rowY(3, 1, true, 10), 144);
    assert.equal(M.rowY(5, -1, false, 2), 96, 'clamped to the row count');
});
