package voice

import (
	"reflect"
	"testing"
)

func TestHealthWarnings(t *testing.T) {
	tools := func(names ...string) func(string) bool {
		return func(n string) bool {
			for _, x := range names {
				if x == n {
					return true
				}
			}
			return false
		}
	}
	cfg := DefaultConfig()
	if got := healthWarnings(cfg, "cuda", true, tools("pw-record", "wtype")); len(got) != 0 {
		t.Fatalf("healthy setup warned: %v", got)
	}
	got := healthWarnings(cfg, "cpu", false, tools())
	want := []string{WarnRecorderMissing, WarnTyperMissing, WarnVADMissing, WarnGPUIgnored}
	if !reflect.DeepEqual(got, want) {
		t.Fatalf("got %v want %v", got, want)
	}
	cfg.Enabled = false
	cfg.TypingMethod = "ydotool"
	got = healthWarnings(cfg, "cuda", true, tools("parecord", "wtype"))
	want = []string{WarnDisabled, WarnTyperMissing}
	if !reflect.DeepEqual(got, want) {
		t.Fatalf("got %v want %v", got, want)
	}
}
