const { test } = require('node:test');
const assert = require('node:assert/strict');
const path = require('node:path');
const { loadLibrary: loadQmlJs } = require('./lib/qmljs.cjs');

const load = file => loadQmlJs(path.join(__dirname, file));
const plain = value => JSON.parse(JSON.stringify(value));

const Markdown = load('../modules/aicenter/lib/Markdown.js');
const Highlight = load('../modules/aicenter/lib/Highlight.js');
const Diff = load('../modules/aicenter/lib/Diff.js');
const Timeline = load('../modules/services/ai/AgentTimeline.js');
const Templates = load('../modules/services/ai/Templates.js');
const Cron = load('../modules/services/ai/Cron.js');
const Permissions = load('../modules/services/ai/Permissions.js');
const Automations = load('../modules/services/ai/Automations.js');
const Urls = load('../modules/globals/Urls.js');

// ── Markdown ────────────────────────────────────────────────────────────

test('markdown: text and fenced code segments', () => {
    const segs = plain(Markdown.segments('Hello\n\n```go\nfunc main() {}\n```\nBye'));
    assert.deepEqual(segs.map(s => s.type), ['text', 'code', 'text']);
    assert.equal(segs[1].language, 'go');
    assert.equal(segs[1].content, 'func main() {}');
    assert.equal(segs[1].open, false);
});

test('markdown: unclosed fence while streaming is an open code block', () => {
    const segs = plain(Markdown.segments('Run:\n```sh\nls -la'));
    assert.equal(segs[1].type, 'code');
    assert.equal(segs[1].open, true);
    assert.equal(segs[1].content, 'ls -la');
});

test('markdown: <think> blocks from local models become thinking segments', () => {
    const segs = plain(Markdown.segments('<think>plan it</think>Answer'));
    assert.deepEqual(segs.map(s => s.type), ['thinking', 'text']);
    assert.equal(segs[0].content, 'plan it');
    const open = plain(Markdown.segments('<think>still thinking'));
    assert.equal(open[0].open, true);
});

test('markdown: longer fences and tildes, nested backticks', () => {
    const segs = plain(Markdown.segments('````md\n```js\nx\n```\n````'));
    assert.equal(segs.length, 1);
    assert.equal(segs[0].content, '```js\nx\n```');
    assert.equal(plain(Markdown.segments('~~~\na\n~~~'))[0].type, 'code');
});

test('markdown: preview strips markup and truncates on a word', () => {
    assert.equal(Markdown.preview('**Bold** `code` [link](http://x)'), 'Bold code link');
    const p = Markdown.preview('word '.repeat(40), 20);
    assert.ok(p.length <= 20 && p.endsWith('…'));
    assert.equal(Markdown.escapeHtml('<a href="x">&'), '&lt;a href=&quot;x&quot;&gt;&amp;');
});

// ── Highlight ───────────────────────────────────────────────────────────

test('highlight: keywords, strings, comments, numbers, functions', () => {
    const toks = plain(Highlight.tokenizeLine('const x = foo("a") // hi 42', 'js', Highlight.newState()));
    const kinds = Object.fromEntries(toks.filter(t => t.k).map(t => [t.t.trim(), t.k]));
    assert.equal(kinds.const, 'kw');
    assert.equal(kinds.foo, 'fn');
    assert.equal(kinds['"a"'], 'str');
    assert.equal(kinds['// hi 42'], 'com');
});

test('highlight: block comments span lines; html is escaped and colored', () => {
    const lines = Highlight.highlightLines('/* a\nb */ x <y>', 'c', { com: '#111', kw: '#222' });
    assert.ok(lines[0].includes('color:#111'));
    assert.ok(lines[1].includes('&lt;y&gt;'));
    assert.equal(Highlight.language('TypeScript'), 'js');
    assert.equal(Highlight.languageForPath('a/b/main.go'), 'go');
    assert.equal(Highlight.languageForPath('README'), 'text');
});

