package agents

import (
	"encoding/json"
	"os"
	"strings"
	"testing"
	"yozakura/backend/pkg/brand"
)

func TestClaudeWriteBashStream(t *testing.T) {
	sink := &recSink{}
	c, f := startFake(t, "claude", "claude_write_bash.jsonl", StartOptions{Model: "haiku"}, sink)
	if err := c.Send("create hello.txt", nil); err != nil {
		t.Fatal(err)
	}
	waitFor(t, "done", func() bool { return sink.count(KindDone) == 1 })

	_, perms, agentID := sink.snapshot()
	if agentID != "9f632da6-0dd2-405a-a73b-a7e1e4e23c24" {
		t.Errorf("agent session id = %q", agentID)
	}
	if len(perms) != 1 || perms[0].Tool != "Write" || perms[0].Category != CatWrite || perms[0].ID != "toolu_01FqEkkizX4EShqc1DskRxna" {
		t.Fatalf("permission requests = %+v", perms)
	}
	write := sink.find(KindToolCall, func(e Event) bool { return e.Tool == "Write" })
	if write == nil || write.Category != CatWrite || !strings.HasSuffix(write.Title, "hello.txt") || !strings.HasPrefix(write.Title, "Write ") {
		t.Errorf("write tool call = %+v", write)
	}
	bash := sink.find(KindToolCall, func(e Event) bool { return e.Tool == "Bash" })
	if bash == nil || bash.Category != CatRead || bash.Title != "$ ls -la" {
		t.Errorf("bash tool call = %+v", bash)
	}
	res := sink.find(KindToolResult, func(e Event) bool { return e.ID == bash.ID })
	if res == nil || !strings.Contains(res.Output, "hello.txt") || res.IsError {
		t.Errorf("bash result = %+v", res)
	}
	diff := sink.find(KindDiff, nil)
	if diff == nil || !strings.HasSuffix(diff.Path, "hello.txt") || !strings.Contains(diff.Diff, "+hi") || diff.ID != write.ID {
		t.Errorf("diff = %+v", diff)
	}
	if got := sink.text(KindText); !strings.Contains(got, "Готово") {
		t.Errorf("text = %q", got)
	}
	done := sink.find(KindDone, nil)
	if done.Usage == nil || done.Usage.CostUSD <= 0 || done.Usage.OutputTokens == 0 {
		t.Errorf("usage = %+v", done.Usage)
	}
	in := f.stdin()
	if !strings.Contains(in, `"subtype":"initialize"`) || !strings.Contains(in, `"behavior":"allow"`) ||
		!strings.Contains(in, `"request_id":"07251d88-28e4-44be-b733-9d7f631eb833"`) {
		t.Errorf("stdin = %s", in)
	}
	args := strings.Join(f.args(), " ")
	if !strings.Contains(args, "--permission-prompt-tool stdio") || !strings.Contains(args, "--model haiku") {
		t.Errorf("args = %s", args)
	}
}

func TestClaudeDenyAndAllowSession(t *testing.T) {
	sink := &recSink{decide: func(r PermissionRequest) string {
		if r.Tool == "WebFetch" {
			return DecisionDeny
		}
		return DecisionAllowSession
	}}
	c, f := startFake(t, "claude", "claude_edit_webfetch.jsonl", StartOptions{}, sink)
	_ = c.Send("edit", nil)
	waitFor(t, "done", func() bool { return sink.count(KindDone) == 1 })
	_, perms, _ := sink.snapshot()
	if len(perms) != 2 || perms[0].Tool != "Edit" || perms[1].Tool != "WebFetch" || perms[1].Category != CatNetwork {
		t.Fatalf("perms = %+v", perms)
	}
	if read := sink.find(KindToolCall, func(e Event) bool { return e.Tool == "Read" }); read == nil || read.Category != CatRead {
		t.Errorf("read call = %+v", read)
	}
	if fetch := sink.find(KindToolCall, func(e Event) bool { return e.Tool == "WebFetch" }); fetch == nil || fetch.Title != "Fetch example.com" {
		t.Errorf("fetch call = %+v", fetch)
	}
	diff := sink.find(KindDiff, nil)
	if diff == nil || !strings.Contains(diff.Diff, "-hi") || !strings.Contains(diff.Diff, "+hello world") {
		t.Errorf("edit diff = %+v", diff)
	}
	in := f.stdin()
	if !strings.Contains(in, `"behavior":"deny"`) {
		t.Errorf("no deny in %s", in)
	}
	// allow_session forwards only session-scoped suggestions.
	if !strings.Contains(in, `"updatedPermissions":[{"destination":"session","mode":"acceptEdits","type":"setMode"}]`) {
		t.Errorf("no session permission update in %s", in)
	}
}

