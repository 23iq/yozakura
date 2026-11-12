package daemon

import (
	"errors"
	"reflect"
	"testing"

	"yozakura/backend/pkg/svc/compositor"
)

// The fallback starts only when the shell's own agent held the session:
// any other report means another agent answers (or the login line's
// fallback already started one), and a second agent would fail to
// register.
func TestPolkitTakeoverOnlyAfterTheShellsAgent(t *testing.T) {
	var spawned [][]string
	spawn := func(argv []string) error {
		spawned = append(spawned, argv)
		return nil
	}
	for _, state := range []string{"", compositor.PolkitOff, compositor.PolkitUnavailable, compositor.PolkitPending} {
		if polkitTakeover(compositor.PolkitReport{State: state, PID: 7}, "/opt/bin/yozakura", spawn) {
			t.Errorf("state %q: fallback started", state)
		}
	}
	if len(spawned) != 0 {
		t.Fatalf("spawned %v", spawned)
	}
	if polkitTakeover(compositor.PolkitReport{State: compositor.PolkitRegistered, PID: 7}, "", spawn) {
		t.Error("started without a launcher")
	}
	if !polkitTakeover(compositor.PolkitReport{State: compositor.PolkitRegistered, PID: 7}, "/opt/my apps/yozakura", spawn) {
		t.Fatal("registered: no fallback")
	}
	// argv, never an sh line: a path with spaces is one argument
	want := [][]string{{"/opt/my apps/yozakura", compositor.FallbackVerb}}
	if !reflect.DeepEqual(spawned, want) {
		t.Fatalf("spawned %q, want %q", spawned, want)
	}
	if polkitTakeover(compositor.PolkitReport{State: compositor.PolkitRegistered}, "/x", func([]string) error { return errors.New("enoent") }) {
		t.Error("a failed spawn reported as started")
	}
}

// Without a compositor service (no report) nothing is started.
func TestShellLostPolkitWithoutCompositor(t *testing.T) {
	(&Daemon{}).shellLostPolkit()
}
