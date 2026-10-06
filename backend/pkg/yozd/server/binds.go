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
