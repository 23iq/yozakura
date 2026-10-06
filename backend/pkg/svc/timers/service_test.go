package timers

import (
	"encoding/json"
	"os"
	"path/filepath"
	"sync"
	"testing"
	"time"

	"yozakura/backend/pkg/ipc"
	"yozakura/backend/pkg/svc/notify"

	"github.com/stretchr/testify/assert"
)

type harness struct {
	svc   *Service
	clock *clock
	path  string
	mu    sync.Mutex
	notes []notify.SendParams
}

func newHarness(t *testing.T, path string, c *clock) *harness {
	h := &harness{clock: c, path: path}
	h.svc = NewService(Options{Path: path, Now: c.now, Notify: func(p notify.SendParams) {
		h.mu.Lock()
		h.notes = append(h.notes, p)
		h.mu.Unlock()
	}, Pomodoro: func() PomodoroConfig { return PomodoroConfig{Work: 50 * time.Minute} }})
	return h
}

func (h *harness) call(t *testing.T, method string, params any) map[string]any {
	t.Helper()
	raw, _ := json.Marshal(params)
	res, err := h.svc.methods()[method](raw)
	assert.NoError(t, err, method)
	data, _ := json.Marshal(res)
	var out map[string]any
	_ = json.Unmarshal(data, &out)
	return out
}

func (h *harness) callErr(method string, params any) error {
	raw, _ := json.Marshal(params)
	_, err := h.svc.methods()[method](raw)
	return err
}

func TestServicePersistsAndFiresAfterRestart(t *testing.T) {
	path := filepath.Join(t.TempDir(), "sub", FileName)
	c := &clock{t: t0}
	h := newHarness(t, path, c)
	res := h.call(t, "start", map[string]any{"spec": "10m", "name": "tea"})
	assert.Equal(t, "t1", res["timer"].(map[string]any)["id"])
	h.call(t, "reminderAdd", map[string]any{"when": "in 1h", "message": "stretch"})
	h.call(t, "stopwatch", map[string]any{"action": "start"})
	_, err := os.Stat(path)
	assert.NoError(t, err)

	// Daemon goes down for 20 minutes; the timer keeps counting.
	c.advance(20 * time.Minute)
	h2 := newHarness(t, path, c)
	v := h2.svc.View()
	assert.Len(t, v.Timers, 1)
	assert.EqualValues(t, 1_200_000, v.Stopwatch.ElapsedMs)
	h2.svc.Poll()
	assert.Len(t, h2.notes, 1)
	n := h2.notes[0]
	assert.Equal(t, "tea", n.Summary)
	assert.Contains(t, n.Body, "(due 14:10)") // missed while down
	assert.Empty(t, n.SummaryKey, "a named timer keeps its name")
	assert.Equal(t, "notify.missed", n.BodyKey)
	if assert.Len(t, n.Args, 2) {
		assert.Equal(t, "notify.timer.finished", n.Args[0].(notify.Text).Key)
		assert.Equal(t, "14:10", n.Args[1])
	}
	assert.Equal(t, "critical", n.Urgency)
	if assert.Len(t, n.Actions, 2) {
		assert.Equal(t, "timers.add", n.Actions[0].Call.Method)
		assert.Equal(t, "timers.dismiss", n.Actions[1].Call.Method)
	}
	assert.Equal(t, StateRinging, h2.svc.View().Timers[0].State)

	// The ringing state is persisted too.
	h3 := newHarness(t, path, c)
	assert.Equal(t, StateRinging, h3.svc.View().Timers[0].State)
	h3.call(t, "dismiss", map[string]any{})
	assert.Empty(t, h3.svc.View().Timers)
}

