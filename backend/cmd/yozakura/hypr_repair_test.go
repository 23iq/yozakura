package main

import (
	"fmt"
	"os"
	"path/filepath"
	"strings"
	"testing"

	"yozakura/backend/pkg/brand"
)

func TestRepairHyprlandEntryGuardsLoadfile(t *testing.T) {
	home := t.TempDir()
	t.Setenv("HOME", home)
	t.Setenv("XDG_DATA_HOME", "")
	t.Setenv("XDG_CONFIG_HOME", "")
	hypr := filepath.Join(home, ".config/hypr")
	os.MkdirAll(hypr, 0o755)
	entry := filepath.Join(hypr, "hyprland.lua")
	old := blockMarker("--") + "\n" + legacyLuaLoadLine() + "\n\n-- OVERRIDES\nhl.bind(\"SUPER + RETURN\", hl.dsp.exec_cmd(\"kitty\"))\n"
	os.WriteFile(entry, []byte(old), 0o644)

	repairHyprlandEntry(home, "/opt/bin/yozakura")

	got, _ := os.ReadFile(entry)
	if strings.Contains(string(got), legacyLuaLoadLine()) {
		t.Fatalf("unguarded loadfile line kept:\n%s", got)
	}
	if !strings.Contains(string(got), luaLoadLine()) || !strings.Contains(string(got), "kitty") {
		t.Fatalf("guarded line or user overrides missing:\n%s", got)
	}
	stub, err := os.ReadFile(filepath.Join(home, ".local/share/yozakura/hyprland.lua"))
	if err != nil || !strings.Contains(string(stub), `hl.exec_cmd("/opt/bin/yozakura")`) {
		t.Fatalf("lua bootstrap stub missing: %v %s", err, stub)
	}
	conf, err := os.ReadFile(filepath.Join(home, ".local/share/yozakura/hyprland.conf"))
	if err != nil || !strings.Contains(string(conf), "exec-once = /opt/bin/yozakura") {
		t.Fatalf("conf bootstrap stub missing: %v %s", err, conf)
	}

	if b, err := os.ReadFile(filepath.Join(home, ".local/share/yozakura/hyprland.yozd.conf")); err != nil || !strings.Contains(string(b), "exec-once = /opt/bin/yozakura") {
		t.Fatalf("daemon conf stub missing: %v %s", err, b)
	}

	// Idempotent, and never overwrites generated files.
	os.WriteFile(filepath.Join(home, ".local/share/yozakura/hyprland.lua"), []byte("generated"), 0o644)
	repairHyprlandEntry(home, "/opt/bin/yozakura")
	again, _ := os.ReadFile(entry)
	if string(again) != string(got) {
		t.Fatalf("second repair changed the entry:\n%s", again)
	}
	if b, _ := os.ReadFile(filepath.Join(home, ".local/share/yozakura/hyprland.lua")); string(b) != "generated" {
		t.Fatalf("generated file overwritten: %s", b)
	}
}

func TestRepairHyprlandEntryNoHyprConfig(t *testing.T) {
	home := t.TempDir()
	t.Setenv("XDG_DATA_HOME", "")
	t.Setenv("XDG_CONFIG_HOME", "")
	repairHyprlandEntry(home, "/opt/bin/yozakura")
	if _, err := os.Stat(filepath.Join(home, ".local/share/yozakura/hyprland.lua")); err == nil {
		t.Fatal("stubs must only be written when a Hyprland config loads them")
	}
}

func TestLuaBlockIsGuarded(t *testing.T) {
	if !strings.Contains(hyprLuaBlock(), "if yozakura then yozakura() end") {
		t.Fatalf("new lua block must guard a missing file:\n%s", hyprLuaBlock())
	}
}

// With the default data dir a current entry is left byte-identical.
func TestRepairHyprlandEntryDefaultKeepsEntry(t *testing.T) {
	home := t.TempDir()
	t.Setenv("HOME", home)
	t.Setenv("XDG_DATA_HOME", "")
	t.Setenv("XDG_CONFIG_HOME", "")
	hypr := filepath.Join(home, ".config/hypr")
	os.MkdirAll(hypr, 0o755)
	lua := filepath.Join(hypr, "hyprland.lua")
	conf := filepath.Join(hypr, "hyprland.conf")
	luaText := "a = 1\n" + hyprLuaBlock()
	confText := "x = 1\n" + hyprConfBlock()
	os.WriteFile(lua, []byte(luaText), 0o644)
	os.WriteFile(conf, []byte(confText), 0o644)
	if !strings.Contains(confText, "source = ~/.local/share/yozakura/hyprland.conf") {
		t.Fatalf("default conf block changed:\n%s", confText)
	}

	repairHyprlandEntry(home, "/opt/bin/yozakura")

	if b, _ := os.ReadFile(lua); string(b) != luaText {
		t.Fatalf("lua entry rewritten:\n%s", b)
	}
	if b, _ := os.ReadFile(conf); string(b) != confText {
		t.Fatalf("conf entry rewritten:\n%s", b)
	}
	if _, err := os.Stat(filepath.Join(home, ".local/share/yozakura/hyprland.conf")); err != nil {
		t.Fatalf("stub missing in the default data dir: %v", err)
	}
}

