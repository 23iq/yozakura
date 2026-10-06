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
	if _, err := m.Keep("nope"); err == nil {
		t.Fatal("unknown id must fail")
	}
	if kept, err := m.Keep(s.ID); err != nil || kept.State != StateKept || kept.ID != s.ID {
		t.Fatalf("keep = %+v, %v", kept, err)
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
	if _, err := m.Keep(first.ID); err == nil {
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

// Two applies in a row: the second snapshot is read while the first
// candidate is live, yet reverting must restore the ORIGINAL state.
func TestSecondApplyRevertsToOriginal(t *testing.T) {
	a := &fakeApplier{}
	m := NewManager(a)
	orig := []ipc.OutputConfig{{Name: "DP-1", Enabled: true, Width: 2560, Height: 1440, Refresh: 60, Scale: 1}}
	c1 := []ipc.OutputConfig{{Name: "DP-1", Enabled: true, Width: 2560, Height: 1440, Refresh: 240, Scale: 1}}
	c2 := []ipc.OutputConfig{
		{Name: "DP-1", Enabled: true, Width: 1920, Height: 1080, Refresh: 144, Scale: 1},
		{Name: "HDMI-A-1", Enabled: false},
	}
	if _, err := m.Start(t0, orig, c1); err != nil {
		t.Fatal(err)
	}
	// what the compositor reports while c1 is live
	snap2 := []ipc.OutputConfig{c1[0], {Name: "HDMI-A-1", Enabled: true, Width: 1920, Height: 1080, Scale: 1}}
	s2, err := m.Start(t0.Add(time.Second), snap2, c2)
	if err != nil {
		t.Fatal(err)
	}
	want := []ipc.OutputConfig{orig[0], snap2[1]}
	if !reflect.DeepEqual(s2.Snapshot, want) {
		t.Fatalf("snapshot = %+v\nwant %+v", s2.Snapshot, want)
	}
	before := len(a.applied)
	if err := m.Revert(s2.ID); err != nil {
		t.Fatal(err)
	}
	if !reflect.DeepEqual(a.applied[before:], want) {
		t.Fatalf("revert applied %+v, want original %+v", a.applied[before:], want)
	}
}
