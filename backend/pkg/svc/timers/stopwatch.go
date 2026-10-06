package timers

import (
	"fmt"
	"strings"
	"time"
)

// maxLaps bounds the persisted lap list.
const maxLaps = 999

// StopwatchAction runs one stopwatch action: start, pause, resume, toggle, lap,
// reset or status.
func (e *Engine) StopwatchAction(action string) (Stopwatch, error) {
	sw := &e.st.Stopwatch
	now := e.nowMs()
	switch action {
	case "start", "resume":
		if sw.State != SWRunning {
			sw.State, sw.StartedAt = SWRunning, now
		}
	case "pause", "stop":
		if sw.State == SWRunning {
			sw.AccumMs += now - sw.StartedAt
			sw.State, sw.StartedAt = SWPaused, 0
		}
	case "toggle":
		if sw.State == SWRunning {
			return e.StopwatchAction("pause")
		}
		return e.StopwatchAction("start")
	case "lap":
		if sw.State == SWIdle {
			return e.swView(now), fmt.Errorf("the stopwatch is not running")
		}
		if len(sw.Laps) >= maxLaps {
			return e.swView(now), fmt.Errorf("too many laps")
		}
		total := e.swElapsed(now)
		var prev int64
		if n := len(sw.Laps); n > 0 {
			prev = sw.Laps[n-1].TotalMs
		}
		sw.Laps = append(sw.Laps, Lap{N: len(sw.Laps) + 1, TotalMs: total, SplitMs: total - prev})
	case "reset":
		*sw = Stopwatch{State: SWIdle}
	case "status", "":
	default:
		return e.swView(now), fmt.Errorf("unknown stopwatch action %q (start, pause, resume, toggle, lap, reset, status)", action)
	}
	return e.swView(now), nil
}

// SetStopwatch replaces the stopwatch (undo of a reset).
func (e *Engine) SetStopwatch(sw Stopwatch) {
	if sw.State != SWRunning && sw.State != SWPaused {
		sw = Stopwatch{State: SWIdle}
	}
	sw.ElapsedMs = 0
	e.st.Stopwatch = sw
}

func (e *Engine) swElapsed(now int64) int64 {
	sw := e.st.Stopwatch
	if sw.State == SWRunning {
		return sw.AccumMs + now - sw.StartedAt
	}
	return sw.AccumMs
}

func (e *Engine) swView(now int64) Stopwatch {
	c := e.st.Stopwatch
	c.Laps = append([]Lap{}, c.Laps...)
	c.ElapsedMs = e.swElapsed(now)
	return c
}

// AddReminder schedules a one-shot reminder.
func (e *Engine) AddReminder(at time.Time, message string) (*Reminder, error) {
	now := e.Now()
	if !at.After(now) {
		return nil, fmt.Errorf("the reminder time has passed")
	}
	if at.Sub(now) > 366*24*time.Hour {
		return nil, fmt.Errorf("reminders reach at most a year ahead")
	}
	r := &Reminder{ID: e.newID("r"), Message: strings.TrimSpace(message), At: at.UnixMilli(), CreatedAt: now.UnixMilli()}
	e.st.Reminders = append(e.st.Reminders, r)
	return r, nil
}

// CancelReminder removes a reminder by id or exact message.
func (e *Engine) CancelReminder(ref string) (*Reminder, error) {
	ref = strings.TrimSpace(ref)
	idx := -1
	for i, r := range e.st.Reminders {
		if r.ID == ref {
			idx = i
			break
		}
	}
	if idx < 0 {
		for i, r := range e.st.Reminders {
			if ref != "" && strings.EqualFold(r.Message, ref) {
				if idx >= 0 {
					return nil, fmt.Errorf("several reminders say %q: give an id", ref)
				}
				idx = i
			}
		}
	}
	if idx < 0 && ref == "" && len(e.st.Reminders) == 1 {
		idx = 0
	}
	if idx < 0 {
		return nil, fmt.Errorf("no reminder %q", ref)
	}
	r := e.st.Reminders[idx]
	e.st.Reminders = append(e.st.Reminders[:idx], e.st.Reminders[idx+1:]...)
	return r, nil
}
