package svc

import (
	"sync"
	"time"

	"yozakura/backend/pkg/ipc"
)

// UIPendingTTL is how long a UI command sent while no shell listens (the
// shell is starting or being restarted after a crash) waits for one. Older
// commands are dropped: a launcher opening long after the key press is
// worse than nothing.
const UIPendingTTL = 10 * time.Second

// Results of ui.run / ui.toggle.
const (
	UIDelivered   = "ok"          // a shell received it
	UIQueued      = "queued"      // no shell yet; delivered when one subscribes
	UIUndelivered = "undelivered" // no shell and the caller asked not to queue
)

// UIService bridges `yozakura run <cmd>` to the QML shell via a subscription stream.
// QML subscribes to the "ui" service; commands pushed as ServiceEvent{Service:"ui.command", Data: cmd}.
type UIService struct {
	mu      sync.Mutex
	subs    map[*ipc.Subscriber]struct{}
	pending []pendingUI
	now     func() time.Time
}

type pendingUI struct {
	kind, cmd string
	at        time.Time
}

func NewUIService() *UIService {
	return &UIService{subs: make(map[*ipc.Subscriber]struct{}), now: time.Now}
}

// Register wires the service into the server.
func (u *UIService) Register(srv *ipc.Server) {
	srv.Register(&ipc.Service{
		Name: "ui",
		Methods: map[string]ipc.HandlerFunc{
			"run":    u.run,
			"toggle": u.toggle,
		},
		Subscribe: u.subscribe,
	})
}

func (u *UIService) run(params RawParams) (any, error) {
	p := ParseParams(params)
	cmd := p.Str("command")
	if cmd == "" {
		return nil, errorsNew("ui.run: missing command")
	}
	return u.send("ui.command", cmd, p.Bool("noQueue", false)), nil
}

// toggle carries state-flipping commands (e.g. bar) as a distinct event
// kind, separate from the run actions.
func (u *UIService) toggle(params RawParams) (any, error) {
	p := ParseParams(params)
	cmd := p.Str("command")
	if cmd == "" {
		return nil, errorsNew("ui.toggle: missing command")
	}
	return u.send("ui.toggle", cmd, p.Bool("noQueue", false)), nil
}

// Run pushes a UI command (same as `<app> run <cmd>`) from inside the daemon.
func (u *UIService) Run(cmd string) {
	u.send("ui.command", cmd, false)
}

// send delivers to every live shell, or queues for the next one unless
// noQueue (the caller then handles the command itself).
func (u *UIService) send(kind, cmd string, noQueue bool) string {
	u.mu.Lock()
	defer u.mu.Unlock()
	if len(u.subs) > 0 {
		for sub := range u.subs {
			sub.Send(kind, cmd)
		}
		return UIDelivered
	}
	if noQueue {
		return UIUndelivered
	}
	u.pending = append(u.prune(), pendingUI{kind: kind, cmd: cmd, at: u.now()})
	return UIQueued
}

// prune drops queued commands older than UIPendingTTL. Caller holds mu.
func (u *UIService) prune() []pendingUI {
	cut := u.now().Add(-UIPendingTTL)
	kept := u.pending[:0]
	for _, p := range u.pending {
		if p.at.After(cut) {
			kept = append(kept, p)
		}
	}
	return kept
}

// Subscribers returns how many shells listen for UI commands.
func (u *UIService) Subscribers() int {
	u.mu.Lock()
	defer u.mu.Unlock()
	return len(u.subs)
}

func (u *UIService) subscribe(sub *ipc.Subscriber) {
	u.mu.Lock()
	u.subs[sub] = struct{}{}
	for _, p := range u.prune() {
		sub.Send(p.kind, p.cmd)
	}
	u.pending = nil
	u.mu.Unlock()

	// A crashed shell's stream ends here; forget it so commands sent while
	// its replacement starts are queued instead of lost on a dead stream.
	<-sub.StopCh()
	u.mu.Lock()
	delete(u.subs, sub)
	u.mu.Unlock()
}