func TestClaudeInterruptAndImages(t *testing.T) {
	sink := &recSink{}
	c, f := startFake(t, "claude", "claude_write_bash.jsonl", StartOptions{}, sink)
	img := f.dir + "/shot.png"
	if err := writeFile(img, "PNG"); err != nil {
		t.Fatal(err)
	}
	_ = c.Send("look", []string{img})
	waitFor(t, "done", func() bool { return sink.count(KindDone) == 1 })
	_ = c.Interrupt()
	waitFor(t, "interrupt", func() bool { return strings.Contains(f.stdin(), `"subtype":"interrupt"`) })
	if !strings.Contains(f.stdin(), `"media_type":"image/png"`) || !strings.Contains(f.stdin(), `"data":"UE5H"`) {
		t.Errorf("image not sent: %s", f.stdin())
	}
}

func TestCodexCommandApproval(t *testing.T) {
	sink := &recSink{decide: func(PermissionRequest) string { return DecisionAllowSession }}
	c, f := startFake(t, "codex", "codex_command.jsonl", StartOptions{}, sink)
	_ = c.Send("create hello.txt", nil)
	waitFor(t, "done", func() bool { return sink.count(KindDone) == 1 })
	_, perms, agentID := sink.snapshot()
	if agentID != "01a10a26-1f55-7ce0-bead-cc118b8d2147" {
		t.Errorf("thread id = %q", agentID)
	}
	if len(perms) != 1 || perms[0].Category != CatExec || !strings.HasPrefix(perms[0].Title, "$ printf 'hi") ||
		perms[0].RuleKey != "" { // a redirection: no exact parse, no session rule
		t.Fatalf("perms = %+v", perms)
	}
	call := sink.find(KindToolCall, nil)
	res := sink.find(KindToolResult, nil)
	if call == nil || res == nil || call.ID != res.ID || !strings.Contains(res.Output, "hello.txt") {
		t.Errorf("call=%+v res=%+v", call, res)
	}
	if got := sink.text(KindText); !strings.Contains(got, "Created `hello.txt`") || !strings.Contains(got, "I’ll create") {
		t.Errorf("text = %q", got)
	}
	in := f.stdin()
	for _, want := range []string{`"method":"initialize"`, `"method":"initialized"`, `"approvalPolicy":"untrusted"`,
		`"approvalsReviewer":"user"`, `"sandbox":"workspace-write"`, `"method":"turn/start"`, `"decision":"acceptForSession"`} {
		if !strings.Contains(in, want) {
			t.Errorf("stdin lacks %s:\n%s", want, in)
		}
	}
}

