package timers

import (
	"testing"
	"time"

	"github.com/stretchr/testify/assert"
)

type clock struct{ t time.Time }

func (c *clock) now() time.Time          { return c.t }
func (c *clock) advance(d time.Duration) { c.t = c.t.Add(d) }

func newEngine() (*Engine, *clock) {
	c := &clock{t: t0}
	return NewEngine(c.now, nil), c
}

func TestTimerLifecycle(t *testing.T) {
	e, c := newEngine()
	tm, err := e.Start(10*time.Minute, "tea")
	assert.NoError(t, err)
	assert.Equal(t, "t1", tm.ID)
	assert.Equal(t, StateRunning, tm.State)

	c.advance(4 * time.Minute)
	assert.Empty(t, e.Tick())
	_, err = e.Pause("tea") // by name
	assert.NoError(t, err)
	assert.EqualValues(t, ms(6*time.Minute), tm.LeftMs)

	c.advance(time.Hour) // paused: no time passes
	assert.Empty(t, e.Tick())
	assert.EqualValues(t, ms(6*time.Minute), e.View().Timers[0].LeftMs)

	_, err = e.Resume("")
	assert.NoError(t, err)
	_, err = e.Add("t1", time.Minute)
	assert.NoError(t, err)
	c.advance(6*time.Minute + 59*time.Second)
	assert.Empty(t, e.Tick())
	c.advance(time.Second)
	evs := e.Tick()
	assert.Len(t, evs, 1)
	assert.Equal(t, "timer", evs[0].Kind)
	assert.Equal(t, "tea", evs[0].Name)
	assert.True(t, evs[0].Done)
	assert.False(t, evs[0].Missed)
	assert.Equal(t, StateRinging, tm.State)
	v := e.View()
	assert.Equal(t, 1, v.Ringing)
	assert.True(t, v.Active)

	// Snooze: +5 min on a ringing timer runs it again.
	_, err = e.Add("t1", 5*time.Minute)
	assert.NoError(t, err)
	assert.Equal(t, StateRunning, tm.State)
	c.advance(5 * time.Minute)
	assert.Len(t, e.Tick(), 1)

	ds, err := e.Dismiss("")
	assert.NoError(t, err)
	assert.Len(t, ds, 1)
	assert.Empty(t, e.View().Timers)
	assert.False(t, e.View().Active)
}

func TestTimerErrorsAndLookup(t *testing.T) {
	e, c := newEngine()
	_, err := e.Start(0, "")
	assert.Error(t, err)
	_, err = e.Pause("")
	assert.ErrorContains(t, err, "no timers")
	a, _ := e.Start(time.Minute, "a")
	_, _ = e.Start(time.Minute, "b")
	_, err = e.Pause("")
	assert.ErrorContains(t, err, "several timers")
	_, err = e.Resume("a")
	assert.ErrorContains(t, err, "running")
	_, err = e.Pause("zzz")
	assert.Error(t, err)

	// Reset restarts the current run; cancel removes; restore puts back.
	c.advance(30 * time.Second)
	_, _ = e.Reset("a")
	assert.EqualValues(t, ms(time.Minute), e.TimerView(a).LeftMs)
	got, err := e.Cancel("a")
	assert.NoError(t, err)
	assert.Len(t, e.View().Timers, 1)
	_, err = e.Restore(*got)
	assert.NoError(t, err)
	assert.Len(t, e.View().Timers, 2)
	_, err = e.Restore(*got)
	assert.Error(t, err)

	// Negative add can make a timer due at once.
	_, _ = e.Add("b", -2*time.Minute)
	assert.Len(t, e.Tick(), 1)
}

