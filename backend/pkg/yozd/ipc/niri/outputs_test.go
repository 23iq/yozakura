package niri

import (
	"encoding/json"
	"errors"
	"os"
	"testing"

	"yozakura/backend/pkg/yozd/ipc"
)

func TestParseNiriOutputs(t *testing.T) {
	b, err := os.ReadFile("testdata/outputs.json")
	if err != nil {
		t.Fatal(err)
	}
	outs, err := parseNiriOutputs(b)
	if err != nil || len(outs) != 2 {
		t.Fatal(outs, err)
	}
	dp, hdmi := outs[0], outs[1] // sorted by name
	if dp.ID != "Lenovo Group Limited|Legion 27Q-10|UNA08414" || !dp.Enabled || dp.Refresh != 239.97 ||
		dp.Width != 2560 || dp.Scale != 1.5 || dp.Transform != 1 || !dp.VRR || dp.PhysicalWidthMM != 600 {
		t.Fatalf("%+v", dp)
	}
	if len(dp.Modes) != 3 || dp.Modes[2] != (ipc.Mode{Width: 1920, Height: 1080, Refresh: 60}) {
		t.Fatalf("modes %+v", dp.Modes)
	}
	if hdmi.ID != "HDMI-A-1" || hdmi.Enabled || hdmi.Width != 0 || len(hdmi.Modes) != 1 {
		t.Fatalf("%+v", hdmi)
	}
}

func TestNiriTransformIndex(t *testing.T) {
	for s, want := range map[string]int{"Normal": 0, "90": 1, "_90": 1, "180": 2, "270": 3, "Flipped": 4, "Flipped270": 7, "junk": 0} {
		if got := niriTransformIndex(s); got != want {
			t.Errorf("%s: %d want %d", s, got, want)
		}
	}
}

func marshalActions(t *testing.T, cfg ipc.OutputConfig) []string {
	t.Helper()
	var out []string
	acts, err := niriOutputActions(cfg)
	if err != nil {
		t.Fatal(err)
	}
	for _, a := range acts {
		b, err := json.Marshal(a)
		if err != nil {
			t.Fatal(err)
		}
		out = append(out, string(b))
	}
	return out
}

func eqStrings(t *testing.T, got, want []string) {
	t.Helper()
	if len(got) != len(want) {
		t.Fatalf("got %v", got)
	}
	for i := range want {
		if got[i] != want[i] {
			t.Errorf("[%d]\n got %s\nwant %s", i, got[i], want[i])
		}
	}
}

func TestNiriOutputActionsFull(t *testing.T) {
	got := marshalActions(t, ipc.OutputConfig{Name: "DP-1", Enabled: true, Width: 2560, Height: 1440, Refresh: 239.97,
		X: 1920, Y: 0, Scale: 1.5, Transform: 1, VRR: 2})
	eqStrings(t, got, []string{
		`{"Output":{"action":"On","output":"DP-1"}}`,
		`{"Output":{"action":{"Mode":{"mode":{"Specific":{"height":1440,"refresh":239.97,"width":2560}}}},"output":"DP-1"}}`,
		`{"Output":{"action":{"Scale":{"scale":{"Specific":1.5}}},"output":"DP-1"}}`,
		`{"Output":{"action":{"Transform":{"transform":"90"}},"output":"DP-1"}}`,
		`{"Output":{"action":{"Position":{"position":{"Specific":{"x":1920,"y":0}}}},"output":"DP-1"}}`,
		`{"Output":{"action":{"Vrr":{"vrr":{"on_demand":true,"vrr":true}}},"output":"DP-1"}}`,
	})
}

func TestNiriOutputActionsAutoAndOff(t *testing.T) {
	got := marshalActions(t, ipc.OutputConfig{Name: "DP-1", Enabled: true, AutoPosition: true})
	eqStrings(t, got, []string{
		`{"Output":{"action":"On","output":"DP-1"}}`,
		`{"Output":{"action":{"Mode":{"mode":"Automatic"}},"output":"DP-1"}}`,
		`{"Output":{"action":{"Scale":{"scale":"Automatic"}},"output":"DP-1"}}`,
		`{"Output":{"action":{"Transform":{"transform":"Normal"}},"output":"DP-1"}}`,
		`{"Output":{"action":{"Position":{"position":"Automatic"}},"output":"DP-1"}}`,
		`{"Output":{"action":{"Vrr":{"vrr":{"on_demand":false,"vrr":false}}},"output":"DP-1"}}`,
	})
	// A disabled output ignores mode/position/scale.
	eqStrings(t, marshalActions(t, ipc.OutputConfig{Name: "DP-1", Width: 1920, Height: 1080, Scale: 2}),
		[]string{`{"Output":{"action":"Off","output":"DP-1"}}`})
}

func TestNiriApplyOutputSendsActions(t *testing.T) {
	f := newFakeNiri(t, func(req json.RawMessage) (any, error) { return nil, nil })
	c := f.Client()
	if err := c.ApplyOutput(ipc.OutputConfig{Name: "DP-1", Enabled: true}); err != nil {
		t.Fatal(err)
	}
	if n := len(f.requestsSnapshot()); n != 6 {
		t.Fatalf("%d requests", n)
	}
}

func TestNiriApplyOutputRejectsInvalid(t *testing.T) {
	f := newFakeNiri(t, func(req json.RawMessage) (any, error) {
		t.Fatalf("unexpected request: %s", req)
		return nil, errors.New("unreachable")
	})
	c := f.Client()
	if err := c.ApplyOutput(ipc.OutputConfig{Name: "DP-1\"; rm", Enabled: true}); err == nil {
		t.Fatal("accepted bad name")
	}
}

func TestNiriTransformWireNames(t *testing.T) {
	for i, want := range []string{"Normal", "90", "180", "270", "Flipped", "Flipped90", "Flipped180", "Flipped270"} {
		got := marshalActions(t, ipc.OutputConfig{Name: "DP-1", Enabled: true, Transform: i})
		w := `{"Output":{"action":{"Transform":{"transform":"` + want + `"}},"output":"DP-1"}}`
		if got[3] != w {
			t.Errorf("transform %d: %s want %s", i, got[3], w)
		}
	}
}

func TestNiriTransformRange(t *testing.T) {
	if _, err := niriOutputActions(ipc.OutputConfig{Name: "DP-1", Enabled: true, Transform: 8}); err == nil {
		t.Fatal("accepted transform 8")
	}
}
