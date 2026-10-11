package server

import (
	"errors"
	"testing"

	"yozakura/backend/pkg/yozd/ipc"
	"yozakura/backend/pkg/yozd/ipc/mock"
	"yozakura/backend/pkg/yozd/ipc/niri"
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

func TestSkippedBinds(t *testing.T) {
	s := &Server{compositor: &niri.Niri{}, cfgState: NewConfigState()}
	res, err := s.dispatchExtra(Request{Method: "Config.SkippedBinds"})
	if got, ok := res.([]ipc.SkippedBind); err != nil || !ok || got == nil || len(got) != 0 {
		t.Fatalf("no config yet must be []: %v %v", res, err)
	}
	s.cfgState.Seed(ipc.ConfigUniversal{Keybinds: ipc.ConfigKeybinds{Custom: []ipc.Keybind{
		{Modifiers: []string{"SUPER"}, Key: "V", Dispatcher: "exec", Argument: "a", Enabled: true},
		{Modifiers: []string{"SUPER"}, Key: "V", Dispatcher: "exec", Argument: "b", Flags: "r", Enabled: true},
	}}})
	res, _ = s.dispatchExtra(Request{Method: "Config.SkippedBinds"})
	if got := res.([]ipc.SkippedBind); len(got) != 1 || got[0].Key != "V" {
		t.Fatalf("release bind must be reported: %+v", got)
	}
	// compositors without a skipping generator report nothing
	h := &Server{compositor: mock.NewCompositor(), cfgState: NewConfigState()}
	h.cfgState.Seed(ipc.ConfigUniversal{})
	if got := h.skippedBinds(); got == nil || len(got) != 0 {
		t.Fatalf("mock: %v", got)
	}
}