func TestServiceMethods(t *testing.T) {
	c := &clock{t: t0}
	h := newHarness(t, "", c)

	q := h.call(t, "quick", map[string]any{"text": "25 pasta"})
	assert.Equal(t, "timer", q["intent"].(map[string]any)["kind"])
	assert.Equal(t, "pasta", q["timer"].(map[string]any)["name"])

	q = h.call(t, "quick", map[string]any{"text": "sw"})
	assert.Equal(t, SWRunning, q["stopwatch"].(map[string]any)["state"])

	q = h.call(t, "quick", map[string]any{"text": "18:00 call mom"})
	assert.Equal(t, "call mom", q["reminder"].(map[string]any)["message"])

	p := h.call(t, "pomodoro", map[string]any{"break": "10m"})
	pm := p["timer"].(map[string]any)["pomodoro"].(map[string]any)
	assert.EqualValues(t, 50*60*1000, pm["workMs"]) // from the config defaults
	assert.EqualValues(t, 10*60*1000, pm["breakMs"])

	parsed := h.call(t, "parse", map[string]any{"text": "1h30 bread"})
	assert.Equal(t, "Timer 1h 30m: bread", parsed["label"])

	a := h.call(t, "add", map[string]any{"id": "pasta", "spec": "-5m"})
	assert.EqualValues(t, -300, a["addedSeconds"])
	assert.EqualValues(t, 20*60*1000, a["timer"].(map[string]any)["leftMs"])

	h.call(t, "pause", map[string]any{"id": "pasta"})
	assert.Error(t, h.callErr("pause", map[string]any{"id": "pasta"}))
	h.call(t, "resume", map[string]any{"id": "pasta"})
	cancelled := h.call(t, "cancel", map[string]any{"id": "pasta"})
	h.call(t, "restore", cancelled)

	start := h.call(t, "start", map[string]any{"spec": "18:00"}) // until a clock time
	assert.EqualValues(t, 4*3600*1000, start["timer"].(map[string]any)["leftMs"])

	assert.Error(t, h.callErr("start", map[string]any{}))
	assert.Error(t, h.callErr("start", map[string]any{"spec": "soon"}))
	assert.Error(t, h.callErr("reminderAdd", map[string]any{"message": "x"}))
	assert.Error(t, h.callErr("stopwatch", map[string]any{"action": "fly"}))

	sw := h.call(t, "stopwatch", map[string]any{"action": "reset"})
	h.call(t, "stopwatchSet", map[string]any{"stopwatch": sw["previous"]})
	assert.Equal(t, SWRunning, h.svc.View().Stopwatch.State)

	h.call(t, "reminderCancel", map[string]any{"id": "call mom"})
	assert.Empty(t, h.svc.View().Reminders)
}

func TestServiceBroadcastsStateAndEvents(t *testing.T) {
	c := &clock{t: t0}
	h := newHarness(t, "", c)
	sub := &ipc.Subscriber{Events: make(chan ipc.ServiceEvent, 16)}
	go h.svc.subscribe(sub) // nil stop channel: stays subscribed
	first := <-sub.Events
	assert.Equal(t, "timers.state", first.Service)

	h.call(t, "start", map[string]any{"seconds": 30})
	assert.Equal(t, "timers.state", (<-sub.Events).Service)
	c.advance(30 * time.Second)
	wait := h.svc.Poll()
	assert.Equal(t, maxWait, wait)
	ev := <-sub.Events
	assert.Equal(t, "timers.event", ev.Service)
	assert.Equal(t, "t1", ev.Data.(Event).ID)
	st := (<-sub.Events).Data.(View)
	assert.Equal(t, 1, st.Ringing)
}

func TestPollWaitsForNextDeadline(t *testing.T) {
	c := &clock{t: t0}
	h := newHarness(t, "", c)
	h.call(t, "start", map[string]any{"seconds": 3})
	assert.Equal(t, 3*time.Second+5*time.Millisecond, h.svc.Poll())
}

func TestSystemPomodoro(t *testing.T) {
	f := filepath.Join(t.TempDir(), "system.json")
	assert.NoError(t, os.WriteFile(f, []byte(`{"pomodoro":{"workTime":1800,"restTime":600}}`), 0o644))
	c := SystemPomodoro(f)
	assert.Equal(t, 30*time.Minute, c.Work)
	assert.Equal(t, 10*time.Minute, c.Break)
	assert.Equal(t, PomodoroConfig{}, SystemPomodoro(filepath.Join(t.TempDir(), "none.json")))
}

func TestLoadCorruptStartsEmpty(t *testing.T) {
	f := filepath.Join(t.TempDir(), FileName)
	assert.NoError(t, os.WriteFile(f, []byte(`{nope`), 0o644))
	_, err := Load(f)
	assert.Error(t, err)
	h := newHarness(t, f, &clock{t: t0})
	assert.Empty(t, h.svc.View().Timers)
}
