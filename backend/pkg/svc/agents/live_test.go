//go:build live

package agents

import (
	"os"
	"strings"
	"testing"
	"time"
)

func TestLive(t *testing.T) {
	agent := os.Getenv("LIVE_AGENT")
	dir := os.Getenv("LIVE_DIR")
	m := NewManager(dir + "/store")
	b := &bus{}
	m.SetBroadcast(b.push)
	m.Configure(Config{Agents: map[string]AgentConfig{"claude": {Model: "haiku"}, "opencode": {Model: "ollama/qwen3.5:9b"}}})
	defer m.Shutdown()
	meta, err := m.Create(CreateParams{Agent: agent, Cwd: dir, Mode: os.Getenv("LIVE_MODE")})
	if err != nil {
		t.Fatal(err)
	}
	wait := func() {
		deadline := time.Now().Add(240 * time.Second)
		for time.Now().Before(deadline) {
			st := status(m, meta.ID)
			if st.Status == StatusIdle || st.Status == StatusExited {
				return
			}
			if st.Pending > 0 {
				for _, e := range b.kinds(KindPermissionRequest) {
					_ = m.Respond(meta.ID, e.ID, DecisionDeny)
				}
			}
			time.Sleep(200 * time.Millisecond)
		}
		t.Fatal("timeout")
	}
	_ = m.Send(meta.ID, "Say hi in exactly two words. Remember the word BANANA.", nil)
	wait()
	_ = m.CloseSession(meta.ID)
	_ = m.Send(meta.ID, "Which word did I ask you to remember? One word.", nil)
	wait()
	b.mu.Lock()
	for _, e := range b.events {
		t.Logf("%d %s %q %s %s %s %s", e.Seq, e.Kind, strings.TrimSpace(e.Text), e.Tool, e.Title, e.Status, e.Message)
	}
	b.mu.Unlock()
	t.Logf("meta %+v", status(m, meta.ID))
}
