package displays

import (
	"errors"
	"reflect"
	"testing"
	"time"

	"yozakura/backend/pkg/yozd/ipc"
)

// fakeApplier records applied configs; fail makes Apply fail for a name.
type fakeApplier struct {
	applied []ipc.OutputConfig
	fail    map[string]error
	calls   int
}

func (f *fakeApplier) Apply(c ipc.OutputConfig) error {
	f.calls++
	if err := f.fail[c.Name]; err != nil {
		return err
	}
	f.applied = append(f.applied, c)
	return nil
}

var (
	t0   = time.Unix(1000, 0)
	snap = []ipc.OutputConfig{{Name: "DP-1", Enabled: true, Width: 2560, Height: 1440, Refresh: 60, Scale: 1}}
	cand = []ipc.OutputConfig{{Name: "DP-1", Enabled: true, Width: 2560, Height: 1440, Refresh: 240, Scale: 1}}
)

func TestSessionAutoRevertsAfterDeadline(t *testing.T) {
	a := &fakeApplier{}
	m := NewManager(a)
	s, err := m.Start(t0, snap, cand)
	if err != nil || s.State != StatePending || !s.Live || !s.Deadline.Equal(t0.Add(RevertAfter)) {
		t.Fatalf("start = %+v, %v", s, err)
	}
	if !reflect.DeepEqual(a.applied, cand) {
		t.Fatalf("applied = %+v", a.applied)
	}
	if exp := m.Tick(t0.Add(14 * time.Second)); exp != nil {
		t.Fatalf("tick before deadline expired %+v", exp)
	}
	if got := m.Remaining(t0.Add(14*time.Second + time.Millisecond)); got != 1 {
		t.Fatalf("remaining = %d", got)
	}
	exp := m.Tick(t0.Add(RevertAfter))
	if exp == nil || exp.ID != s.ID || exp.State != StateReverted {
		t.Fatalf("tick after deadline = %+v", exp)
	}
	if !reflect.DeepEqual(a.applied[1:], snap) {
		t.Fatalf("revert applied %+v", a.applied[1:])
	}
	if m.Tick(t0.Add(time.Minute)) != nil {
		t.Fatal("a reverted session must not expire twice")
	}
}

func TestSessionKeepStopsTimer(t *testing.T) {
	a := &fakeApplier{}
	m := NewManager(a)
	s, _ := m.Start(t0, snap, cand)
	if err := m.Keep("nope"); err == nil {
		t.Fatal("unknown id must fail")
	}
	if err := m.Keep(s.ID); err != nil {
		t.Fatal(err)
	}
	if m.Tick(t0.Add(time.Hour)) != nil || len(a.applied) != 1 {
		t.Fatalf("kept session reverted: %+v", a.applied)
	}
	if m.Current().State != StateKept {
		t.Fatalf("state = %s", m.Current().State)
	}
	if err := m.Revert(s.ID); err == nil {
		t.Fatal("revert after keep must fail")
	}
}

func TestSessionExplicitRevert(t *testing.T) {
	a := &fakeApplier{}
	m := NewManager(a)
	s, _ := m.Start(t0, snap, cand)
	if err := m.Revert(s.ID); err != nil {
		t.Fatal(err)
	}
	if m.Current().State != StateReverted || !reflect.DeepEqual(a.applied[1:], snap) {
		t.Fatalf("state %s applied %+v", m.Current().State, a.applied)
	}
}

func TestSecondStartRevertsFirst(t *testing.T) {
	a := &fakeApplier{}
	m := NewManager(a)
	first, _ := m.Start(t0, snap, cand)
	cand2 := []ipc.OutputConfig{{Name: "DP-1", Enabled: true, Width: 1920, Height: 1080, Scale: 1}}
	second, err := m.Start(t0.Add(time.Second), snap, cand2)
	if err != nil || second.ID == first.ID {
		t.Fatalf("second = %+v, %v", second, err)
	}
	want := append(append(append([]ipc.OutputConfig{}, cand...), snap...), cand2...)
	if !reflect.DeepEqual(a.applied, want) {
		t.Fatalf("applied = %+v\nwant %+v", a.applied, want)
	}
	if err := m.Keep(first.ID); err == nil {
		t.Fatal("the replaced session must be gone")
	}
}

func TestApplyErrorRevertsImmediately(t *testing.T) {
	boom := errors.New("boom")
	a := &fakeApplier{fail: map[string]error{"HDMI-A-1": boom}}
	m := NewManager(a)
	c := append(append([]ipc.OutputConfig{}, cand...), ipc.OutputConfig{Name: "HDMI-A-1", Enabled: true})
	s, err := m.Start(t0, snap, c)
	if !errors.Is(err, boom) {
		t.Fatalf("want boom, got %v", err)
	}
	if s == nil || s.State != StateReverted {
		t.Fatalf("session = %+v", s)
	}
	if !reflect.DeepEqual(a.applied, append(append([]ipc.OutputConfig{}, cand...), snap...)) {
		t.Fatalf("applied = %+v", a.applied)
	}
}

func TestNotSupportedSessionIsNotLive(t *testing.T) {
	a := &fakeApplier{fail: map[string]error{"DP-1": ipc.ErrNotSupported}}
	m := NewManager(a)
	s, err := m.Start(t0, snap, cand)
	if err != nil || s.Live || s.State != StatePending {
		t.Fatalf("session = %+v, %v", s, err)
	}
	if exp := m.Tick(t0.Add(RevertAfter)); exp == nil || exp.State != StateReverted {
		t.Fatalf("expired = %+v", exp)
	}
	if a.calls != 1 {
		t.Fatalf("non-live revert must not apply: %d calls", a.calls)
	}
}