test('highlight: python triple quotes continue across lines', () => {
    const st = Highlight.newState();
    Highlight.tokenizeLine('x = """doc', 'python', st);
    const t = plain(Highlight.tokenizeLine('still"""; y = 1', 'python', st));
    assert.equal(t[0].k, 'str');
    assert.ok(t.some(x => x.k === 'num'));
});

// ── Diff ────────────────────────────────────────────────────────────────

test('diff: git diff with two files', () => {
    const text = [
        'diff --git a/hello.txt b/hello.txt', 'index 45b983b..3b18e51 100644', '--- a/hello.txt', '+++ b/hello.txt',
        '@@ -1 +1 @@', '-hi', '+hello world',
        'diff --git a/b.go b/b.go', '--- a/b.go', '+++ b/b.go', '@@ -1,3 +1,3 @@', ' package b', '--- removed', '+++ added', ' end'
    ].join('\n');
    const files = plain(Diff.parse(text));
    assert.equal(files.length, 2);
    assert.equal(files[0].path, 'hello.txt');
    assert.deepEqual([files[0].added, files[0].removed], [1, 1]);
    // "--- removed" inside a hunk is a deletion, not a header
    assert.deepEqual([files[1].added, files[1].removed], [1, 1]);
    assert.deepEqual(plain(Diff.stats(files)), { files: 2, added: 2, removed: 2 });
    const rows = plain(Diff.rows(files));
    assert.equal(rows[0].kind, 'hunk');
    assert.equal(rows[2].newNo, 1);
});

test('diff: headerless structuredPatch lines and no-newline notes', () => {
    const files = plain(Diff.parse('-hi\n\\ No newline at end of file\n+hello world', 'hello.txt'));
    assert.equal(files[0].path, 'hello.txt');
    assert.deepEqual(files[0].hunks[0].lines.map(l => l.kind), ['del', 'note', 'add']);
});

test('diff: unified() builds a parseable patch from snapshots', () => {
    const patch = Diff.unified('a\nb\nc\nd', 'a\nB\nc\nd\ne', 'f.txt');
    const files = plain(Diff.parse(patch));
    assert.equal(files[0].path, 'f.txt');
    assert.deepEqual([files[0].added, files[0].removed], [2, 1]);
    assert.equal(Diff.unified('same', 'same', 'x'), '');
});

// ── Agent timeline ──────────────────────────────────────────────────────

function run(events) {
    const st = Timeline.newState();
    const results = events.map((e, i) => Timeline.apply(st, Object.assign({ seq: i + 1 }, e)));
    return { st, results };
}

test('timeline: streamed text deltas update one block', () => {
    const { st, results } = run([
        { kind: 'user', text: 'hi' },
        { kind: 'text', text: 'Hel', delta: true },
        { kind: 'text', text: 'lo', delta: true },
    ]);
    assert.equal(st.blocks.length, 2);
    assert.equal(st.blocks[1].text, 'Hello');
    assert.equal(results[2].ops[0].op, 'update');
});

test('timeline: tool call, result, diff and permission flow', () => {
    const { st } = run([
        { kind: 'text', text: 'Editing', delta: true },
        { kind: 'tool_call', id: 't1', tool: 'Edit', title: 'Edit a.txt', category: 'write', input: { file_path: 'a.txt' } },
        { kind: 'permission_request', id: 't1', tool: 'Edit', title: 'Edit a.txt', category: 'write' },
        { kind: 'permission_resolved', id: 't1', decision: 'allow_session' },
        { kind: 'diff', id: 't1', path: 'a.txt', diff: '@@ -1 +1 @@\n-a\n+b' },
        { kind: 'tool_result', id: 't1', output: 'ok' },
        { kind: 'text', text: 'Done', delta: true },
        { kind: 'done', usage: { inputTokens: 5 } },
    ]);
    const types = plain(st.blocks.map(b => b.type));
    assert.deepEqual(types, ['assistant', 'tool', 'permission', 'assistant']);
    assert.equal(st.blocks[2].linked, true); // card belongs to the tool row
    assert.equal(st.blocks[1].decision, 'allow_session');
    const tool = st.blocks[1];
    assert.equal(tool.status, 'done');
    assert.equal(tool.path, 'a.txt');
    assert.ok(tool.diff.includes('+b'));
    assert.equal(JSON.parse(tool.input).file_path, 'a.txt');
    assert.equal(st.blocks[2].status, 'allowed');
    assert.equal(st.pending, 0);
    assert.equal(st.diffs.length, 1);
    assert.equal(st.usage.inputTokens, 5);
});

