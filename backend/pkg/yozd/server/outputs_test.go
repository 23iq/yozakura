package server

import (
	"encoding/json"
	"errors"
	"testing"

	"yozakura/backend/pkg/yozd/ipc"
	"yozakura/backend/pkg/yozd/ipc/mock"
)

// bareComp hides the mock's optional interfaces.
type bareComp struct{ ipc.Compositor }

func call(t *testing.T, s *Server, method string, params interface{}) (interface{}, error) {
	t.Helper()
	raw, _ := json.Marshal(params)
	res, handled, err := s.dispatchOutputs(Request{Method: method, Params: raw})
	if !handled {
		t.Fatalf("%s not handled", method)
	}
	return res, err
}

func TestMonitorOutputs(t *testing.T) {
	m := mock.NewCompositor()
	s := &Server{compositor: m}
	res, err := call(t, s, "Monitor.Outputs", nil)
	if err != nil || res.([]ipc.Output) == nil || len(res.([]ipc.Output)) != 0 {
		t.Fatalf("empty must be []: %#v %v", res, err)
	}
	m.Outputs = []ipc.Output{{Name: "DP-1"}}
	res, _ = call(t, s, "Monitor.Outputs", nil)
	b, _ := json.Marshal(res)
	if string(b) == "null" || res.([]ipc.Output)[0].Modes == nil {
		t.Fatalf("modes must be []: %s", b)
	}
	if _, err := call(t, &Server{compositor: bareComp{m}}, "Monitor.Outputs", nil); !errors.Is(err, ipc.ErrNotSupported) {
		t.Fatalf("want ErrNotSupported, got %v", err)
	}
}

func TestMonitorApply(t *testing.T) {
	m := mock.NewCompositor()
	s := &Server{compositor: m}
	cfg := ipc.OutputConfig{Name: "DP-1", Enabled: true, Width: 1920, Height: 1080}
	if _, err := call(t, s, "Monitor.Apply", cfg); err != nil {
		t.Fatal(err)
	}
	if len(m.ApplyOutputCalls) != 1 || m.ApplyOutputCalls[0] != cfg {
		t.Fatalf("calls: %v", m.ApplyOutputCalls)
	}
	if _, err := call(t, s, "Monitor.Apply", ipc.OutputConfig{Name: "DP 1;rm"}); err == nil {
		t.Fatal("invalid name accepted")
	}
	if len(m.ApplyOutputCalls) != 1 {
		t.Fatalf("invalid config reached compositor: %v", m.ApplyOutputCalls)
	}
	if _, err := call(t, &Server{compositor: bareComp{m}}, "Monitor.Apply", cfg); !errors.Is(err, ipc.ErrNotSupported) {
		t.Fatalf("want ErrNotSupported, got %v", err)
	}
}

func TestKeyboardApplyActive(t *testing.T) {
	m := mock.NewCompositor()
	s := &Server{compositor: m}
	k := ipc.KeyboardSettings{Layouts: []string{"us", "ru"}, Options: []string{"caps:escape"}}
	if _, err := call(t, s, "Keyboard.Apply", k); err != nil {
		t.Fatal(err)
	}
	if len(m.ApplyKeyboardCalls) != 1 || len(m.ApplyKeyboardCalls[0].Variants) != 2 {
		t.Fatalf("want normalized call, got %v", m.ApplyKeyboardCalls)
	}
	if _, err := call(t, s, "Keyboard.Apply", ipc.KeyboardSettings{Layouts: []string{"u s;"}}); err == nil {
		t.Fatal("invalid layout accepted")
	}
	if len(m.ApplyKeyboardCalls) != 1 {
		t.Fatal("invalid settings reached compositor")
	}
	res, err := call(t, s, "Keyboard.Active", nil)
	if err != nil || res.(ipc.KeyboardLayoutState).Names == nil {
		t.Fatalf("active: %#v %v", res, err)
	}
	bare := &Server{compositor: bareComp{m}}
	if _, err := call(t, bare, "Keyboard.Active", nil); !errors.Is(err, ipc.ErrNotSupported) {
		t.Fatalf("want ErrNotSupported, got %v", err)
	}
	if _, err := call(t, bare, "Keyboard.Apply", k); !errors.Is(err, ipc.ErrNotSupported) {
		t.Fatalf("want ErrNotSupported, got %v", err)
	}
}
