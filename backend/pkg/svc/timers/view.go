package timers

import (
	"sort"
	"time"
)

// NextDeadline is the earliest running timer or reminder.
func (e *Engine) NextDeadline() (time.Time, bool) {
	var best int64
	for _, t := range e.st.Timers {
		if t.State == StateRunning && (best == 0 || t.EndsAt < best) {
			best = t.EndsAt
		}
	}
	for _, r := range e.st.Reminders {
		if best == 0 || r.At < best {
			best = r.At
		}
	}
	if best == 0 {
		return time.Time{}, false
	}
	return time.UnixMilli(best), true
}

// View snapshots the state with computed time left / elapsed.
func (e *Engine) View() View {
	now := e.nowMs()
	v := View{Now: now, Timers: []Timer{}, Reminders: []Reminder{}}
	for _, t := range e.st.Timers {
		c := e.timerView(t, now)
		switch c.State {
		case StateRinging:
			v.Ringing++
			v.Active = true
		case StateRunning:
			v.Active = true
		}
		v.Timers = append(v.Timers, c)
	}
	for _, r := range e.st.Reminders {
		c := *r
		c.LeftMs = max(r.At-now, 0)
		v.Reminders = append(v.Reminders, c)
	}
	sort.SliceStable(v.Reminders, func(i, j int) bool { return v.Reminders[i].At < v.Reminders[j].At })
	v.Stopwatch = e.swView(now)
	if v.Stopwatch.State == SWRunning {
		v.Active = true
	}
	return v
}

// TimerView is one timer with its time left filled in.
func (e *Engine) TimerView(t *Timer) Timer { return e.timerView(t, e.nowMs()) }

func (e *Engine) timerView(t *Timer, now int64) Timer {
	c := *t
	if t.Pomodoro != nil {
		p := *t.Pomodoro
		c.Pomodoro = &p
	}
	if c.State == StateRunning {
		c.LeftMs = max(c.EndsAt-now, 0)
	}
	return c
}