test('timeline: a pending permission hides its tool row until answered', () => {
    const { st } = run([
        { kind: 'tool_call', id: 'b', tool: 'Bash', title: '$ make', category: 'exec', input: { command: 'make' } },
        { kind: 'permission_request', id: 'b', tool: 'Bash', title: '$ make', category: 'exec' },
    ]);
    assert.equal(st.blocks[0].status, 'ask');
    assert.equal(JSON.parse(st.blocks[1].input).command, 'make');
    Timeline.apply(st, { seq: 3, kind: 'permission_resolved', id: 'b', decision: 'deny' });
    assert.equal(st.blocks[0].status, 'denied');
    Timeline.apply(st, { seq: 4, kind: 'tool_result', id: 'b', output: 'denied', isError: true });
    assert.equal(st.blocks[0].status, 'denied');
});

test('timeline: denied permission and gaps request a resync; duplicates ignored', () => {
    const st = Timeline.newState();
    Timeline.apply(st, { seq: 1, kind: 'permission_request', id: 'p', tool: 'Bash' });
    assert.equal(st.pending, 1);
    Timeline.apply(st, { seq: 2, kind: 'permission_resolved', id: 'p', decision: 'deny' });
    assert.equal(st.blocks[0].status, 'denied');
    assert.equal(Timeline.apply(st, { seq: 2, kind: 'error', message: 'dup' }).ops.length, 0);
    assert.equal(Timeline.apply(st, { seq: 5, kind: 'error', message: 'x' }).resync, true);
    assert.equal(Timeline.build([{ seq: 1, kind: 'user', text: 'a' }]).blocks.length, 1);
});

// ── Templates / Cron / Permissions / Automations ────────────────────────

test('templates: variables and expansion', () => {
    assert.deepEqual(plain(Templates.variables('Fix {selection} using {clipboard} {unknown} {selection}')), ['selection', 'clipboard']);
    const out = Templates.expand('{date} {selection} {{literal}} {json}', { selection: 'S' }, new Date(2026, 9, 5, 9, 7));
    assert.equal(out, '2026-10-05 S {literal} {json}');
    assert.equal(Templates.needsInput('Ask {input}'), true);
});

test('cron: parse, match, next', () => {
    assert.equal(Cron.valid('*/15 9-17 * * mon-fri'), true);
    assert.equal(Cron.valid('61 * * * *'), false);
    assert.equal(Cron.valid('@daily'), true);
    const monday9 = new Date(2026, 9, 5, 9, 0); // Monday
    assert.equal(Cron.matches('0 9 * * 1', monday9), true);
    assert.equal(Cron.matches('0 9 * * sun', monday9), false);
    assert.equal(Cron.matches('0 9 5 * 0', monday9), true); // dom OR dow when both restricted
    const n = Cron.next('30 8 * * *', monday9);
    assert.equal(n.getDate(), 6);
    assert.equal(n.getHours(), 8);
});

test('permissions: read-only auto, writes ask, yolo and session rules', () => {
    const read = { name: 'windows_list', server: 'yozakura', annotations: { readOnlyHint: true } };
    const write = { name: 'config_set', server: 'yozakura', annotations: { readOnlyHint: false } };
    assert.equal(Permissions.category(read), 'read');
    assert.equal(Permissions.category(write), 'write');
    assert.equal(Permissions.decide(read, {}), 'allow');
    assert.equal(Permissions.decide(write, {}), 'ask');
    assert.equal(Permissions.decide(write, { yolo: true }), 'allow');
    assert.equal(Permissions.decide(write, { sessionRules: { 'yozakura/config_set': true } }), 'allow');
    assert.equal(Permissions.category({ name: 'run_command' }), 'exec');
    assert.equal(Permissions.summarize('config_set', { key: 'bar.position' }), 'config_set · {"key":"bar.position"}');
});

