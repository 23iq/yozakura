package config

import (
	"os"
	"path/filepath"
	"strings"
	"testing"

	"yozakura/backend/pkg/yozd/ipc"
	"yozakura/backend/pkg/yozd/ipc/hyprland"
	"yozakura/backend/pkg/yozd/ipc/mango"
	"yozakura/backend/pkg/yozd/ipc/niri"
)

const startupTOML = `
[target]
hyprland = "hyprland.lua"
niri = "niri.kdl"
mango = "mango.conf"

[startup]
exec-once = "yozakura"
exec-once-non-hyprland = "/usr/lib/hyprpolkitagent/hyprpolkitagent"
`

const unitFallbackTOML = `
[startup]
exec-once = "yozakura"
exec-once-non-hyprland = "systemctl --user start hyprpolkitagent"
`

// The user-unit fallback has arguments: niri gets argv, Mango a command line.
func TestStartupUnitFallbackArgv(t *testing.T) {
	dir := t.TempDir()
	toml := filepath.Join(dir, "yozd.toml")
	os.WriteFile(toml, []byte(unitFallbackTOML), 0o644)
	cfg, err := LoadConfig(toml)
	if err != nil {
		t.Fatal(err)
	}
	ipcCfg := cfg.ToIPCConfig()
	write := func(name string, gen ipc.ConfigGenerator) string {
		p := filepath.Join(dir, name)
		if err := writeConfig(gen, p, ipcCfg, true); err != nil {
			t.Fatal(err)
		}
		b, _ := os.ReadFile(p)
		return string(b)
	}
	if kdl := write("niri.kdl", niri.NewGenerator()); !strings.Contains(kdl, `spawn-at-startup "systemctl" "--user" "start" "hyprpolkitagent"`) {
		t.Errorf("niri:\n%s", kdl)
	}
	if m := write("mango.conf", mango.NewGenerator()); !strings.Contains(m, "exec-once = systemctl --user start hyprpolkitagent\n") {
		t.Errorf("mango:\n%s", m)
	}
}

// The polkit agent is for niri and Mango only: Hyprland's installer line
// starts it there.
func TestStartupNonHyprlandOnlyForNiriAndMango(t *testing.T) {
	dir := t.TempDir()
	toml := filepath.Join(dir, "yozd.toml")
	if err := os.WriteFile(toml, []byte(startupTOML), 0o644); err != nil {
		t.Fatal(err)
	}
	cfg, err := LoadConfig(toml)
	if err != nil {
		t.Fatal(err)
	}
	// The headless writer ApplyConfig uses for the inactive compositors.
	ipcCfg := cfg.ToIPCConfig()
	for name, gen := range map[string]ipc.ConfigGenerator{
		"niri.kdl": niri.NewGenerator(), "mango.conf": mango.NewGenerator(), "hyprland.conf": hyprland.NewGenerator(),
	} {
		nonHypr := name != "hyprland.conf"
		if err := writeConfig(gen, filepath.Join(dir, name), ipcCfg, nonHypr); err != nil {
			t.Fatal(err)
		}
	}
	read := func(name string) string {
		b, err := os.ReadFile(filepath.Join(dir, name))
		if err != nil {
			t.Fatal(err)
		}
		return string(b)
	}
	kdl := read("niri.kdl")
	for _, want := range []string{`spawn-at-startup "yozakura"`, `spawn-at-startup "/usr/lib/hyprpolkitagent/hyprpolkitagent"`} {
		if !strings.Contains(kdl, want) {
			t.Errorf("niri.kdl lacks %s:\n%s", want, kdl)
		}
	}
	mango := read("mango.conf")
	for _, want := range []string{"exec-once = yozakura\n", "exec-once = /usr/lib/hyprpolkitagent/hyprpolkitagent\n"} {
		if !strings.Contains(mango, want) {
			t.Errorf("mango.conf lacks %q:\n%s", want, mango)
		}
	}
	for _, name := range []string{"hyprland.conf"} {
		if b, err := os.ReadFile(filepath.Join(dir, name)); err == nil && strings.Contains(string(b), "polkit") {
			t.Errorf("%s carries the polkit agent:\n%s", name, b)
		}
	}
}
