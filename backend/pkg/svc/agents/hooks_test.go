package agents

import (
	"reflect"
	"strings"
	"sync"
	"testing"
)

func TestListenerAndPermissionHook(t *testing.T) {
	m, b, f := newTestManager(t, "claude_write_bash.jsonl")
	var mu sync.Mutex
	seen := map[string]int{}
	m.AddListener(func(service string, data any) {
		mu.Lock()
		seen[service]++
		mu.Unlock()
	})
	m.SetPermissionHook(func(meta SessionMeta, req PermissionRequest) string {
		if req.Category == CatWrite {
			return DecisionAllow
		}
		return "maybe" // anything else falls through to the policy
	})
	meta, err := m.Create(CreateParams{Agent: "claude", Cwd: f.dir})
	if err != nil {
		t.Fatal(err)
	}
	if err := m.Send(meta.ID, "Create hello.txt please", nil); err != nil {
		t.Fatal(err)
	}
	waitFor(t, "done", func() bool { return len(b.kinds(KindDone)) == 1 })
	if n := len(b.kinds(KindPermissionRequest)); n != 0 {
		t.Fatalf("the hook should have answered the Write, %d requests asked", n)
	}
	res := b.kinds(KindPermissionResolved)
	if len(res) == 0 || res[0].Decision != DecisionAuto {
		t.Fatalf("resolved: %+v", res)
	}
	if !strings.Contains(f.stdin(), `"behavior":"allow"`) {
		t.Fatal("allow not sent to the agent")
	}
	mu.Lock()
	defer mu.Unlock()
	if seen["agents.event"] == 0 || seen["agents.sessions"] == 0 {
		t.Fatalf("listener saw %v", seen)
	}
	if autoDecision(DecisionDeny) != DecisionDeny || autoDecision(DecisionAllow) != DecisionAuto {
		t.Fatal("autoDecision")
	}
}

func TestDebugInfo(t *testing.T) {
	m, b, f := newTestManager(t, "claude_write_bash.jsonl")
	meta, _ := m.Create(CreateParams{Agent: "claude", Cwd: f.dir})
	if _, err := m.Debug("nope", 5); err == nil {
		t.Fatal("unknown session accepted")
	}
	_ = m.Send(meta.ID, "hi", nil)
	waitFor(t, "permission", func() bool { return len(b.kinds(KindPermissionRequest)) == 1 })
	info, err := m.Debug(meta.ID, 3)
	if err != nil {
		t.Fatal(err)
	}
	if !info.Running || len(info.LogTail) != 3 || info.LogPath != m.logPath(meta.ID) || len(info.Argv) == 0 ||
		!strings.HasSuffix(info.Argv[0], "fakecli.sh") {
		t.Fatalf("debug: %+v", info)
	}
}

func TestRedactArgv(t *testing.T) {
	in := []string{"claude", "--api-key", "sk-123", "--token=abc", "OPENAI_API_KEY=xyz", "--model", "opus",
		`{"headers":{"Authorization":"Bearer tok"}}`, "-p"}
	want := []string{"claude", "--api-key", "<redacted>", "--token=<redacted>", "OPENAI_API_KEY=<redacted>", "--model", "opus",
		`{"headers":{"Authorization":"Bearer <redacted>"}}`, "-p"}
	if got := RedactArgv(in); !reflect.DeepEqual(got, want) {
		t.Fatalf("got %q", got)
	}
}
