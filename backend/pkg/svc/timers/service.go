package timers

import (
	"log"
	"sync"
	"time"

	"yozakura/backend/pkg/ipc"
	"yozakura/backend/pkg/svc/notify"
)

// maxWait caps the scheduler sleep: Go timers use the monotonic clock,
// which stops during suspend, so the wall clock is re-checked regularly.
const maxWait = 15 * time.Second

// Notifier shows a desktop notification (notify.Service.Send in the daemon).
type Notifier func(notify.SendParams)

// Service is the `timers` IPC service: it owns the engine, persists every
// change, fires timers on time and publishes state + events.
type Service struct {
	mu       sync.Mutex
	eng      *Engine
	path     string
	notify   Notifier
	pomodoro func() PomodoroConfig // defaults for timers.pomodoro (nil: built-in)

	subsMu sync.Mutex
	subs   map[*ipc.Subscriber]struct{}

	wake      chan struct{}
	stop      chan struct{}
	closeOnce sync.Once
}

// Options configure NewService; zero values are fine for tests.
type Options struct {
	Path     string           // timers.json ("" = not persisted)
	Now      func() time.Time // nil: time.Now
	Notify   Notifier
	Pomodoro func() PomodoroConfig
}

// NewService loads the persisted state. Call Start to run the scheduler.
func NewService(o Options) *Service {
	if o.Now == nil {
		o.Now = time.Now
	}
	var st *State
	if o.Path != "" {
		var err error
		if st, err = Load(o.Path); err != nil {
			log.Printf("[timers] %s: %v (starting empty)", o.Path, err)
		}
	}
	return &Service{
		eng: NewEngine(o.Now, st), path: o.Path, notify: o.Notify, pomodoro: o.Pomodoro,
		subs: map[*ipc.Subscriber]struct{}{},
		wake: make(chan struct{}, 1), stop: make(chan struct{}),
	}
}

// Register wires the IPC methods (see methods.go).
func (s *Service) Register(srv *ipc.Server) {
	srv.Register(&ipc.Service{Name: "timers", Methods: s.methods(), Subscribe: s.subscribe})
}

// Start runs the scheduler goroutine; timers that expired while the daemon
// was down fire right away (marked missed).
func (s *Service) Start() { go s.loop() }

// Close stops the scheduler.
func (s *Service) Close() { s.closeOnce.Do(func() { close(s.stop) }) }

func (s *Service) loop() {
	for {
		wait := s.Poll()
		t := time.NewTimer(wait)
		select {
		case <-t.C:
		case <-s.wake:
			t.Stop()
		case <-s.stop:
			t.Stop()
			return
		}
	}
}

// Poll fires what is due (notifications + events) and returns how long to
// sleep before the next check.
func (s *Service) Poll() time.Duration {
	s.mu.Lock()
	evs := s.eng.Tick()
	if len(evs) > 0 {
		s.saveLocked()
	}
	next, ok := s.eng.NextDeadline()
	now := s.eng.Now()
	s.mu.Unlock()
	if len(evs) > 0 {
		for _, ev := range evs {
			s.announce(ev)
		}
		s.broadcast()
	}
	if !ok {
		return maxWait
	}
	return min(max(next.Sub(now)+5*time.Millisecond, 0), maxWait)
}

// mutate runs f under the lock, then persists, reschedules and broadcasts.
func (s *Service) mutate(f func(e *Engine) (any, error)) (any, error) {
	s.mu.Lock()
	res, err := f(s.eng)
	if err == nil {
		s.saveLocked()
	}
	s.mu.Unlock()
	if err != nil {
		return nil, err
	}
	select {
	case s.wake <- struct{}{}:
	default:
	}
	s.broadcast()
	return res, nil
}

func (s *Service) saveLocked() {
	if s.path == "" {
		return
	}
	if err := Save(s.path, s.eng.State()); err != nil {
		log.Printf("[timers] save: %v", err)
	}
}

// View returns the current snapshot.
func (s *Service) View() View {
	s.mu.Lock()
	defer s.mu.Unlock()
	return s.eng.View()
}

func (s *Service) subscribe(sub *ipc.Subscriber) {
	s.subsMu.Lock()
	s.subs[sub] = struct{}{}
	s.subsMu.Unlock()
	sub.Send("timers.state", s.View())
	<-sub.StopCh()
	s.subsMu.Lock()
	delete(s.subs, sub)
	s.subsMu.Unlock()
}

func (s *Service) send(kind string, data any) {
	s.subsMu.Lock()
	defer s.subsMu.Unlock()
	for sub := range s.subs {
		sub.Send(kind, data)
	}
}

func (s *Service) broadcast() { s.send("timers.state", s.View()) }

// announce publishes an event and shows its notification.
func (s *Service) announce(ev Event) {
	s.send("timers.event", ev)
	if s.notify == nil {
		return
	}
	s.notify(notificationFor(ev))
}

func notificationFor(ev Event) notify.SendParams {
	p := notify.SendParams{Body: ev.Message, AppIcon: "alarm-clock", ReplaceKey: "timer-" + ev.ID, Urgency: "normal"}
	// The body as a translatable argument (%1): the event's message, or
	// the user's own text as is.
	body := any(ev.Message)
	if ev.MsgKey != "" {
		p.BodyKey, p.Args = ev.MsgKey, ev.MsgArgs
		body = notify.Text{Key: ev.MsgKey, Args: ev.MsgArgs, Text: ev.Message}
	}
	due := time.UnixMilli(ev.DueAt).Format("15:04")
	switch ev.Kind {
	case "reminder":
		p.Summary, p.SummaryKey, p.Urgency = "Reminder", "notify.reminder.title", "critical"
		if ev.Name == "" {
			p.Body, p.BodyKey, p.Args = "It is "+due, "notify.reminder.it_is", []any{due}
			body = notify.Text{Key: p.BodyKey, Args: p.Args, Text: p.Body}
		}
		p.Actions = []notify.SendAction{
			{Identifier: "snooze", Text: "+5 min", LabelKey: "timers.action.snooze", Call: &notify.ActionCall{Method: "timers.reminderAdd",
				Params: map[string]any{"when": "5m", "message": ev.Name}}},
			{Identifier: "dismiss", Text: "Stop", LabelKey: "timers.action.stop"},
		}
	case "pomodoro":
		p.Summary, p.SummaryKey = "Pomodoro", "notify.pomodoro.title"
		if ev.Done {
			p.Urgency = "critical"
			p.Actions = stopActions(ev.ID)
		}
	default:
		p.Summary, p.Urgency = "Timer", "critical"
		if ev.Name != "" {
			p.Summary = ev.Name
		} else {
			p.SummaryKey = "notify.timer.title"
		}
		p.Actions = stopActions(ev.ID)
	}
	if ev.Missed {
		p.Body += " (due " + due + ")"
		p.BodyKey, p.Args = "notify.missed", []any{body, due}
	}
	return p
}

func stopActions(id string) []notify.SendAction {
	return []notify.SendAction{
		{Identifier: "snooze", Text: "+5 min", LabelKey: "timers.action.snooze", Call: &notify.ActionCall{Method: "timers.add",
			Params: map[string]any{"id": id, "spec": "5m"}}},
		{Identifier: "stop", Text: "Stop", LabelKey: "timers.action.stop", Call: &notify.ActionCall{Method: "timers.dismiss",
			Params: map[string]any{"id": id}}},
	}
}
