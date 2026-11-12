package main

import (
	"os"
	"path/filepath"
	"strings"
	"testing"

	"yozakura/backend/pkg/brand"
)

// writeDefaultEntries writes Hyprland entries carrying the historical
// ~/.local/share/<app> lines under home and returns their paths and text.
func writeDefaultEntries(t *testing.T, home string) (lua, conf, luaText, confText string) {
	t.Helper()
	hypr := filepath.Join(home, ".config/hypr")
	if err := os.MkdirAll(hypr, 0o755); err != nil {
		t.Fatal(err)
	}
	lua, conf = filepath.Join(hypr, "hyprland.lua"), filepath.Join(hypr, "hyprland.conf")
	luaText = "-- Yozakura\n" + brand.HyprLuaLoadLineFor(home, filepath.Join(home, ".local/share/yozakura")) + "\n"
	confText = "# Yozakura\nsource = ~/.local/share/yozakura/hyprland.conf\n"
	if err := os.WriteFile(lua, []byte(luaText), 0o644); err != nil {
		t.Fatal(err)
	}
	if err := os.WriteFile(conf, []byte(confText), 0o644); err != nil {
		t.Fatal(err)
	}
	return lua, conf, luaText, confText
}

// A relative XDG_DATA_HOME (here a literal "~/.local/share") is ignored:
// a working entry is not rewritten into a path that never loads.
func TestRepairHyprlandEntryIgnoresRelativeXDGDataHome(t *testing.T) {
	home := t.TempDir()
	t.Setenv("HOME", home)
	t.Setenv("XDG_CONFIG_HOME", "")
	t.Setenv("XDG_DATA_HOME", "~/.local/share")
	lua, conf, luaText, confText := writeDefaultEntries(t, home)

	repairHyprlandEntry(home, "/opt/bin/yozakura")

	if b, _ := os.ReadFile(lua); string(b) != luaText {
		t.Fatalf("lua entry rewritten:\n%s", b)
	}
	if b, _ := os.ReadFile(conf); string(b) != confText {
		t.Fatalf("conf entry rewritten:\n%s", b)
	}
}

// A data dir with '"' and '\' is written as a valid Lua string; one with
// '#' cannot be spelled in hyprland.conf, whose entry is left untouched.
func TestRepairHyprlandEntryEscapesOrRefusesDataDir(t *testing.T) {
	home := t.TempDir()
	t.Setenv("HOME", home)
	t.Setenv("XDG_CONFIG_HOME", "")
	t.Setenv("XDG_DATA_HOME", filepath.Join(home, `da"t\a#1`))
	lua, conf, _, confText := writeDefaultEntries(t, home)

	repairHyprlandEntry(home, "/opt/bin/yozakura")

	gotLua, _ := os.ReadFile(lua)
	if want := `loadfile(os.getenv("HOME") .. "/da\"t\\a#1/yozakura/hyprland.lua")`; !strings.Contains(string(gotLua), want) {
		t.Fatalf("lua entry:\n%s\nwant it to contain %s", gotLua, want)
	}
	if b, _ := os.ReadFile(conf); string(b) != confText {
		t.Fatalf("conf entry rewritten despite '#':\n%s", b)
	}
	// the escaped Lua line is recognised as loading the data dir
	if _, err := os.Stat(filepath.Join(home, `da"t\a#1`, "yozakura", "hyprland.lua")); err != nil {
		t.Fatalf("bootstrap stub missing: %v", err)
	}
}

// A control character cannot be spelled in either entry: both stay as is.
func TestRepairHyprlandEntryRefusesControlCharacters(t *testing.T) {
	home := t.TempDir()
	t.Setenv("HOME", home)
	t.Setenv("XDG_CONFIG_HOME", "")
	t.Setenv("XDG_DATA_HOME", filepath.Join(home, "da\nta"))
	lua, conf, luaText, confText := writeDefaultEntries(t, home)

	repairHyprlandEntry(home, "/opt/bin/yozakura")

	if b, _ := os.ReadFile(lua); string(b) != luaText {
		t.Fatalf("lua entry rewritten:\n%q", b)
	}
	if b, _ := os.ReadFile(conf); string(b) != confText {
		t.Fatalf("conf entry rewritten:\n%q", b)
	}
}