// With XDG_DATA_HOME / XDG_CONFIG_HOME set, an entry written with the old
// ~/.local/share/<app> lines is pointed at the real data dir, which gets
// the bootstrap stubs; nothing is written to ~/.local/share.
func TestRepairHyprlandEntryFollowsXDG(t *testing.T) {
	home := t.TempDir()
	cfg := filepath.Join(t.TempDir(), "cfg")
	data := filepath.Join(t.TempDir(), "data")
	t.Setenv("HOME", home)
	t.Setenv("XDG_CONFIG_HOME", cfg)
	t.Setenv("XDG_DATA_HOME", data)
	hypr := filepath.Join(cfg, "hypr")
	os.MkdirAll(hypr, 0o755)
	oldLua := "-- Yozakura\n" + brand.HyprLuaLoadLineFor(home, filepath.Join(home, ".local/share/yozakura")) + "\nhl.bind(\"SUPER + RETURN\", hl.dsp.exec_cmd(\"kitty\"))\n"
	oldConf := "# Yozakura\nsource = ~/.local/share/yozakura/hyprland.conf\nbind = SUPER, Q, killactive\n"
	os.WriteFile(filepath.Join(hypr, "hyprland.lua"), []byte(oldLua), 0o644)
	os.WriteFile(filepath.Join(hypr, "hyprland.conf"), []byte(oldConf), 0o644)

	repairHyprlandEntry(home, "/opt/bin/yozakura")

	dataDir := filepath.Join(data, "yozakura")
	gotLua, _ := os.ReadFile(filepath.Join(hypr, "hyprland.lua"))
	wantLine := fmt.Sprintf("local yozakura = loadfile(%q) if yozakura then yozakura() end", filepath.Join(dataDir, "hyprland.lua"))
	if !strings.Contains(string(gotLua), wantLine) || strings.Contains(string(gotLua), ".local/share") || !strings.Contains(string(gotLua), "kitty") {
		t.Fatalf("lua entry not repointed:\n%s", gotLua)
	}
	gotConf, _ := os.ReadFile(filepath.Join(hypr, "hyprland.conf"))
	if want := "# Yozakura\nsource = " + filepath.Join(dataDir, "hyprland.conf") + "\nbind = SUPER, Q, killactive\n"; string(gotConf) != want {
		t.Fatalf("conf entry:\n%s\nwant\n%s", gotConf, want)
	}
	for _, name := range []string{"hyprland.lua", "hyprland.conf", "hyprland.yozd.conf"} {
		if _, err := os.Stat(filepath.Join(dataDir, name)); err != nil {
			t.Errorf("stub %s missing in XDG_DATA_HOME: %v", name, err)
		}
	}
	if _, err := os.Stat(filepath.Join(home, ".local/share/yozakura")); err == nil {
		t.Fatal("wrote into ~/.local/share despite XDG_DATA_HOME")
	}
	if _, err := os.Stat(filepath.Join(home, ".config/hypr")); err == nil {
		t.Fatal("looked at ~/.config/hypr despite XDG_CONFIG_HOME")
	}

	// The legacy unguarded line maps straight to the new one too, and a
	// second run changes nothing.
	os.WriteFile(filepath.Join(hypr, "hyprland.lua"), []byte(legacyLuaLoadLine()+"\n"), 0o644)
	repairHyprlandEntry(home, "/opt/bin/yozakura")
	once, _ := os.ReadFile(filepath.Join(hypr, "hyprland.lua"))
	if string(once) != wantLine+"\n" {
		t.Fatalf("legacy line: %s", once)
	}
	repairHyprlandEntry(home, "/opt/bin/yozakura")
	if twice, _ := os.ReadFile(filepath.Join(hypr, "hyprland.lua")); string(twice) != string(once) {
		t.Fatalf("second run changed the entry: %s", twice)
	}
}
