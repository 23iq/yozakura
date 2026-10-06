package timers

import (
	"encoding/json"
	"fmt"
	"strings"
	"time"

	"yozakura/backend/pkg/ipc"
)

// args is the union of every method's params. Durations come as a human
// spec ("10m", "1h30", "-5m" for add) or as seconds.
type args struct {
	ID        string          `json:"id"`
	Name      string          `json:"name"`
	Spec      string          `json:"spec"`
	Seconds   float64         `json:"seconds"`
	Text      string          `json:"text"`
	Action    string          `json:"action"`
	When      string          `json:"when"`
	At        int64           `json:"at"`
	Message   string          `json:"message"`
	Work      json.RawMessage `json:"work"`
	Break     json.RawMessage `json:"break"`
	LongBreak json.RawMessage `json:"longBreak"`
	Every     int             `json:"every"`
	Rounds    int             `json:"rounds"`
	Timer     *Timer          `json:"timer"`
	Stopwatch *Stopwatch      `json:"stopwatch"`
}

func parseArgs(raw json.RawMessage) (args, error) {
	var a args
	if len(raw) > 0 && string(raw) != "null" {
		if err := json.Unmarshal(raw, &a); err != nil {
			return a, fmt.Errorf("invalid params: %v", err)
		}
	}
	return a, nil
}

// duration reads spec or seconds; signed allows a leading "-" (add).
func (a args) duration(signed bool) (time.Duration, error) {
	spec := strings.TrimSpace(a.Spec)
	if spec == "" {
		if a.Seconds == 0 {
			return 0, fmt.Errorf("give a time: spec (\"10m\", \"1h30\") or seconds")
		}
		if a.Seconds < 0 && !signed {
			return 0, fmt.Errorf("time must be positive")
		}
		return time.Duration(a.Seconds * float64(time.Second)), nil
	}
	neg := false
	if signed {
		if rest, ok := strings.CutPrefix(spec, "-"); ok {
			spec, neg = rest, true
		} else {
			spec = strings.TrimPrefix(spec, "+")
		}
	}
	d, err := ParseDuration(spec)
	if neg {
		d = -d
	}
	return d, err
}

// optDuration reads a pomodoro length: a spec string or seconds.
func optDuration(raw json.RawMessage) (time.Duration, error) {
	if len(raw) == 0 || string(raw) == "null" {
		return 0, nil
	}
	var n float64
	if json.Unmarshal(raw, &n) == nil {
		return time.Duration(n * float64(time.Second)), nil
	}
	var s string
	if err := json.Unmarshal(raw, &s); err != nil || strings.TrimSpace(s) == "" {
		return 0, nil
	}
	return ParseDuration(s)
}

type handler func(e *Engine, a args) (any, error)

func (s *Service) methods() map[string]ipc.HandlerFunc {
	write := func(h handler) ipc.HandlerFunc {
		return func(raw json.RawMessage) (any, error) {
			a, err := parseArgs(raw)
			if err != nil {
				return nil, err
			}
			return s.mutate(func(e *Engine) (any, error) { return h(e, a) })
		}
	}
	read := func(h handler) ipc.HandlerFunc {
		return func(raw json.RawMessage) (any, error) {
			a, err := parseArgs(raw)
			if err != nil {
				return nil, err
			}
			s.mu.Lock()
			defer s.mu.Unlock()
			return h(s.eng, a)
		}
	}
	one := func(op func(e *Engine, ref string) (*Timer, error)) ipc.HandlerFunc {
		return write(func(e *Engine, a args) (any, error) {
			t, err := op(e, a.ID)
			if err != nil {
				return nil, err
			}
			return map[string]any{"timer": e.TimerView(t)}, nil
		})
	}
	return map[string]ipc.HandlerFunc{
		"list":   read(func(e *Engine, _ args) (any, error) { return e.View(), nil }),
		"parse":  read(parseMethod),
		"start":  write(startMethod),
		"quick":  write(s.quickMethod),
		"pause":  one((*Engine).Pause),
		"resume": one((*Engine).Resume),
		"reset":  one((*Engine).Reset),
		"cancel": one((*Engine).Cancel),
		"add": write(func(e *Engine, a args) (any, error) {
			d, err := a.duration(true)
			if err != nil {
				return nil, err
			}
			t, err := e.Add(a.ID, d)
			if err != nil {
				return nil, err
			}
			return map[string]any{"timer": e.TimerView(t), "addedSeconds": d.Seconds()}, nil
		}),
		"dismiss": write(func(e *Engine, a args) (any, error) {
			ts, err := e.Dismiss(a.ID)
			if err != nil {
				return nil, err
			}
			return map[string]any{"dismissed": len(ts)}, nil
		}),
		"restore": write(func(e *Engine, a args) (any, error) {
			if a.Timer == nil {
				return nil, fmt.Errorf("timer is required")
			}
			t, err := e.Restore(*a.Timer)
			if err != nil {
				return nil, err
			}
			return map[string]any{"timer": e.TimerView(t)}, nil
		}),
		"pomodoro": write(s.pomodoroMethod),
		"stopwatch": write(func(e *Engine, a args) (any, error) {
			before := e.swView(e.nowMs())
			sw, err := e.StopwatchAction(a.Action)
			if err != nil {
				return nil, err
			}
			return map[string]any{"stopwatch": sw, "previous": before}, nil
		}),
		"stopwatchSet": write(func(e *Engine, a args) (any, error) {
			if a.Stopwatch == nil {
				return nil, fmt.Errorf("stopwatch is required")
			}
			e.SetStopwatch(*a.Stopwatch)
			return map[string]any{"stopwatch": e.swView(e.nowMs())}, nil
		}),
		"reminderAdd": write(reminderAddMethod),
		"reminderCancel": write(func(e *Engine, a args) (any, error) {
			r, err := e.CancelReminder(a.ID)
			if err != nil {
				return nil, err
			}
			return map[string]any{"reminder": r}, nil
		}),
	}
}

