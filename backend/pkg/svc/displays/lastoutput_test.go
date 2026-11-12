package displays

import (
	"encoding/json"
	"errors"
	"testing"

	"yozakura/backend/pkg/yozd/ipc"
)

func TestApplyRefusesDisablingLastOutput(t *testing.T) {
	cases := []struct {
		name    string
		outputs []ipc.Output
		cand    []ipc.OutputConfig
		refused bool
	}{
		{"only enabled monitor", twoOutputs()[1:], []ipc.OutputConfig{{Name: "DP-1"}}, true},
		{"both enabled monitors at once", twoOutputs(), []ipc.OutputConfig{{Name: "DP-1"}, {Name: "HDMI-A-1"}}, true},
		{"one of two", twoOutputs(), []ipc.OutputConfig{{Name: "DP-1"}}, false},
		{"swap: disable one, enable another", twoOutputs()[1:],
			[]ipc.OutputConfig{{Name: "DP-1"}, {Name: "DP-2", Enabled: true, Width: 1920, Height: 1080, Refresh: 60, Scale: 1}}, false},
		{"a mirror does not count as on", []ipc.Output{
			{Name: "DP-1", Enabled: true, Width: 2560, Height: 1440, Refresh: 60, Scale: 1},
			{Name: "HDMI-A-1", Enabled: true, Width: 2560, Height: 1440, Refresh: 60, Scale: 1, MirrorOf: "DP-1"},
		}, []ipc.OutputConfig{{Name: "DP-1"}}, true},
	}
	for _, c := range cases {
		t.Run(c.name, func(t *testing.T) {
			y := &fakeYozd{outputs: c.outputs}
			s := newService(y, "", "")
			defer s.Close()
			raw, _ := json.Marshal(map[string]any{"outputs": c.cand})
			_, err := s.apply(raw)
			if c.refused {
				if !errors.Is(err, ErrLastOutput) || len(y.appliedCopy()) != 0 {
					t.Fatalf("not refused: err %v, applied %+v", err, y.appliedCopy())
				}
				if s.mgr.Current() != nil {
					t.Fatal("a refused change started a session")
				}
				return
			}
			if err != nil || len(y.appliedCopy()) == 0 {
				t.Fatalf("refused a safe change: %v", err)
			}
		})
	}
}
