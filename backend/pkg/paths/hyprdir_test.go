package paths

import "testing"

func TestHyprDirHonoursXDG(t *testing.T) {
	t.Setenv("XDG_CONFIG_HOME", "/x/cfg")
	if got := HyprDir(); got != "/x/cfg/hypr" {
		t.Fatalf("got %q", got)
	}
	t.Setenv("XDG_CONFIG_HOME", "")
	t.Setenv("HOME", "/home/u")
	if got := HyprDir(); got != "/home/u/.config/hypr" {
		t.Fatalf("got %q", got)
	}
}