func parseMethod(e *Engine, a args) (any, error) {
	text := a.Text
	if text == "" {
		text = a.Spec
	}
	it, err := ParseQuick(text, e.Now())
	if err != nil {
		return nil, err
	}
	return it, nil
}

func startMethod(e *Engine, a args) (any, error) {
	var d time.Duration
	if strings.TrimSpace(a.Spec) != "" {
		sp, err := ParseSpec(a.Spec, e.Now())
		if err != nil {
			return nil, err
		}
		d = sp.Until(e.Now()).Round(time.Second)
	} else {
		var err error
		if d, err = a.duration(false); err != nil {
			return nil, err
		}
	}
	t, err := e.Start(d, a.Name)
	if err != nil {
		return nil, err
	}
	return map[string]any{"timer": e.TimerView(t)}, nil
}

func (s *Service) pomodoroMethod(e *Engine, a args) (any, error) {
	c := PomodoroConfig{Name: a.Name, Every: a.Every, Rounds: a.Rounds}
	if s.pomodoro != nil {
		def := s.pomodoro()
		c.Work, c.Break = def.Work, def.Break
	}
	for _, f := range []struct {
		raw json.RawMessage
		dst *time.Duration
	}{{a.Work, &c.Work}, {a.Break, &c.Break}, {a.LongBreak, &c.LongBreak}} {
		d, err := optDuration(f.raw)
		if err != nil {
			return nil, err
		}
		if d > 0 {
			*f.dst = d
		}
	}
	t, err := e.StartPomodoro(c)
	if err != nil {
		return nil, err
	}
	return map[string]any{"timer": e.TimerView(t)}, nil
}

func reminderAddMethod(e *Engine, a args) (any, error) {
	var at time.Time
	switch {
	case a.At > 0:
		at = time.UnixMilli(a.At)
	case strings.TrimSpace(a.When) != "":
		sp, err := ParseSpec(a.When, e.Now())
		if err != nil {
			return nil, err
		}
		at = sp.Deadline(e.Now())
	default:
		return nil, fmt.Errorf(`give "when" ("18:00", "in 20m", "7:30pm") or "at" (unix ms)`)
	}
	r, err := e.AddReminder(at, a.Message)
	if err != nil {
		return nil, err
	}
	c := *r
	c.LeftMs = r.At - e.nowMs()
	return map[string]any{"reminder": c}, nil
}

// quickMethod runs a quick-input line ("10m tea", "sw", "18:00 call mom").
func (s *Service) quickMethod(e *Engine, a args) (any, error) {
	it, err := ParseQuick(a.Text, e.Now())
	if err != nil {
		return nil, err
	}
	out := map[string]any{"intent": it}
	var res any
	switch it.Kind {
	case "timer":
		res, err = startMethod(e, args{Seconds: it.Spec.Duration.Seconds(), Name: it.Name})
	case "reminder":
		res, err = reminderAddMethod(e, args{At: it.At, Message: it.Name})
	case "stopwatch":
		var sw Stopwatch
		sw, err = e.StopwatchAction("toggle")
		res = map[string]any{"stopwatch": sw}
	case "pomodoro":
		w, _ := json.Marshal(it.Work.Seconds())
		b, _ := json.Marshal(it.Break.Seconds())
		pa := args{}
		if it.Work > 0 {
			pa.Work = w
		}
		if it.Break > 0 {
			pa.Break = b
		}
		res, err = s.pomodoroMethod(e, pa)
	}
	if err != nil {
		return nil, err
	}
	for k, v := range res.(map[string]any) {
		out[k] = v
	}
	return out, nil
}
