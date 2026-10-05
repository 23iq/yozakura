package main

import (
	"os"
	"path/filepath"
	"strings"
	"testing"
)

func TestRepairHyprlandEntryGuardsLoadfile(t *testing.T) {
	home := t.TempDir()
	t.Setenv("HOME", home)
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
