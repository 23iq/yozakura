package timers

import (
	"fmt"
	"sort"
	"strconv"
	"strings"
	"time"
)

// missedAfter: an event that fires this late was missed while the daemon
// was down; notifications say so.
const missedAfter = time.Minute

// Engine is the timer state machine. It is not safe for concurrent use
// (Service serialises access) and takes its clock from Now, so tests can
// drive time.
type Engine struct {
	Now func() time.Time
	st  State
}

// NewEngine starts from a persisted state (nil: empty).
func NewEngine(now func() time.Time, st *State) *Engine {
	e := &Engine{Now: now}
	if st != nil {
		e.st = *st
	}
	e.st.Version = 1
	if e.st.Stopwatch.State == "" {
		e.st.Stopwatch.State = SWIdle
	}
	return e
}

// State returns the persistable state.
func (e *Engine) State() State { return e.st }

func (e *Engine) nowMs() int64 { return e.Now().UnixMilli() }

func (e *Engine) newID(prefix string) string {
	e.st.NextID++
	return prefix + strconv.Itoa(e.st.NextID)
}

// Start adds a running countdown.
func (e *Engine) Start(d time.Duration, name string) (*Timer, error) {
	if d < time.Second {
		return nil, fmt.Errorf("timer must be at least 1s")
	}
	if d > 7*24*time.Hour {
		return nil, fmt.Errorf("timer must be shorter than 7 days")
	}
	now := e.nowMs()
	t := &Timer{ID: e.newID("t"), Name: strings.TrimSpace(name), State: StateRunning,
		TotalMs: ms(d), EndsAt: now + ms(d), CreatedAt: now}
	e.st.Timers = append(e.st.Timers, t)
	return t, nil
}

// StartPomodoro adds a Pomodoro timer starting with a work session.
func (e *Engine) StartPomodoro(c PomodoroConfig) (*Timer, error) {
	p := &Pomodoro{WorkMs: ms(c.Work), BreakMs: ms(c.Break), LongBreakMs: ms(c.LongBreak),
		Every: c.Every, Rounds: c.Rounds, Phase: PhaseWork, Round: 1}
	if p.WorkMs <= 0 {
		p.WorkMs = ms(25 * time.Minute)
	}
	if p.BreakMs <= 0 {
		p.BreakMs = ms(5 * time.Minute)
	}
	if p.LongBreakMs <= 0 {
		p.LongBreakMs = ms(15 * time.Minute)
	}
	if p.Every <= 0 {
		p.Every = 4
	}
	if p.Rounds < 0 {
		p.Rounds = 0
	}
	name := c.Name
	if name == "" {
		name = "Pomodoro"
	}
	t, err := e.Start(time.Duration(p.WorkMs)*time.Millisecond, name)
	if err != nil {
		return nil, err
	}
	t.Pomodoro = p
	return t, nil
}

// Find resolves a timer by id, or by name (case-insensitive). An empty ref
// picks the only timer, or the only ringing one.
func (e *Engine) Find(ref string) (*Timer, error) {
	ref = strings.TrimSpace(ref)
	if ref == "" {
		if len(e.st.Timers) == 1 {
			return e.st.Timers[0], nil
		}
		var ringing []*Timer
		for _, t := range e.st.Timers {
			if t.State == StateRinging {
				ringing = append(ringing, t)
			}
		}
		if len(ringing) == 1 {
			return ringing[0], nil
		}
		if len(e.st.Timers) == 0 {
			return nil, fmt.Errorf("no timers")
		}
		return nil, fmt.Errorf("several timers: give an id (%s)", e.ids())
	}
	for _, t := range e.st.Timers {
		if t.ID == ref {
			return t, nil
		}
	}
	var match []*Timer
	for _, t := range e.st.Timers {
		if strings.EqualFold(t.Name, ref) {
			match = append(match, t)
		}
	}
	if len(match) == 1 {
		return match[0], nil
	}
	if len(match) > 1 {
		return nil, fmt.Errorf("several timers named %q: give an id (%s)", ref, e.ids())
	}
	return nil, fmt.Errorf("no timer %q", ref)
}

func (e *Engine) ids() string {
	var out []string
	for _, t := range e.st.Timers {
		s := t.ID
		if t.Name != "" {
			s += " " + t.Name
		}
		out = append(out, s)
	}
	return strings.Join(out, ", ")
}

// Pause freezes a running timer.
func (e *Engine) Pause(ref string) (*Timer, error) {
	t, err := e.Find(ref)
	if err != nil {
		return nil, err
	}
	if t.State != StateRunning {
		return nil, fmt.Errorf("timer %s is %s", t.ID, t.State)
	}
	t.LeftMs = max(t.EndsAt-e.nowMs(), 0)
	t.EndsAt = 0
	t.State = StatePaused
	return t, nil
}

// Resume restarts a paused timer.
func (e *Engine) Resume(ref string) (*Timer, error) {
	t, err := e.Find(ref)
	if err != nil {
		return nil, err
	}
	if t.State != StatePaused {
		return nil, fmt.Errorf("timer %s is %s", t.ID, t.State)
	}
	t.EndsAt = e.nowMs() + t.LeftMs
	t.LeftMs = 0
	t.State = StateRunning
	return t, nil
}

