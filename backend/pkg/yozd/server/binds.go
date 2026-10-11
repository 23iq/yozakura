package server

import (
	"errors"

	"yozakura/backend/pkg/yozd/ipc"
)

var errMethodNotFound = errors.New("method not found")

// dispatchExtra handles the methods kept out of the main switch in
// server.go (which is already large): add new read-only queries here.
func (s *Server) dispatchExtra(req Request) (interface{}, error) {
	switch req.Method {
	case "Config.ListBinds":
		return listBinds(s.compositor)
	case "Config.Errors":
		return configErrors(s.compositor)
	case "Config.SkippedBinds":
		return s.skippedBinds(), nil
	}
	if res, handled, err := s.dispatchOutputs(req); handled {
		return res, err
	}
	return nil, errMethodNotFound
}

// listBinds returns the compositor's key binds (ErrNotSupported when it
// cannot list them); never nil, so the reply is [] rather than "ok".
func listBinds(c ipc.Compositor) ([]ipc.Bind, error) {
	l, ok := c.(ipc.BindLister)
	if !ok {
		return nil, ipc.ErrNotSupported
	}
	binds, err := l.ListBinds()
	if err != nil {
		return nil, err
	}
	if binds == nil {
		binds = []ipc.Bind{}
	}
	return binds, nil
}

// configErrors returns the errors of the compositor's last config load
// (ErrNotSupported when it cannot tell); never nil.
func configErrors(c ipc.Compositor) ([]string, error) {
	l, ok := c.(ipc.ConfigErrorLister)
	if !ok {
		return nil, ipc.ErrNotSupported
	}
	errs, err := l.ConfigErrors()
	if errs == nil {
		errs = []string{}
	}
	return errs, err
}

// skippedBinds lists the binds of the applied config that the generated
// compositor config leaves out (never nil; [] when the compositor writes
// everything or no config was applied yet).
func (s *Server) skippedBinds() []ipc.SkippedBind {
	out := []ipc.SkippedBind{}
	payload, ok := s.cfgState.Current()
	if !ok {
		return out
	}
	gen := NewConfigHandler(s.compositor).generator
	if sk, ok := gen.(ipc.BindSkipper); ok {
		out = append(out, sk.SkippedKeybinds(payload.Keybinds)...)
	}
	return out
}
