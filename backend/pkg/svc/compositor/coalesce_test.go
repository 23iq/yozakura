package compositor

import (
	"encoding/json"
	"fmt"
	"strings"
	"sync"
	"testing"
	"time"
)

func layoutState(name string) State {
	return State{KeyboardLayout: json.RawMessage(`{"name":"` + name + `"}`)}
}

type recorder struct {
	mu   sync.Mutex
	got  []string
	when []time.Time
}

func (r *recorder) send(st State) {
	r.mu.Lock()
	defer r.mu.Unlock()
	r.got = append(r.got, string(st.KeyboardLayout))
	r.when = append(r.when, time.Now())
}

func (r *recorder) snapshot() ([]string, []time.Time) {
	r.mu.Lock()
	defer r.mu.Unlock()
	return append([]string(nil), r.got...), append([]time.Time(nil), r.when...)
}

func TestCoalesceFirstEventIsImmediate(t *testing.T) {
	in := make(chan State, 1)
	stop := make(chan struct{})
	defer close(stop)
	r := &recorder{}
	go coalesce(in, stop, time.Hour, r.send)
	t0 := time.Now()
	in <- layoutState("a")
	waitFor(t, "first push", func() bool { got, _ := r.snapshot(); return len(got) == 1 })
	if _, when := r.snapshot(); when[0].Sub(t0) > 50*time.Millisecond {
		t.Fatalf("first push delayed by %v", when[0].Sub(t0))
	}
}

func TestCoalesceBurstLatestWins(t *testing.T) {
	const interval = 40 * time.Millisecond
	in := make(chan State)
	stop := make(chan struct{})
	defer close(stop)
	r := &recorder{}
	go coalesce(in, stop, interval, r.send)
	for i := 0; i < 200; i++ {
		in <- layoutState(fmt.Sprintf("s%d", i))
	}
	last := layoutState("final")
	in <- last
	burstEnd := time.Now()
	waitFor(t, "newest state", func() bool {
		got, _ := r.snapshot()
		return len(got) > 0 && got[len(got)-1] == string(last.KeyboardLayout)
	})
	got, when := r.snapshot()
	if got[0] != `{"name":"s0"}` {
		t.Errorf("first push = %s, want the first state of the burst", got[0])
	}
	// 201 events back to back: the first goes out at once, the rest
	// collapse into one push per interval.
	elapsed := when[len(when)-1].Sub(when[0])
	if limit := int(elapsed/interval) + 2; len(got) > limit {
		t.Errorf("%d pushes in %v, want at most %d", len(got), elapsed, limit)
	}
	for i := 1; i < len(when); i++ {
		if gap := when[i].Sub(when[i-1]); gap < interval-2*time.Millisecond {
			t.Errorf("push %d only %v after the previous one", i, gap)
		}
	}
	if lag := when[len(when)-1].Sub(burstEnd); lag > interval+50*time.Millisecond {
		t.Errorf("newest state arrived %v after the burst", lag)
	}
}

func TestCoalesceFlushesPendingOnClose(t *testing.T) {
	in := make(chan State, 3)
	r := &recorder{}
	in <- layoutState("a")
	in <- layoutState("b")
	in <- layoutState("c")
	close(in)
	coalesce(in, make(chan struct{}), time.Hour, r.send)
	got, _ := r.snapshot()
	if len(got) != 2 || got[0] != `{"name":"a"}` || got[1] != `{"name":"c"}` {
		t.Fatalf("pushes = %v, want first and last", got)
	}
}

func TestCoalesceStops(t *testing.T) {
	stop := make(chan struct{})
	done := make(chan struct{})
	go func() { coalesce(make(chan State), stop, pushInterval, func(State) {}); close(done) }()
	close(stop)
	select {
	case <-done:
	case <-time.After(time.Second):
		t.Fatal("coalesce did not return on stop")
	}
}

func TestReadSubscribeDecodesAndKeepsNewest(t *testing.T) {
	m := NewManager(nil)
	ch, cancel := m.Subscribe()
	defer cancel()
	var lines strings.Builder
	const n = 40 // more than the subscriber channel buffer
	for i := 0; i < n; i++ {
		fmt.Fprintf(&lines, `{"state":{"keyboard_layout":{"name":"l%d"},"windows":[{"id":"0x1"}]}}`+"\n", i)
	}
	lines.WriteString("not json\n{\"other\":1}\n")
	m.readSubscribe(strings.NewReader(lines.String()))

	var last State
	for k := len(ch); k > 0; k-- {
		last = <-ch
	}
	want := fmt.Sprintf(`{"name":"l%d"}`, n-1)
	if string(last.KeyboardLayout) != want {
		t.Errorf("newest queued state = %s, want %s", last.KeyboardLayout, want)
	}
	if st := m.State(); string(st.KeyboardLayout) != want || len(st.Windows) != 1 {
		t.Errorf("State() = %+v", st)
	}
}