func TestPomodoroCycles(t *testing.T) {
	e, c := newEngine()
	tm, err := e.StartPomodoro(PomodoroConfig{Work: 25 * time.Minute, Break: 5 * time.Minute,
		LongBreak: 15 * time.Minute, Every: 2, Rounds: 3})
	assert.NoError(t, err)
	assert.Equal(t, "Pomodoro", tm.Name)

	step := func(d time.Duration, phase string, done bool) {
		t.Helper()
		c.advance(d)
		evs := e.Tick()
		if assert.Len(t, evs, 1) {
			assert.Equal(t, "pomodoro", evs[0].Kind)
			assert.Equal(t, phase, evs[0].Phase)
			assert.Equal(t, done, evs[0].Done)
		}
	}
	step(25*time.Minute, PhaseBreak, false)
	step(5*time.Minute, PhaseWork, false)
	assert.Equal(t, 2, tm.Pomodoro.Round)
	step(25*time.Minute, PhaseLongBreak, false) // every 2nd session
	step(15*time.Minute, PhaseWork, false)
	step(25*time.Minute, "", true) // 3 rounds: complete
	assert.Equal(t, StateRinging, tm.State)
}

func TestPomodoroCatchesUpByWallClock(t *testing.T) {
	e, c := newEngine()
	_, _ = e.StartPomodoro(PomodoroConfig{}) // 25/5/15 every 4, endless
	c.advance(25*time.Minute + 5*time.Minute + 10*time.Minute)
	evs := e.Tick()
	assert.Len(t, evs, 2) // work -> break -> work, now 10 min into round 2
	assert.True(t, evs[0].Missed)
	tm := e.View().Timers[0]
	assert.Equal(t, PhaseWork, tm.Pomodoro.Phase)
	assert.Equal(t, 2, tm.Pomodoro.Round)
	assert.EqualValues(t, ms(15*time.Minute), tm.LeftMs)
}

func TestStopwatch(t *testing.T) {
	e, c := newEngine()
	_, err := e.StopwatchAction("lap")
	assert.Error(t, err)
	sw, _ := e.StopwatchAction("start")
	assert.Equal(t, SWRunning, sw.State)
	c.advance(10 * time.Second)
	_, _ = e.StopwatchAction("lap")
	c.advance(5 * time.Second)
	sw, _ = e.StopwatchAction("lap")
	assert.Equal(t, []Lap{{N: 1, TotalMs: 10000, SplitMs: 10000}, {N: 2, TotalMs: 15000, SplitMs: 5000}}, sw.Laps)
	sw, _ = e.StopwatchAction("toggle")
	assert.Equal(t, SWPaused, sw.State)
	c.advance(time.Hour)
	sw, _ = e.StopwatchAction("status")
	assert.EqualValues(t, 15000, sw.ElapsedMs)
	_, _ = e.StopwatchAction("toggle")
	c.advance(time.Second)
	assert.EqualValues(t, 16000, e.View().Stopwatch.ElapsedMs)
	prev := e.View().Stopwatch
	sw, _ = e.StopwatchAction("reset")
	assert.Equal(t, SWIdle, sw.State)
	assert.Empty(t, sw.Laps)
	e.SetStopwatch(prev)
	assert.EqualValues(t, 16000, e.View().Stopwatch.ElapsedMs)
	_, err = e.StopwatchAction("explode")
	assert.Error(t, err)
}

func TestReminders(t *testing.T) {
	e, c := newEngine()
	_, err := e.AddReminder(t0.Add(-time.Minute), "past")
	assert.Error(t, err)
	r1, _ := e.AddReminder(t0.Add(2*time.Hour), "late")
	r2, _ := e.AddReminder(t0.Add(time.Hour), "call mom")
	assert.Equal(t, []string{r2.ID, r1.ID}, []string{e.View().Reminders[0].ID, e.View().Reminders[1].ID})
	next, ok := e.NextDeadline()
	assert.True(t, ok)
	assert.Equal(t, t0.Add(time.Hour).UnixMilli(), next.UnixMilli())

	_, err = e.CancelReminder("late")
	assert.NoError(t, err)
	c.advance(time.Hour + 2*time.Minute)
	evs := e.Tick()
	if assert.Len(t, evs, 1) {
		assert.Equal(t, "reminder", evs[0].Kind)
		assert.Equal(t, "call mom", evs[0].Message)
		assert.True(t, evs[0].Missed)
	}
	assert.Empty(t, e.View().Reminders)
	_, ok = e.NextDeadline()
	assert.False(t, ok)
}
