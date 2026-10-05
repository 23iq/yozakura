package agents

import (
	"strings"
	"testing"
)

func TestClassify(t *testing.T) {
	cases := []struct {
		tool  string
		input map[string]any
		want  string
	}{
		{"Read", nil, CatRead},
		{"Grep", nil, CatRead},
		{"Edit", nil, CatWrite},
		{"Write", nil, CatWrite},
		{"WebFetch", nil, CatNetwork},
		{"WebSearch", nil, CatNetwork},
		{"Bash", map[string]any{"command": "ls -la"}, CatRead},
		{"Bash", map[string]any{"command": "git status && git diff HEAD"}, CatRead},
		{"Bash", map[string]any{"command": "rm -rf build"}, CatExec},
		{"Bash", map[string]any{"command": "ls > out.txt"}, CatExec},
		{"Bash", map[string]any{"command": "echo $(whoami)"}, CatExec},
		{"Bash", map[string]any{"command": "find . -name '*.go' -delete"}, CatExec},
		{"Bash", map[string]any{"command": "git branch -D main"}, CatExec},
		{"Bash", map[string]any{"command": "cat a | grep b | wc -l"}, CatRead},
		{"shell", map[string]any{"command": `/usr/bin/bash -lc "ls"`}, CatRead},
		{"execute", map[string]any{"command": "npm install"}, CatExec},
		{"read", nil, CatRead},
		{"edit", nil, CatWrite},
		{"fetch", nil, CatNetwork},
		{"mcp__yozakura__windows_list", nil, CatRead},
		{"mcp__yozakura__config_set", nil, CatMCP},
		{"mcp__github__create_issue", nil, CatMCP},
		{"ExitPlanMode", nil, CatOther},
	}
	for _, c := range cases {
		if got := Classify(c.tool, c.input); got != c.want {
			t.Errorf("Classify(%s, %v) = %s, want %s", c.tool, c.input, got, c.want)
		}
	}
}

func TestUnwrapShell(t *testing.T) {
	if got := unwrapShell(`/usr/bin/bash -lc "printf 'hi\\n' > hello.txt"`); got != `printf 'hi\n' > hello.txt` {
		t.Errorf("unwrap = %q", got)
	}
	if got := unwrapShell("sh -c 'ls -la'"); got != "ls -la" {
		t.Errorf("unwrap = %q", got)
	}
	if got := unwrapShell("ls"); got != "ls" {
		t.Errorf("unwrap = %q", got)
	}
}

func TestPolicyDecide(t *testing.T) {
	p := DefaultPolicy()
	read := PermissionRequest{Category: CatRead, Tool: "Read", RuleKey: "Read"}
	write := PermissionRequest{Category: CatWrite, Tool: "Edit", RuleKey: "Edit"}
	if p.Decide(read, false, nil) != DecisionAllow {
		t.Error("reads must be auto-approved")
	}
	if p.Decide(write, false, nil) != "" {
		t.Error("writes must ask")
	}
	if p.Decide(write, true, nil) != DecisionAllow {
		t.Error("yolo must approve")
	}
	if p.Decide(write, false, map[string]bool{"Edit": true}) != DecisionAllow {
		t.Error("session rule must approve")
	}
	strict := Policy{}
	if strict.Decide(read, false, nil) != "" {
		t.Error("empty autoApprove must ask for reads too")
	}
}

func TestToolTitle(t *testing.T) {
	cwd := "/work/proj"
	cases := []struct {
		tool  string
		input map[string]any
		want  string
	}{
		{"Read", map[string]any{"file_path": "/work/proj/src/a.go"}, "Read src/a.go"},
		{"Read", map[string]any{"file_path": "/work/projX/a"}, "Read /work/projX/a"},
		{"Bash", map[string]any{"command": "go test\n./..."}, "$ go test ./..."},
		{"Bash", map[string]any{"command": "sh -c 'cat a'"}, "$ cat a"},
		{"Bash", map[string]any{}, "Bash"},
		{"WebFetch", map[string]any{"url": "https://example.com/x"}, "Fetch example.com"},
		{"WebSearch", map[string]any{"query": "layer shell"}, "Search layer shell"},
		{"mcp__yozakura__wallpaper_set", nil, "yozakura: wallpaper_set"},
		{"Grep", map[string]any{"pattern": "TODO"}, "Grep TODO"},
		{"MultiEdit", map[string]any{"file_path": "/work/proj/x/y.qml"}, "Edit x/y.qml"},
		{"Write", map[string]any{"file_path": "/elsewhere/b.txt"}, "Write /elsewhere/b.txt"},
		{"execute", map[string]any{"command": `bash -c "make check"`}, "$ make check"},
		{"Unknown", nil, "Unknown"},
	}
	for _, c := range cases {
		if got := toolTitle(c.tool, c.input, cwd); got != c.want {
			t.Errorf("toolTitle(%s) = %q, want %q", c.tool, got, c.want)
		}
	}
	if long := toolTitle("Bash", map[string]any{"command": strings.Repeat("x", 300)}, cwd); len([]rune(long)) != 122 {
		t.Errorf("long title not truncated: %d", len([]rune(long)))
	}
}