func TestCodexPatchDiffAndYolo(t *testing.T) {
	sink := &recSink{}
	yolo := true
	c, f := startFake(t, "codex", "codex_patch.jsonl", StartOptions{Yolo: func() bool { return yolo }}, sink)
	_ = c.Send("edit", nil)
	waitFor(t, "done", func() bool { return sink.count(KindDone) == 1 })
	file := sink.find(KindDiff, func(e Event) bool { return e.Path != "" })
	if file == nil || !strings.HasSuffix(file.Path, "hello.txt") || !strings.Contains(file.Diff, "+hello world") || !strings.HasPrefix(file.Diff, "--- a/") {
		t.Errorf("file diff = %+v", file)
	}
	turn := sink.find(KindDiff, func(e Event) bool { return strings.HasPrefix(e.ID, "turn:") })
	if turn == nil || !strings.Contains(turn.Diff, "diff --git a/hello.txt") {
		t.Errorf("turn diff = %+v", turn)
	}
	_, perms, _ := sink.snapshot()
	if len(perms) != 1 || perms[0].Category != CatWrite {
		t.Errorf("perms = %+v", perms)
	}
	if in := f.stdin(); !strings.Contains(in, `"approvalPolicy":"never"`) || !strings.Contains(in, `"sandbox":"danger-full-access"`) {
		t.Errorf("yolo not applied: %s", in)
	}
}

func TestOpenCodeACPDeny(t *testing.T) {
	sink := &recSink{decide: func(PermissionRequest) string { return DecisionDeny }}
	c, f := startFake(t, "opencode", "opencode_ask.jsonl", StartOptions{Model: "ollama/qwen3.5:9b"}, sink)
	_ = c.Send("create hello.txt", nil)
	waitFor(t, "done", func() bool { return sink.count(KindDone) == 1 })
	_, perms, agentID := sink.snapshot()
	if agentID != "ses_ef5d7f265ffea2hJG1c7g51Oi1" {
		t.Errorf("session id = %q", agentID)
	}
	if len(perms) != 2 || perms[0].Category != CatWrite || perms[1].Category != CatRead || perms[1].Title != "$ ls" {
		t.Fatalf("perms = %+v", perms)
	}
	diff := sink.find(KindDiff, nil)
	if diff == nil || diff.Path != "hello.txt" || !strings.Contains(diff.Diff, "+hi") || !strings.Contains(diff.Diff, "--- /dev/null") {
		t.Errorf("diff = %+v", diff)
	}
	res := sink.find(KindToolResult, nil)
	if res == nil || !res.IsError || !strings.Contains(res.Output, "declined") {
		t.Errorf("result = %+v", res)
	}
	if strings.Count(f.stdin(), `"optionId":"reject"`) != 2 {
		t.Errorf("stdin = %s", f.stdin())
	}
	if !strings.Contains(f.stdin(), `"configId":"model"`) {
		t.Errorf("model not set: %s", f.stdin())
	}
}

func TestOpenCodeACPStream(t *testing.T) {
	sink := &recSink{}
	c, _ := startFake(t, "opencode", "opencode_noperm.jsonl", StartOptions{Model: "ollama/qwen3.5:9b"}, sink)
	_ = c.Send("create hello.txt", nil)
	waitFor(t, "done", func() bool { return sink.count(KindDone) == 1 })
	if sink.count(KindToolResult) != 2 || sink.text(KindThinking) == "" {
		evs, _, _ := sink.snapshot()
		t.Fatalf("events = %+v", evs)
	}
	ls := sink.find(KindToolCall, func(e Event) bool { return e.Title == "$ ls" })
	if ls == nil || ls.Category != CatRead || ls.Tool != "execute" {
		t.Errorf("ls call = %+v", ls)
	}
}

