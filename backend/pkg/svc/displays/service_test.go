package displays

import (
	"encoding/json"
	"reflect"
	"sync"
	"testing"
	"time"

	"yozakura/backend/pkg/yozd/ipc"
)

type fakeYozd struct {
	mu      sync.Mutex
	outputs []ipc.Output
	applied []ipc.OutputConfig
	applyFn func(ipc.OutputConfig) error
}

func (f *fakeYozd) Outputs() ([]ipc.Output, error) { return f.outputs, nil }
func (f *fakeYozd) ApplyOutput(c ipc.OutputConfig) error {
	f.mu.Lock()
	defer f.mu.Unlock()
	if f.applyFn != nil {
		if err := f.applyFn(c); err != nil {
			return err
		}
	}
	f.applied = append(f.applied, c)
	return nil
}

func (f *fakeYozd) appliedCopy() []ipc.OutputConfig {
	f.mu.Lock()
	defer f.mu.Unlock()
	return append([]ipc.OutputConfig(nil), f.applied...)
}

type events struct {
	mu   sync.Mutex
	list []map[string]any
}

func (e *events) add(name string, data any) {
	e.mu.Lock()
	defer e.mu.Unlock()
	raw, _ := json.Marshal(data)
	m := map[string]any{}
	_ = json.Unmarshal(raw, &m)
	m["_event"] = name
	e.list = append(e.list, m)
}

func (e *events) last() map[string]any {
	e.mu.Lock()
	defer e.mu.Unlock()
	if len(e.list) == 0 {
		return nil
	}
	return e.list[len(e.list)-1]
}

func twoOutputs() []ipc.Output {
	return []ipc.Output{
		{Name: "HDMI-A-1", Enabled: true, Width: 1920, Height: 1080, Refresh: 60, X: 2560, Scale: 1},
		{Name: "DP-1", Enabled: true, Width: 2560, Height: 1440, Refresh: 60, Scale: 1, VRR: true},
		{Name: "DP-2", Enabled: false},
	}
}

func newTestService(y *fakeYozd, now *time.Time, mu *sync.Mutex) (*Service, *events) {
	ev := &events{}
	s := newService(y, "", "")
	s.tick = time.Millisecond
	s.now = func() time.Time { mu.Lock(); defer mu.Unlock(); return *now }
	s.onEvent = ev.add
	return s, ev
}

func rpc(t *testing.T, h func(json.RawMessage) (any, error), params any) map[string]any {
	t.Helper()
	raw, _ := json.Marshal(params)
	res, err := h(raw)
	if err != nil {
		t.Fatalf("rpc: %v", err)
	}
	out, _ := json.Marshal(res)
	m := map[string]any{}
	_ = json.Unmarshal(out, &m)
	return m
}

func waitFor(t *testing.T, cond func() bool) {
	t.Helper()
	deadline := time.Now().Add(2 * time.Second)
	for !cond() {
		if time.Now().After(deadline) {
			t.Fatal("timed out")
		}
		time.Sleep(time.Millisecond)
	}
}

func TestApplyKeepPublishesSession(t *testing.T) {
	y := &fakeYozd{outputs: twoOutputs()}
	var mu sync.Mutex
	now := time.Unix(1000, 0)
	s, ev := newTestService(y, &now, &mu)
	cand := ipc.OutputConfig{Name: "DP-1", Enabled: true, Width: 2560, Height: 1440, Refresh: 240, Scale: 1}
	res := rpc(t, s.apply, map[string]any{"outputs": []ipc.OutputConfig{cand}})
	if res["revertIn"] != float64(15) || res["live"] != true || res["session"] == "" {
		t.Fatalf("apply result = %v", res)
	}
	waitFor(t, func() bool {
		l := ev.last()
		return l != nil && l["state"] == StatePending && l["remaining"] == float64(15)
	})
	rpc(t, s.keep, map[string]any{"session": res["session"]})
	if l := ev.last(); l["state"] != StateKept {
		t.Fatalf("last event = %v", l)
	}
	mu.Lock()
	now = now.Add(time.Minute)
	mu.Unlock()
	time.Sleep(10 * time.Millisecond)
	if got := y.appliedCopy(); !reflect.DeepEqual(got, []ipc.OutputConfig{cand}) {
		t.Fatalf("kept session re-applied: %+v", got)
	}
	s.Close()
}

func TestTimerRevertsWithoutShell(t *testing.T) {
	y := &fakeYozd{outputs: twoOutputs()}
	var mu sync.Mutex
	now := time.Unix(1000, 0)
	s, ev := newTestService(y, &now, &mu)
	defer s.Close()
	cand := ipc.OutputConfig{Name: "DP-1", Enabled: true, Width: 1920, Height: 1080, Scale: 1}
	rpc(t, s.apply, map[string]any{"outputs": []ipc.OutputConfig{cand}})
	mu.Lock()
	now = now.Add(RevertAfter)
	mu.Unlock()
	waitFor(t, func() bool { l := ev.last(); return l != nil && l["state"] == StateReverted })
	want := []ipc.OutputConfig{cand, {Name: "DP-1", Enabled: true, Width: 2560, Height: 1440, Refresh: 60, Scale: 1, VRR: 1}}
	if got := y.appliedCopy(); !reflect.DeepEqual(got, want) {
		t.Fatalf("applied = %+v\nwant %+v", got, want)
	}
}

func TestApplyRejectsInvalidOutput(t *testing.T) {
	y := &fakeYozd{outputs: twoOutputs()}
	s := newService(y, "", "")
	raw, _ := json.Marshal(map[string]any{"outputs": []ipc.OutputConfig{{Name: "DP-1;reboot"}}})
	if _, err := s.apply(raw); err == nil || len(y.appliedCopy()) != 0 {
		t.Fatalf("invalid output applied: %v", err)
	}
	if _, err := s.apply(json.RawMessage(`{"outputs":[]}`)); err == nil {
		t.Fatal("empty apply must fail")
	}
}

func TestIdentifyOrdersByPosition(t *testing.T) {
	y := &fakeYozd{outputs: twoOutputs()}
	s := newService(y, "", "")
	ev := &events{}
	s.onEvent = ev.add
	res := rpc(t, s.identify, nil)
	want := []any{
		map[string]any{"name": "DP-1", "index": float64(1)},
		map[string]any{"name": "HDMI-A-1", "index": float64(2)},
	}
	if !reflect.DeepEqual(res["outputs"], want) {
		t.Fatalf("identify = %v", res)
	}
	if l := ev.last(); l["_event"] != "displays.identify" || !reflect.DeepEqual(l["outputs"], want) {
		t.Fatalf("event = %v", l)
	}
}

func TestApplyAfterCloseFails(t *testing.T) {
	y := &fakeYozd{outputs: twoOutputs()}
	s := newService(y, "", "")
	s.Close()
	raw, _ := json.Marshal(map[string]any{"outputs": []ipc.OutputConfig{{Name: "DP-1", Enabled: true}}})
	if _, err := s.apply(raw); err == nil || len(y.appliedCopy()) != 0 {
		t.Fatalf("apply after Close: %v, applied %d", err, len(y.appliedCopy()))
	}
}