func TestUnifiedDiff(t *testing.T) {
	d := unifiedDiff("a.txt", "one\ntwo\nthree\n", "one\n2\nthree\nfour\n")
	want := "--- a/a.txt\n+++ b/a.txt\n@@ -1,3 +1,4 @@\n one\n-two\n+2\n three\n+four\n"
	if d != want {
		t.Errorf("diff:\n%s\nwant:\n%s", d, want)
	}
	if d := unifiedDiff("n.txt", "", "hi"); d != "--- /dev/null\n+++ b/n.txt\n@@ -0,0 +1,1 @@\n+hi\n" {
		t.Errorf("new file diff:\n%s", d)
	}
	if unifiedDiff("x", "same", "same") != "" {
		t.Error("identical texts must give an empty diff")
	}
	// Two distant changes produce two hunks.
	var a, b []string
	for i := 0; i < 20; i++ {
		a = append(a, "l"+string(rune('a'+i)))
	}
	b = append(b, a...)
	b[1], b[18] = "X", "Y"
	d = unifiedDiff("f", strings.Join(a, "\n"), strings.Join(b, "\n"))
	if strings.Count(d, "@@ -") != 2 {
		t.Errorf("expected 2 hunks:\n%s", d)
	}
}

func TestRuleKeyIsTheWholeCommand(t *testing.T) {
	key := func(cmd string) string { return ruleKey("Bash", CatExec, map[string]any{"command": cmd}) }
	if k := key("git push origin"); k == "" || k == key("git push --force origin") || k == key("git reset --hard") {
		t.Errorf("git commands share a rule key: %q", k)
	}
	if key("make test") != key("make  test") || key("make test") != key(`bash -lc "make test"`) {
		t.Error("equivalent spellings should share a key")
	}
	if key("make && make install") == key("make || make install") || key("make && make install") == key("make") {
		t.Error("every segment and operator must be part of the key")
	}
	// No session rule for shells, interpreters, wrappers, cd, scripts or
	// commands that cannot be parsed exactly.
	for _, cmd := range []string{
		"cd /tmp", "cd x && make", "make && cd ..", "bash x.sh", "sh -c 'a' b", "zsh", "fish -c x",
		"python x.py", "python3 -c 'print(1)'", "python3.12 x.py", "node x.js", "perl -e x", "ruby x",
		"php x", "deno run x", "bun x.ts", "lua x", "npx something", "uvx tool", "env make", "sudo make",
		"xargs rm", "nice make", "timeout 5 make", "eval x", "exec make", "source x", ". x", "FOO=1 make",
		"./run.sh", "scripts/x.sh", "/tmp/x", "make > log", "echo $(id)", "make & make", "",
	} {
		if k := key(cmd); k != "" {
			t.Errorf("ruleKey(%q) = %q, want no session rule", cmd, k)
		}
	}
	if ruleKey("execute", CatExec, map[string]any{}) != "" {
		t.Error("exec without a command must not get a tool-wide rule")
	}
	if ruleKey("Edit", CatWrite, map[string]any{"file_path": "x"}) != "Edit" {
		t.Error("non-command tools keep the tool rule")
	}
}

func TestSessionRuleOnlyWhenOffered(t *testing.T) {
	s, sink, b := sinkFor(t)
	m := s.m
	var replies []string
	ask := func(id, cmd string) {
		in := map[string]any{"command": cmd}
		sink.Permission(PermissionRequest{ID: id, Tool: "Bash", Category: CatExec, Input: in,
			RuleKey: ruleKey("Bash", CatExec, in)}, func(d string) { replies = append(replies, d) })
	}
	ask("p1", "python evil.py")
	m.mu.Lock()
	s.flushLocked()
	m.mu.Unlock()
	reqs := b.kinds(KindPermissionRequest)
	if len(reqs) != 1 {
		t.Fatalf("requests = %+v", reqs)
	}
	for _, o := range reqs[0].Options {
		if o == DecisionAllowSession {
			t.Errorf("allow_session offered for an interpreter: %v", reqs[0].Options)
		}
	}
	// Even if a client sends allow_session, it is downgraded to allow.
	if err := s.respond("p1", DecisionAllowSession); err != nil {
		t.Fatal(err)
	}
	if len(s.rules) != 0 || len(replies) != 1 || replies[0] != DecisionAllow {
		t.Errorf("rules=%v replies=%v", s.rules, replies)
	}
	// A parsed command gets an exact rule; the agent itself is only told
	// "allow once" so it cannot widen the rule on its side.
	ask("p2", "make test")
	if err := s.respond("p2", DecisionAllowSession); err != nil {
		t.Fatal(err)
	}
	if len(replies) != 2 || replies[1] != DecisionAllow || len(s.rules) != 1 {
		t.Errorf("rules=%v replies=%v", s.rules, replies)
	}
	ask("p3", "make test")
	ask("p4", "make install")
	if len(replies) != 3 || len(s.pending) != 1 {
		t.Errorf("exact rule: replies=%v pending=%d", replies, len(s.pending))
	}
}

func TestPrivateDesktopDataAsks(t *testing.T) {
	for _, tool := range []string{"clipboard_read", "clipboard_history", "notifications_list"} {
		if got := Classify("mcp__"+YozakuraMCPName+"__"+tool, nil); got == CatRead {
			t.Errorf("%s auto-approved as read", tool)
		}
	}
}