test('permissions: third-party MCP tools are reads only with readOnlyHint', () => {
    const third = (name, annotations) => ({ name: name, server: 'github', annotations: annotations || {} });
    for (const name of ['query', 'list_repos', 'get_secret', 'delete_history', 'read_file', 'search_code', 'status', 'repo_list']) {
        assert.notEqual(Permissions.category(third(name)), 'read', name);
        assert.equal(Permissions.decide(third(name), {}), 'ask', name);
    }
    assert.equal(Permissions.category(third('delete_history')), 'write');
    assert.equal(Permissions.category(third('query')), 'mcp');
    assert.equal(Permissions.category(third('list_repos', { readOnlyHint: true })), 'read');
    assert.equal(Permissions.decide(third('list_repos', { readOnlyHint: true }), {}), 'allow');
    assert.equal(Permissions.category(third('list_repos', { readOnlyHint: false })), 'mcp');
    assert.equal(Permissions.category({ name: 'list_repos', server: 'github', readOnly: true }), 'read');
    // Yozakura's own tools keep the name heuristic.
    assert.equal(Permissions.category({ name: 'config_get', server: 'yozakura' }), 'read');
});

test('permissions: private desktop data always asks', () => {
    for (const name of ['clipboard_read', 'clipboard_history', 'notifications_list']) {
        const tool = { name: name, server: 'yozakura', readOnly: true, annotations: { readOnlyHint: true } };
        assert.notEqual(Permissions.category(tool), 'read', name);
        assert.equal(Permissions.decide(tool, {}), 'ask', name);
    }
    assert.equal(Permissions.category({ name: 'windows_list', server: 'yozakura', readOnly: true }), 'read');
});

test('urls: only http(s) links are opened', () => {
    for (const u of ['https://example.com', 'http://example.com/a?b=c#d', 'HTTPS://X.org'])
        assert.equal(Urls.isWeb(u), true, u);
    for (const u of ['file:///etc/passwd', 'javascript:alert(1)', 'ftp://x', 'smb://host/share', 'x-scheme-handler:foo',
        'https://', 'https:// space', ' https://x', 'https://x\n', '/home/user', '', null, undefined, 42, 'mailto:a@b'])
        assert.equal(Urls.isWeb(u), false, String(u));
});

test('automations: schedules, clipboard regex, transfers, login', () => {
    const list = [
        { id: 'a', enabled: true, trigger: { type: 'schedule', cron: '0 9 * * *' }, prompt: 'brief' },
        { id: 'b', enabled: true, trigger: { type: 'clipboard', pattern: 'Traceback|Exception' }, prompt: 'explain {clipboard}' },
        { id: 'c', enabled: false, trigger: { type: 'schedule', cron: '* * * * *' }, prompt: 'x' },
        { id: 'd', enabled: true, trigger: { type: 'clipboard', pattern: '(' }, prompt: 'bad regex' },
    ];
    const nine = new Date(2026, 9, 5, 9, 0);
    const first = Automations.dueSchedules(list, nine, {});
    assert.deepEqual(plain(first.due.map(a => a.id)), ['a']);
    assert.equal(Automations.dueSchedules(list, nine, { a: first.key }).due.length, 0);
    assert.deepEqual(plain(Automations.clipboardMatches(list, 'Traceback (most recent call last)').map(a => a.id)), ['b']);
    assert.equal(Automations.clipboardMatches(list, 'hello').length, 0);
    assert.equal(Automations.validPattern('('), false);
    const done = Automations.completedTransfers([{ id: 1, state: 'running' }, { id: 2, state: 'done' }], [{ id: 1, state: 'done' }, { id: 2, state: 'done' }, { id: 3, state: 'done' }]);
    assert.deepEqual(plain(done.map(t => t.id)), [1]);
    assert.equal(Automations.loginDue('2026-10-5', nine).due, false);
    assert.equal(Automations.normalize({ output: 'bogus' }).output, 'notify');
});
