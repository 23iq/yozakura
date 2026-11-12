package brand

import (
	"strings"
	"testing"
)

// A relative XDG_DATA_HOME (a literal "~/.local/share" is one) is invalid
// per the XDG spec and ignored: the blocks keep the default spelling.
func TestXDGBaseIgnoresRelativeValues(t *testing.T) {
	t.Setenv("HOME", "/home/u")
	t.Setenv("XDG_DATA_HOME", "")
	want := HyprLuaBlock()
	for _, v := range []string{"~/.local/share", "rel/data", "./data"} {
		t.Setenv("XDG_DATA_HOME", v)
		if got := DataDirIn("/home/u"); got != "/home/u/.local/share/yozakura" {
			t.Errorf("XDG_DATA_HOME=%q: data dir %q", v, got)
		}
		if HyprLuaBlock() != want {
			t.Errorf("XDG_DATA_HOME=%q changed the Lua block", v)
		}
	}
}

// The data dir is spelled as a valid Lua string literal: only '\' and '"'
// are escaped, never as \uXXXX the way Go's %q does.
func TestHyprLuaLoadLineQuotesPath(t *testing.T) {
	got := HyprLuaLoadLineFor("/home/u", `/home/u/a"b\c/yozakura`)
	want := `local yozakura = loadfile(os.getenv("HOME") .. "/a\"b\\c/yozakura/hyprland.lua") if yozakura then yozakura() end`
	if got != want {
		t.Fatalf("under home:\n got %s\nwant %s", got, want)
	}
	nbsp := "/srv/a b/yozakura"
	got = HyprLuaLoadLineFor("/home/u", nbsp)
	if want := `loadfile("` + nbsp + `/hyprland.lua")`; !strings.Contains(got, want) || strings.Contains(got, `\u`) {
		t.Fatalf("outside home: %s", got)
	}
}

func TestHyprDataDirErrors(t *testing.T) {
	for _, c := range []struct {
		dir       string
		lua, conf bool // whether each form refuses it
	}{
		{"/home/u/.local/share/yozakura", false, false},
		{`/home/u/a"b\c/yozakura`, false, false},
		{"/home/u/a#b/yozakura", false, true},
		{"/home/u/a\nb/yozakura", true, true},
		{"/home/u/a\tb/yozakura", true, true},
		{"/home/u/a\x7fb/yozakura", true, true},
		{"rel/yozakura", true, true},
	} {
		if got := HyprLuaDataDirError(c.dir) != nil; got != c.lua {
			t.Errorf("HyprLuaDataDirError(%q) refused = %v, want %v", c.dir, got, c.lua)
		}
		if got := HyprConfDataDirError(c.dir) != nil; got != c.conf {
			t.Errorf("HyprConfDataDirError(%q) refused = %v, want %v", c.dir, got, c.conf)
		}
	}
}