// Add changes the time left by d (negative shortens it). On a ringing timer
// it snoozes: the timer runs again for d.
func (e *Engine) Add(ref string, d time.Duration) (*Timer, error) {
	t, err := e.Find(ref)
	if err != nil {
		return nil, err
	}
	switch t.State {
	case StateRinging:
		if d <= 0 {
			return nil, fmt.Errorf("snooze needs a positive time")
		}
		t.State, t.TotalMs, t.EndsAt, t.FinishedAt = StateRunning, ms(d), e.nowMs()+ms(d), 0
	case StateRunning:
		t.EndsAt += ms(d)
		t.TotalMs = max(t.TotalMs+ms(d), 1000)
	case StatePaused:
		t.LeftMs = max(t.LeftMs+ms(d), 0)
		t.TotalMs = max(t.TotalMs+ms(d), 1000)
	}
	return t, nil
}

// Reset starts the current run over (a ringing timer restarts).
func (e *Engine) Reset(ref string) (*Timer, error) {
	t, err := e.Find(ref)
	if err != nil {
		return nil, err
	}
	if t.State == StatePaused {
		t.LeftMs = t.TotalMs
		return t, nil
	}
	t.State, t.EndsAt, t.LeftMs, t.FinishedAt = StateRunning, e.nowMs()+t.TotalMs, 0, 0
	return t, nil
}

// Cancel removes a timer and returns it.
func (e *Engine) Cancel(ref string) (*Timer, error) {
	t, err := e.Find(ref)
	if err != nil {
		return nil, err
	}
	e.remove(t.ID)
	return t, nil
}

// Dismiss stops ringing timers: the one named by ref, or all with ref "".
func (e *Engine) Dismiss(ref string) ([]*Timer, error) {
	var out []*Timer
	if strings.TrimSpace(ref) != "" {
		t, err := e.Find(ref)
		if err != nil {
			return nil, err
		}
		e.remove(t.ID)
		return []*Timer{t}, nil
	}
	for _, t := range append([]*Timer(nil), e.st.Timers...) {
		if t.State == StateRinging {
			e.remove(t.ID)
			out = append(out, t)
		}
	}
	return out, nil
}

// Restore puts back a cancelled timer (undo).
func (e *Engine) Restore(t Timer) (*Timer, error) {
	if t.ID == "" || (t.State != StateRunning && t.State != StatePaused && t.State != StateRinging) {
		return nil, fmt.Errorf("not a timer")
	}
	if _, err := e.Find(t.ID); err == nil {
		return nil, fmt.Errorf("timer %s exists", t.ID)
	}
	c := t
	e.st.Timers = append(e.st.Timers, &c)
	return &c, nil
}

func (e *Engine) remove(id string) {
	for i, t := range e.st.Timers {
		if t.ID == id {
			e.st.Timers = append(e.st.Timers[:i], e.st.Timers[i+1:]...)
			return
		}
	}
}

// Tick fires everything due and returns the events, oldest first.
func (e *Engine) Tick() []Event {
	now := e.nowMs()
	var evs []Event
	for _, t := range e.st.Timers {
		for t.State == StateRunning && t.EndsAt <= now {
			evs = append(evs, e.fire(t, now))
		}
	}
	keep := e.st.Reminders[:0]
	for _, r := range e.st.Reminders {
		if r.At > now {
			keep = append(keep, r)
			continue
		}
		msg := r.Message
		if msg == "" {
			msg = "Reminder"
		}
		evs = append(evs, Event{Kind: "reminder", ID: r.ID, Name: r.Message, Message: msg,
			Done: true, Missed: now-r.At > ms(missedAfter), DueAt: r.At})
	}
	e.st.Reminders = keep
	sort.SliceStable(evs, func(i, j int) bool { return evs[i].DueAt < evs[j].DueAt })
	return evs
}

// fire handles one expiry of a running timer.
func (e *Engine) fire(t *Timer, now int64) Event {
	due := t.EndsAt
	ev := Event{Kind: "timer", ID: t.ID, Name: t.Name, DueAt: due, Missed: now-due > ms(missedAfter)}
	if p := t.Pomodoro; p != nil {
		ev.Kind = "pomodoro"
		next, length := p.next()
		if next != "" {
			if next == PhaseWork {
				p.Round++
			}
			p.Phase = next
			t.TotalMs, t.EndsAt = length, due+length
			ev.Phase = next
			ev.Message = pomodoroMessage(next, length)
			return ev
		}
		ev.Message = "Pomodoro complete"
	}
	t.State, t.EndsAt, t.LeftMs, t.FinishedAt = StateRinging, 0, 0, due
	ev.Done = true
	if ev.Message == "" {
		ev.Message = "Timer " + FormatDuration(time.Duration(t.TotalMs)*time.Millisecond) + " finished"
	}
	return ev
}

// next returns the phase after the current one ("" when the Pomodoro is
// complete) and its length.
func (p *Pomodoro) next() (string, int64) {
	if p.Phase != PhaseWork {
		return PhaseWork, p.WorkMs
	}
	if p.Rounds > 0 && p.Round >= p.Rounds {
		return "", 0
	}
	if p.Every > 0 && p.Round%p.Every == 0 {
		return PhaseLongBreak, p.LongBreakMs
	}
	return PhaseBreak, p.BreakMs
}

func pomodoroMessage(phase string, length int64) string {
	d := FormatDuration(time.Duration(length) * time.Millisecond)
	switch phase {
	case PhaseBreak:
		return "Work session done: take a " + d + " break"
	case PhaseLongBreak:
		return "Work session done: take a long " + d + " break"
	}
	return "Break over: " + d + " of focus"
}