func TestArgsAndMCPPassThrough(t *testing.T) {
	mcp := []MCPServer{
		{Name: "yozakura", Transport: "stdio", Command: "/usr/bin/yozakura", Args: []string{"mcp"}, Env: map[string]string{"A": "SECRET-A"}},
		{Name: "docs", Transport: "http", URL: "https://example.com/mcp", Headers: map[string]string{"X": "SECRET-X"}},
	}
	o := StartOptions{Model: "opus", ResumeID: "abc", MCP: mcp, Mode: "shell", SystemPrompt: "be brief"}
	a := claudeArgs(o, "/run/cfg.json")
	joined := strings.Join(a, "\x00")
	for _, want := range []string{"--resume\x00abc", "--model\x00opus", "--strict-mcp-config", "--tools\x00\x00",
		"--append-system-prompt\x00be brief", "--mcp-config\x00/run/cfg.json"} {
		if !strings.Contains(joined, want) {
			t.Errorf("claude args lack %q: %q", want, a)
		}
	}
	var cfg struct {
		MCPServers map[string]map[string]any `json:"mcpServers"`
	}
	_ = json.Unmarshal(claudeMCPConfig(o), &cfg)
	if cfg.MCPServers["yozakura"]["command"] != "/usr/bin/yozakura" || cfg.MCPServers["docs"]["type"] != "http" {
		t.Errorf("mcp config = %+v", cfg)
	}
	cargs, cenv, err := codexArgs(StartOptions{MCP: mcp})
	if err != nil {
		t.Fatal(err)
	}
	ca := strings.Join(cargs, " ")
	for _, want := range []string{`mcp_servers."yozakura".command="/usr/bin/yozakura"`, `mcp_servers."yozakura".args=["mcp"]`,
		`mcp_servers."yozakura".env_vars=["A"]`, `mcp_servers."docs".url="https://example.com/mcp"`,
		`mcp_servers."docs".env_http_headers={"X" = "` + brand.EnvPrefix + `MCP_SECRET_1_0"}`} {
		if !strings.Contains(ca, want) {
			t.Errorf("codex args lack %s: %s", want, ca)
		}
	}
	if strings.Contains(ca, "SECRET-") {
		t.Errorf("codex argv carries MCP secrets: %s", ca)
	}
	if e := strings.Join(cenv, " "); !strings.Contains(e, "A=SECRET-A") || !strings.Contains(e, brand.EnvPrefix+"MCP_SECRET_1_0=SECRET-X") {
		t.Errorf("codex env = %v", cenv)
	}
	// Two servers wanting different values for one variable cannot share
	// Codex's environment.
	clash := append(mcp, MCPServer{Name: "b", Transport: "stdio", Command: "x", Env: map[string]string{"A": "other"}})
	if _, _, err := codexArgs(StartOptions{MCP: clash}); err == nil {
		t.Error("conflicting env values must be refused")
	}
	acp, _ := json.Marshal(acpMCPServers(mcp))
	if !strings.Contains(string(acp), `"env":[{"name":"A","value":"SECRET-A"}]`) || !strings.Contains(string(acp), `"type":"http"`) {
		t.Errorf("acp servers = %s", acp)
	}
}

func TestClaudeMCPConfigIsAPrivateFile(t *testing.T) {
	t.Setenv("XDG_RUNTIME_DIR", t.TempDir())
	mcp := []MCPServer{{Name: "gh", Transport: "stdio", Command: "gh-mcp", Env: map[string]string{"GITHUB_TOKEN": "SECRET-GH"}},
		{Name: "docs", Transport: "http", URL: "https://example.com/mcp", Headers: map[string]string{"Authorization": "SECRET-H"}}}
	c, f := startFake(t, "claude", "claude_write_bash.jsonl", StartOptions{MCP: mcp}, &recSink{})
	waitFor(t, "args", func() bool { return strings.Contains(strings.Join(f.args(), " "), "--mcp-config") })
	args := f.args()
	var path string
	for i, a := range args {
		if strings.Contains(a, "SECRET-") {
			t.Errorf("argv carries a secret: %q", a)
		}
		if a == "--mcp-config" && i+1 < len(args) {
			path = args[i+1]
		}
	}
	st, err := os.Stat(path)
	if err != nil || st.Mode().Perm() != 0o600 {
		t.Fatalf("mcp config %q: %v %v", path, st, err)
	}
	if b, _ := os.ReadFile(path); !strings.Contains(string(b), "SECRET-GH") || !strings.Contains(string(b), "SECRET-H") {
		t.Errorf("config = %s", b)
	}
	_ = c.Close()
	if _, err := os.Stat(path); !os.IsNotExist(err) {
		t.Errorf("config not removed after close: %v", err)
	}
}
