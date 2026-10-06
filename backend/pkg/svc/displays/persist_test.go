package displays

import (
	"errors"
	"strings"
	"sync"
	"testing"
	"time"

	"yozakura/backend/pkg/yozd/ipc"
)

// Whoever keeps a session (the shell, the CLI, MCP), the backend saves its
// candidate into displays.monitors; a second keep of the same session is
// answered without saving again.
func TestKeepPersistsCandidate(t *testing.T) {
	y := &fakeYozd{outputs: []ipc.Output{{ID: "LG|27GP|1", Name: "DP-1", Enabled: true, Width: 2560, Height: 1440, Refresh: 60, Scale: 1}}}
	var mu sync.Mutex
	now := time.Unix(1000, 0)
	s, _ := newTestService(y, &now, &mu)
	defer s.Close()
	var saved [][]ipc.OutputConfig
	var savedOuts []ipc.Output
	s.SetPersist(func(c []ipc.OutputConfig, outs []ipc.Output) error {
		saved = append(saved, c)
		savedOuts = outs
		return nil
	})
	cand := ipc.OutputConfig{Name: "DP-1", Enabled: true, Width: 2560, Height: 1440, Refresh: 165, Scale: 1}
	res := rpc(t, s.apply, map[string]any{"outputs": []ipc.OutputConfig{cand}})
	if len(saved) != 0 {
		t.Fatal("apply must not save")
	}
	k := rpc(t, s.keep, map[string]any{"session": res["session"]})
	if k["saved"] != true || len(saved) != 1 || saved[0][0] != cand {
		t.Fatalf("keep = %v, saved = %+v", k, saved)
	}
	if len(savedOuts) != 1 || savedOuts[0].ID != "LG|27GP|1" {
		t.Fatalf("persist needs the outputs' stable ids: %+v", savedOuts)
	}
	k = rpc(t, s.keep, map[string]any{"session": res["session"]})
	if k["ok"] != true || len(saved) != 1 {
		t.Fatalf("second keep = %v, saves = %d", k, len(saved))
	}
}

func TestKeepReportsSaveFailure(t *testing.T) {
	y := &fakeYozd{outputs: twoOutputs()}
	var mu sync.Mutex
	now := time.Unix(1000, 0)
	s, ev := newTestService(y, &now, &mu)
	defer s.Close()
	s.SetPersist(func([]ipc.OutputConfig, []ipc.Output) error { return errors.New("disk full") })
	res := rpc(t, s.apply, map[string]any{"outputs": []ipc.OutputConfig{{Name: "DP-1", Enabled: true, Width: 1920, Height: 1080, Scale: 1}}})
	_, err := s.keep([]byte(`{"session":"` + res["session"].(string) + `"}`))
	if err == nil || !strings.Contains(err.Error(), "disk full") {
		t.Fatalf("err = %v", err)
	}
	if l := ev.last(); l["state"] != StateKept {
		t.Fatalf("the change stays kept: %v", l)
	}
}
