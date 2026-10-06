package mango

import (
	"errors"
	"testing"

	"yozakura/backend/pkg/yozd/ipc"
)

func TestParseMangoOutputs(t *testing.T) {
	outs := parseMangoOutputs([]mangoMonitor{
		{Name: "DP-1", Active: 1, X: 0, Y: 0, Width: 2560, Height: 1440, Scale: 150},
		{Name: "HDMI-A-1", Active: 0},
	})
	if len(outs) != 2 {
		t.Fatal(outs)
	}
	a, b := outs[0], outs[1]
	if a.ID != "DP-1" || !a.Enabled || a.Scale != 1.5 || len(a.Modes) != 1 || a.Modes[0] != (ipc.Mode{Width: 2560, Height: 1440}) {
		t.Fatalf("%+v", a)
	}
	if b.Enabled || b.Scale != 1 || len(b.Modes) != 0 {
		t.Fatalf("%+v", b)
	}
}

func TestMangoApplyOutput(t *testing.T) {
	m := &Mango{}
	if err := m.ApplyOutput(ipc.OutputConfig{Name: "DP-1", Enabled: true}); !errors.Is(err, ipc.ErrNotSupported) {
		t.Fatal(err)
	}
	if err := m.ApplyOutput(ipc.OutputConfig{Name: "bad name"}); err == nil || errors.Is(err, ipc.ErrNotSupported) {
		t.Fatal("expected validation error", err)
	}
}
