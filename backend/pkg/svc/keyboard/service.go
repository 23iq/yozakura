// Package keyboard serves the XKB catalog, the active layout and live
// keyboard apply.
//
// IPC (service "keyboard"):
//
//	catalog  → {layouts, options, groups} from evdev.lst (base.lst fallback), cached
//	active   → {name, index, code, short}
//	next     → switch to the next layout
//	apply    {layouts:[{layout,variant}], switchBind, options, model?, repeatRate, repeatDelay}
//	         → applies the settings live (persisting is the compositor TOML's job)
//	current  → {available, layouts, switchBind, options, model, repeatRate, repeatDelay}:
//	         the settings in effect on the compositor (the user's own config
//	         while the shell does not manage the keyboard), in the keyboard
//	         domain's shape; available is false where the compositor cannot
//	         report them (niri, Mango). Read only.
//
// Events: keyboard.layout {name, index, code, short} on subscribe and on
// every keyboard_layout event yozd reports through the compositor state.
package keyboard

import (
	"bytes"
	"encoding/json"
	"errors"
	"fmt"
	"sync"

	"yozakura/backend/pkg/ipc"
	"yozakura/backend/pkg/svc/compositor"
	"yozakura/backend/pkg/svc/yozdcli"
	yipc "yozakura/backend/pkg/yozd/ipc"
)

// Yozd is the part of the compositor daemon this service needs.
type Yozd interface {
	ApplyKeyboard(yipc.KeyboardSettings) error
	ActiveLayout() (yipc.KeyboardLayoutState, error)
	CurrentKeyboard() (yipc.KeyboardSettings, error)
	NextLayout() error
}

// StateSource streams compositor state (compositor.Manager).
type StateSource interface {
	Subscribe() (<-chan compositor.State, func())
}

// Service is the keyboard IPC service.
type Service struct {
	yozd       Yozd
	src        StateSource
	rulesPaths []string

	catOnce sync.Once
	cat     *Catalog
	catErr  error

	mu    sync.Mutex
	names []string // layout names from the last ActiveLayout (events omit them)
}

// NewService wires the daemon CLI. src may be nil (no layout events).
func NewService(src StateSource) *Service {
	return newService(yozdcli.New(), src, RulesPaths())
}

func newService(y Yozd, src StateSource, rules []string) *Service {
	return &Service{yozd: y, src: src, rulesPaths: rules}
}

// Register exposes the service over IPC.
func (s *Service) Register(srv *ipc.Server) {
	srv.Register(&ipc.Service{
		Name: "keyboard",
		Methods: map[string]ipc.HandlerFunc{
			"catalog": func(json.RawMessage) (any, error) { return s.Catalog() },
			"active":  func(json.RawMessage) (any, error) { return s.Active() },
			"next":    s.next,
			"apply":   s.apply,
			"current": func(json.RawMessage) (any, error) { return s.Current() },
		},
		Subscribe: s.subscribe,
		Async:     map[string]bool{"catalog": true, "active": true, "next": true, "apply": true, "current": true},
	})
}

// Catalog parses the rules list once.
func (s *Service) Catalog() (*Catalog, error) {
	s.catOnce.Do(func() { s.cat, s.catErr = LoadCatalog(s.rulesPaths...) })
	return s.cat, s.catErr
}

// catalogOrEmpty lets the active layout resolve (without codes) when no
// rules list is installed.
func (s *Service) catalogOrEmpty() *Catalog {
	if c, err := s.Catalog(); err == nil {
		return c
	}
	return &Catalog{}
}

// Active asks yozd for the active layout and resolves its index and code.
func (s *Service) Active() (Active, error) {
	st, err := s.yozd.ActiveLayout()
	if err != nil {
		return Active{}, err
	}
	s.mu.Lock()
	s.names = st.Names
	s.mu.Unlock()
	return s.catalogOrEmpty().Resolve(st), nil
}

// Current is the compositor's keyboard settings in the keyboard domain's
// shape (see the package doc).
type Current struct {
	Available bool `json:"available"`
	compositor.KeyboardInput
}

// Current reads the settings in effect. A compositor that cannot report
// them answers {available: false}; a daemon error is an error.
func (s *Service) Current() (Current, error) {
	k, err := s.yozd.CurrentKeyboard()
	if errors.Is(err, yipc.ErrNotSupported) {
		return Current{KeyboardInput: compositor.KeyboardFromSettings(yipc.KeyboardSettings{})}, nil
	}
	if err != nil {
		return Current{}, err
	}
	in := compositor.KeyboardFromSettings(k)
	return Current{Available: len(in.Layouts) > 0, KeyboardInput: in}, nil
}

func (s *Service) next(json.RawMessage) (any, error) {
	if err := s.yozd.NextLayout(); err != nil {
		return nil, err
	}
	return map[string]any{"ok": true}, nil
}

func (s *Service) apply(params json.RawMessage) (any, error) {
	var in compositor.KeyboardInput
	if err := json.Unmarshal(params, &in); err != nil {
		return nil, fmt.Errorf("keyboard.apply: %w", err)
	}
	settings := in.Settings()
	if len(settings.Layouts) == 0 {
		return nil, fmt.Errorf("keyboard.apply: no valid layouts")
	}
	if err := s.yozd.ApplyKeyboard(settings); err != nil {
		return nil, err
	}
	return map[string]any{"ok": true}, nil
}

// layoutEvent turns a compositor-state keyboard_layout payload into the
// resolved layout. Payloads without names (Hyprland) reuse the last names.
func (s *Service) layoutEvent(raw json.RawMessage) (Active, bool) {
	var st yipc.KeyboardLayoutState
	if err := json.Unmarshal(raw, &st); err != nil || st.Name == "" {
		return Active{}, false
	}
	s.mu.Lock()
	if len(st.Names) == 0 {
		st.Names = s.names
	} else {
		s.names = st.Names
	}
	s.mu.Unlock()
	return s.catalogOrEmpty().Resolve(st), true
}

func (s *Service) subscribe(sub *ipc.Subscriber) {
	var ch <-chan compositor.State
	cancel := func() {}
	if s.src != nil {
		ch, cancel = s.src.Subscribe()
	}
	go func() {
		defer cancel()
		// initial state first, in the same goroutine as the events so it
		// can never arrive after a newer switch
		if a, err := s.Active(); err == nil {
			sub.Send("keyboard.layout", a)
		}
		if ch == nil {
			return
		}
		var last json.RawMessage
		for {
			select {
			case st, ok := <-ch:
				if !ok {
					return
				}
				if len(st.KeyboardLayout) == 0 || bytes.Equal(st.KeyboardLayout, last) {
					continue
				}
				last = append(json.RawMessage(nil), st.KeyboardLayout...)
				if a, ok := s.layoutEvent(st.KeyboardLayout); ok {
					sub.Send("keyboard.layout", a)
				}
			case <-sub.StopCh():
				return
			}
		}
	}()
}
