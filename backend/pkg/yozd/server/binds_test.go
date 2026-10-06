package server

import (
	"errors"
	"testing"

	"yozakura/backend/pkg/yozd/ipc"
	"yozakura/backend/pkg/yozd/ipc/mock"
)

type listerComp struct {
	*mock.Compositor
	binds []ipc.Bind
}

func (l listerComp) ListBinds() ([]ipc.Bind, error) { return l.binds, nil }

func TestListBinds(t *testing.T) {
	if _, err := listBinds(mock.NewCompositor()); !errors.Is(err, ipc.ErrNotSupported) {
		t.Fatalf("plain compositor: want ErrNotSupported, got %v", err)
	}
	got, err := listBinds(listerComp{Compositor: mock.NewCompositor()})
	if err != nil || got == nil || len(got) != 0 {
		t.Fatalf("nil list must become []: %v %v", got, err)
	}
	s := &Server{compositor: listerComp{Compositor: mock.NewCompositor(), binds: []ipc.Bind{{Key: "Q"}}}}
	res, err := s.dispatchExtra(Request{Method: "Config.ListBinds"})
	if err != nil || len(res.([]ipc.Bind)) != 1 {
		t.Fatalf("dispatch: %v %v", res, err)
	}
	if _, err := s.dispatchExtra(Request{Method: "Nope.Nope"}); err == nil || err.Error() != "method not found" {
		t.Fatalf("unknown method: %v", err)
	}
}
