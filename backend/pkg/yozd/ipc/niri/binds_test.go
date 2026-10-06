package niri

import (
	"os"
	"path/filepath"
	"testing"
)

const kdl = `input { keyboard { xkb { layout "us,ru"; } } }
binds {
    // comment
    Mod+T hotkey-overlay-title="Open a Terminal" { spawn "alacritty"; }
    Mod+Shift+Slash { show-hotkey-overlay; }
    XF86AudioRaiseVolume allow-when-locked=true { spawn "wpctl" "set-volume" "@DEFAULT_AUDIO_SINK@" "0.1+"; }
    /-Mod+X { close-window; }
    Mod+Q {
        close-window;
    }
    Mod+WheelScrollDown { focus-workspace-down; }
}
`

func TestParseBinds(t *testing.T) {
	binds := ParseBinds(kdl, "config.kdl")
	if len(binds) != 5 {
		t.Fatalf("got %d binds: %+v", len(binds), binds)
	}
	if b := binds[0]; b.Key != "T" || b.Modifiers[0] != "SUPER" || b.Dispatcher != "spawn" || b.Arg != `"alacritty"` || b.Description != "Open a Terminal" {
		t.Fatalf("bind 0: %+v", b)
	}
	if b := binds[1]; b.Key != "Slash" || len(b.Modifiers) != 2 || b.Modifiers[1] != "SHIFT" || b.Dispatcher != "show-hotkey-overlay" {
		t.Fatalf("bind 1: %+v", b)
	}
	if b := binds[2]; !b.Locked || len(b.Modifiers) != 0 {
		t.Fatalf("bind 2: %+v", b)
	}
	if b := binds[3]; b.Key != "Q" || b.Dispatcher != "close-window" {
		t.Fatalf("multi-line bind: %+v", b)
	}
	if b := binds[4]; !b.Mouse {
		t.Fatalf("wheel bind: %+v", b)
	}
}

func TestReadBindsFollowsIncludes(t *testing.T) {
	dir := t.TempDir()
	main := filepath.Join(dir, "config.kdl")
	if err := os.WriteFile(main, []byte("include \"extra.kdl\"\nbinds {\n    Mod+A { spawn \"a\"; }\n}\n"), 0o644); err != nil {
		t.Fatal(err)
	}
	if err := os.WriteFile(filepath.Join(dir, "extra.kdl"), []byte("binds {\n    Mod+B { spawn \"b\"; }\n}\n"), 0o644); err != nil {
		t.Fatal(err)
	}
	binds := ReadBinds(main)
	if len(binds) != 2 || binds[1].Key != "B" {
		t.Fatalf("got %+v", binds)
	}
	if got := ReadBinds(filepath.Join(dir, "missing.kdl")); got == nil || len(got) != 0 {
		t.Fatalf("missing file: %+v", got)
	}
}
