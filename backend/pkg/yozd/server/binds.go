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
