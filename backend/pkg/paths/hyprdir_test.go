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

// A relative XDG value is used as it is, as this package always did (only
// the Hyprland entry ignores it, see brand.XDGBase): no app dir moves.
func TestXDGRelativeValueKept(t *testing.T) {
	t.Setenv("HOME", "/home/u")
	t.Setenv("XDG_DATA_HOME", "rel/data")
	t.Setenv("XDG_CONFIG_HOME", "~/.config")
	p := New()
	if p.DataDir != "rel/data/yozakura" || p.ConfigDir != "~/.config/yozakura" || HyprDir() != "~/.config/hypr" {
		t.Fatalf("data %q, config %q, hypr %q", p.DataDir, p.ConfigDir, HyprDir())
	}
}
