package displays

import (
	"errors"
	"sync"
	"testing"
	"time"

	"yozakura/backend/pkg/yozd/ipc"
)

func TestApplyOnlyChangedOutputsAndSkipsMirror(t *testing.T) {
	outs := twoOutputs()
	outs[0].MirrorOf = "DP-1"
	y := &fakeYozd{outputs: outs}
	var mu sync.Mutex
	now := time.Unix(1000, 0)
	s, _ := newTestService(y, &now, &mu)
	defer s.Close()
	same := ipc.OutputConfig{Name: "DP-1", Enabled: true, Width: 2560, Height: 1440, Refresh: 60, Scale: 1, VRR: 2}
	mirrored := ipc.OutputConfig{Name: "HDMI-A-1", Enabled: true, Width: 1280, Height: 720, Refresh: 60, X: 2560, Scale: 1}
	res := rpc(t, s.apply, map[string]any{"outputs": []ipc.OutputConfig{same, mirrored}})
	if res["unchanged"] != true || res["session"] != "" {
		t.Fatalf("nothing should be applied: %v", res)
	}
	if len(y.appliedCopy()) != 0 {
		t.Fatalf("applied %v", y.appliedCopy())
	}
	changed := same
	changed.Refresh = 144
	res = rpc(t, s.apply, map[string]any{"outputs": []ipc.OutputConfig{changed, mirrored}})
	if got := y.appliedCopy(); len(got) != 1 || got[0].Name != "DP-1" {
		t.Fatalf("applied %v", got)
	}
	if a := res["applied"].([]any); len(a) != 1 || a[0] != "DP-1" {
		t.Fatalf("applied = %v", res["applied"])
	}
}

func TestSnapshotKeepsVRRMode(t *testing.T) {
	cur := twoOutputs()
	cand := []ipc.OutputConfig{{Name: "DP-1", Enabled: true, Width: 2560, Height: 1440, Refresh: 240, Scale: 1, VRR: 2}}
	if got := snapshotFor(cur, cand); len(got) != 1 || got[0].VRR != 2 {
		t.Fatalf("snapshot vrr = %+v", got)
	}
}

func TestRevertFailureIsPublished(t *testing.T) {
	a := &fakeApplier{}
	m := NewManager(a)
	if _, err := m.Start(t0, snap, cand); err != nil {
		t.Fatal(err)
	}
	a.fail = map[string]error{"DP-1": errors.New("boom")}
	exp := m.Tick(t0.Add(RevertAfter))
	if exp == nil || exp.State != StateReverted || exp.Error == "" {
		t.Fatalf("expired = %+v", exp)
	}
}
