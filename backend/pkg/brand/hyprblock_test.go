package brand

import (
	"strings"
	"testing"
)

// With the default data dir the blocks must stay byte-identical to what
// earlier releases wrote, or every existing entry would be rewritten.
func TestHyprBlocksDefaultUnchanged(t *testing.T) {
	t.Setenv("HOME", "/home/u")
	t.Setenv("XDG_DATA_HOME", "")
	wantLua := `local yozakura = loadfile(os.getenv("HOME") .. "/.local/share/yozakura/hyprland.lua") if yozakura then yozakura() end`
	if got := HyprLuaLoadLine(); got != wantLua {
		t.Fatalf("lua line:\n got %s\nwant %s", got, wantLua)
	}
	wantConf := "# Yozakura\nsource = ~/.local/share/yozakura/hyprland.conf\n\n# OVERRIDES\n" + ConfigOverridesNote("#", "source") + "\n"
	if got := HyprConfBlock(); got != wantConf {
		t.Fatalf("conf block:\n%q\nwant\n%q", got, wantConf)
	}
	wantLuaBlock := "-- Yozakura\n" + wantLua + "\n\n-- OVERRIDES\n" + ConfigOverridesNote("--", "source") + "\n"
	if got := HyprLuaBlock(); got != wantLuaBlock {
		t.Fatalf("lua block:\n%q\nwant\n%q", got, wantLuaBlock)
	}
	// An explicit XDG_DATA_HOME equal to the default spells the same.
	t.Setenv("XDG_DATA_HOME", "/home/u/.local/share")
	if HyprConfBlock() != wantConf || HyprLuaLoadLine() != wantLua {
		t.Fatal("explicit default XDG_DATA_HOME changed the blocks")
	}
}

func TestHyprBlocksFollowXDGDataHome(t *testing.T) {
	t.Setenv("HOME", "/home/u")
	t.Setenv("XDG_DATA_HOME", "/home/u/data")
	if got := HyprConfBlock(); !strings.Contains(got, "\nsource = ~/data/yozakura/hyprland.conf\n") {
		t.Fatalf("conf block under home:\n%s", got)
	}
	if got := HyprLuaLoadLine(); !strings.Contains(got, `os.getenv("HOME") .. "/data/yozakura/hyprland.lua"`) {
		t.Fatalf("lua line under home: %s", got)
	}

	t.Setenv("XDG_DATA_HOME", "/srv/data")
	if got := HyprConfBlock(); !strings.Contains(got, "\nsource = /srv/data/yozakura/hyprland.conf\n") {
		t.Fatalf("conf block outside home:\n%s", got)
	}
	want := `local yozakura = loadfile("/srv/data/yozakura/hyprland.lua") if yozakura then yozakura() end`
	if got := HyprLuaLoadLine(); got != want {
		t.Fatalf("lua line outside home:\n got %s\nwant %s", got, want)
	}
	if !strings.Contains(HyprLuaBlock(), want) {
		t.Fatalf("lua block outside home:\n%s", HyprLuaBlock())
	}
}

func TestDataRelTo(t *testing.T) {
	for _, c := range []struct {
		home, dir, want string
		ok              bool
	}{
		{"/home/u", "/home/u/.local/share/yozakura", "/.local/share/yozakura/", true},
		{"/home/u/", "/home/u/x/yozakura", "/x/yozakura/", true},
		{"/home/u", "/home/u2/yozakura", "", false},
		{"/home/u", "/home/u", "", false},
		{"", "/x/yozakura", "", false},
		{"/home/u", "rel/yozakura", "", false},
	} {
		got, ok := DataRelTo(c.home, c.dir)
		if got != c.want || ok != c.ok {
			t.Errorf("DataRelTo(%q, %q) = %q, %v; want %q, %v", c.home, c.dir, got, ok, c.want, c.ok)
		}
	}
}
