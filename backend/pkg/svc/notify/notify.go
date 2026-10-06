package notify

import (
	"encoding/json"
	"os/exec"
	"sync"
	"sync/atomic"
	"yozakura/backend/pkg/brand"

	"yozakura/backend/pkg/ipc"
)

// Service exposes a notification-request IPC channel. CLIs that previously
// shelled out to `notify-send` (colorpicker, screen, …) route through this
// service instead so the running Yozakura shell can render the notification
// via its Notifications singleton. The end result: every notification is
// tracked, dismissable, and visible in the popup/notch/dashboard history
// instead of leaking into the system notification daemon.
type Service struct {
	mu        sync.RWMutex
	subs      map[*ipc.Subscriber]struct{}
	nextReqID atomic.Uint64
}

func NewService() *Service {
	return &Service{
		subs: make(map[*ipc.Subscriber]struct{}),
	}
}

func (s *Service) Register(srv *ipc.Server) {
	srv.Register(&ipc.Service{
		Name: "notify",
		Methods: map[string]ipc.HandlerFunc{
			"send": s.send,
		},
		Subscribe: s.subscribe,
	})
}

// SendParams mirrors the shape Notifications.notifyInternal accepts on the
// QML side, plus an optional `actions` field whose entries can carry a
// `clipboard` value — when the user clicks the action, the QML side runs
// `wl-copy` with that value. This is how cross-process colorpicker actions
// stay in sync without requiring the CLI to keep its notification alive.
type SendParams struct {
	Summary       string       `json:"summary"`
	Body          string       `json:"body"`
	AppName       string       `json:"appName"`
	AppIcon       string       `json:"appIcon"`
	Image         string       `json:"image"`
	Urgency       string       `json:"urgency"`
	ExpireTimeout int          `json:"expireTimeout"`
	ReplaceKey    string       `json:"replaceKey"`
	Actions       []SendAction `json:"actions"`
	// SummaryKey / BodyKey name translations (translations/*.json) the
	// shell shows instead of Summary / Body, which stay the English
	// fallback. Args fill %1, %2... of both; an arg may itself be a
	// Text (translated first).
	SummaryKey string `json:"summaryKey,omitempty"`
	BodyKey    string `json:"bodyKey,omitempty"`
	Args       []any  `json:"args,omitempty"`
}

// Text is a translatable notification argument: the shell shows
// I18n.t(Key, Args...) when it knows Key, else Text.
type Text struct {
	Key  string `json:"key"`
	Args []any  `json:"args,omitempty"`
	Text string `json:"text"`
}

type SendAction struct {
	Identifier string `json:"identifier"`
	Text       string `json:"text"`
	LabelKey   string `json:"labelKey,omitempty"` // translation of Text
	Clipboard  string `json:"clipboard,omitempty"`
	// Call is a daemon IPC call the shell makes when the action is clicked
	// (e.g. timers.add {"id":"t3","spec":"5m"} for "+5 min"), so a backend
	// service can react to its own notification's actions.
	Call *ActionCall `json:"call,omitempty"`
}

// ActionCall is one daemon IPC request (service.method + params).
type ActionCall struct {
	Method string `json:"method"`
	Params any    `json:"params,omitempty"`
}

func (s *Service) send(params json.RawMessage) (any, error) {
	var p SendParams
	if err := json.Unmarshal(params, &p); err != nil {
		return nil, err
	}
	id, err := s.Send(p)
	if err != nil {
		return nil, err
	}
	return map[string]any{"requestId": id}, nil
}

// Send pushes a notification request to the subscribed shell. In-process
// services (timers) call it directly.
func (s *Service) Send(p SendParams) (int64, error) {
	if p.Summary == "" && p.Body == "" {
		return 0, &ValidationError{msg: "notify.send: summary or body required"}
	}
	if p.AppName == "" {
		p.AppName = brand.DisplayName
	}

	id := s.nextReqID.Add(1)
	payload := map[string]any{
		"id":            int64(id),
		"summary":       p.Summary,
		"body":          p.Body,
		"appName":       p.AppName,
		"appIcon":       p.AppIcon,
		"image":         p.Image,
		"urgency":       p.Urgency,
		"expireTimeout": p.ExpireTimeout,
		"replaceKey":    p.ReplaceKey,
		"actions":       p.Actions,
	}
	if p.SummaryKey != "" {
		payload["summaryKey"] = p.SummaryKey
	}
	if p.BodyKey != "" {
		payload["bodyKey"] = p.BodyKey
	}
	if len(p.Args) > 0 {
		payload["args"] = p.Args
	}

	s.mu.RLock()
	defer s.mu.RUnlock()
	for sub := range s.subs {
		sub.Send("notify.request", payload)
	}
	return int64(id), nil
}

func (s *Service) subscribe(sub *ipc.Subscriber) {
	s.mu.Lock()
	s.subs[sub] = struct{}{}
	s.mu.Unlock()

	// Block until the subscriber disconnects; the IPC server drains our
	// sends on its own goroutine. Without this select the subscribe
	// callback returns immediately and the server's streamSubscribe
	// goroutine exits before the first event is pumped.
	<-sub.StopCh()

	s.mu.Lock()
	delete(s.subs, sub)
	s.mu.Unlock()
}

// Subscribers returns how many shells listen for notification requests.
func (s *Service) Subscribers() int {
	s.mu.RLock()
	defer s.mu.RUnlock()
	return len(s.subs)
}

// ValidationError reports a malformed notify.send payload.
type ValidationError struct{ msg string }

func (e *ValidationError) Error() string { return e.msg }

// SendFallback writes a notification via notify-send. Used by CLI commands
// when the yozakura daemon is not running (e.g. during early boot or when
// the shell hasn't started yet) so users still see the message instead of
// failing silently.
func SendFallback(summary, body, urgency string) error {
	args := []string{summary, body}
	if urgency != "" {
		args = append(args, "-u", urgency)
	}
	return exec.Command("notify-send", args...).Start()
}
