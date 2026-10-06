package main

import (
	"os"
	"path/filepath"
	"strings"
	"testing"

	"yozakura/backend/pkg/brand"
	"yozakura/backend/pkg/migrate"
)

func TestUpgradeLegacyBlockInPlace(t *testing.T) {
	dir := t.TempDir()
	lua := filepath.Join(dir, "hyprland.lua")
	orig := "hl.config({})\n" +
		"-- Ambxst\n" +
		"loadfile(os.getenv(\"HOME\") .. \"/.local/share/ambxst/hyprland.lua\")()\n\n" +
		"-- OVERRIDES\n" +
		"-- Down here you can write or source anything that you want to override from Ambxst's settings.\n" +
		"-- the old path /.local/share/ambxst/ in a comment stays\n" +
		"loadfile(os.getenv(\"HOME\") .. \"/.config/hypr/custom/sakura.lua\")()\n"
	os.WriteFile(lua, []byte(orig), 0o644)

	changed, err := migrate.UpgradeLegacyBlock(lua)
	if err != nil || !changed {
		t.Fatalf("changed=%v err=%v", changed, err)
	}
	got, _ := os.ReadFile(lua)
	want := "hl.config({})\n" +
		"-- Yozakura\n" +
		"loadfile(os.getenv(\"HOME\") .. \"/.local/share/yozakura/hyprland.lua\")()\n\n" +
		"-- OVERRIDES\n" +
		"-- Down here you can write or source anything that you want to override from Yozakura's settings.\n" +
		"-- the old path /.local/share/ambxst/ in a comment stays\n" +
		"loadfile(os.getenv(\"HOME\") .. \"/.config/hypr/custom/sakura.lua\")()\n"
	if string(got) != want {
		t.Fatalf("upgrade:\n%s\nwant:\n%s", got, want)
	}
	backup, err := os.ReadFile(lua + ".pre-yozakura")
	if err != nil || string(backup) != orig {
		t.Fatalf("backup missing or wrong: %v", err)
	}
	// Idempotent: nothing left to upgrade, install sees the new marker.
	if changed, _ := migrate.UpgradeLegacyBlock(lua); changed {
		t.Fatal("second run must be a no-op")
	}
	if !containsLine(string(got), blockMarker("--")) {
		t.Fatal("new marker not detected")
	}
}

func TestRemoveBlockDropsIncludeLine(t *testing.T) {
	dir := t.TempDir()
	lua := filepath.Join(dir, "hyprland.lua")
	os.WriteFile(lua, []byte("a = 1\n\n"+hyprLuaBlock()+"\nb = 2\n"), 0o644)
	removeBlock(lua, blockMarker("--"), strings.Split(hyprLuaBlock(), "\n")[1])
	got, _ := os.ReadFile(lua)
	if strings.Contains(string(got), "loadfile") || strings.Contains(string(got), "Yozakura") {
		t.Fatalf("block not removed:\n%s", got)
	}
	if !strings.Contains(string(got), "a = 1") || !strings.Contains(string(got), "b = 2") {
		t.Fatalf("user lines lost:\n%s", got)
	}
}

func TestRemoveBlockKeepsLongLinesAndBacksUp(t *testing.T) {
	dir := t.TempDir()
	real := filepath.Join(dir, "dotfiles", "hyprland.lua")
	os.MkdirAll(filepath.Dir(real), 0o755)
	long := "x = \"" + strings.Repeat("y", 200*1024) + "\""
	orig := "a = 1\n" + long + "\n\n" + hyprLuaBlock() + "\nb = 2\n"
	os.WriteFile(real, []byte(orig), 0o600)
	lua := filepath.Join(dir, "hyprland.lua")
	os.Symlink(real, lua)

	if err := removeBlock(lua, blockMarker("--"), strings.Split(hyprLuaBlock(), "\n")[1]); err != nil {
		t.Fatal(err)
	}
	got, _ := os.ReadFile(real)
	if !strings.Contains(string(got), long) || !strings.Contains(string(got), "b = 2") {
		t.Fatalf("a line over 64KB truncated the file (%d bytes left)", len(got))
	}
	if strings.Contains(string(got), "loadfile") {
		t.Fatal("block not removed")
	}
	if st, _ := os.Lstat(lua); st.Mode()&os.ModeSymlink == 0 {
		t.Fatal("a symlinked compositor config must stay a symlink")
	}
	if st, _ := os.Stat(real); st.Mode().Perm() != 0o600 {
		t.Fatalf("mode changed: %v", st.Mode())
	}
	bak, err := os.ReadFile(lua + ".bak")
	if err != nil || string(bak) != orig {
		t.Fatalf("no .bak with the original content: %v", err)
	}
}

func TestBootstrapBodyStartsShellAndPolkit(t *testing.T) {
	niri := bootstrapBody(niriConfig, "/opt/bin/yozakura", "/usr/lib/hyprpolkitagent/hyprpolkitagent")
	for _, want := range []string{`spawn-at-startup "/opt/bin/yozakura"`, `spawn-at-startup "/usr/lib/hyprpolkitagent/hyprpolkitagent"`} {
		if !strings.Contains(niri, want) {
			t.Errorf("niri bootstrap lacks %s:\n%s", want, niri)
		}
	}
	mango := bootstrapBody(mangoConfig, "/opt/bin/yozakura", "systemctl --user start hyprpolkitagent")
	if nu := bootstrapBody(niriConfig, "/b", "systemctl --user start hyprpolkitagent"); !strings.Contains(nu, `spawn-at-startup "systemctl" "--user" "start" "hyprpolkitagent"`) {
		t.Errorf("niri unit fallback not argv:\n%s", nu)
	}
	for _, want := range []string{"exec-once = /opt/bin/yozakura\n", "exec-once = systemctl --user start hyprpolkitagent\n"} {
		if !strings.Contains(mango, want) {
			t.Errorf("mango bootstrap lacks %q:\n%s", want, mango)
		}
	}
	if strings.Contains(bootstrapBody(niriConfig, "/b", ""), "polkit") {
		t.Error("polkit line without an agent")
	}
}

// Before the first shell start the include target must exist and start the
// shell; an existing generated file is never overwritten.
func TestInstallSimpleTargetBootstrapsBeforeFirstStart(t *testing.T) {
	for _, tc := range []struct {
		t        simpleTarget
		cfg, gen string
		want     string
	}{
		{niriConfig, "niri/config.kdl", "niri.kdl", "spawn-at-startup "},
		{mangoConfig, "mango/config.conf", "mango.conf", "exec-once = "},
	} {
		home := t.TempDir()
		t.Setenv("HOME", home)
		t.Setenv("XDG_CONFIG_HOME", "")
		t.Setenv("XDG_DATA_HOME", "")
		installSimpleTarget(tc.t)
		cfg, _ := os.ReadFile(filepath.Join(home, ".config", tc.cfg))
		if !strings.Contains(string(cfg), tc.gen) {
			t.Fatalf("%s lacks the include of %s:\n%s", tc.cfg, tc.gen, cfg)
		}
		genPath := filepath.Join(home, ".local/share", brand.AppID, tc.gen)
		got, err := os.ReadFile(genPath)
		if err != nil || !strings.Contains(string(got), tc.want) {
			t.Fatalf("bootstrap %s: %v\n%s", genPath, err, got)
		}
		os.WriteFile(genPath, []byte("generated\n"), 0o644)
		installSimpleTarget(tc.t)
		if got, _ := os.ReadFile(genPath); string(got) != "generated\n" {
			t.Fatalf("bootstrap overwrote the generated file: %s", got)
		}
	}
}

// goodbye after declining the exclusive restore: the minimal entry (our
// block is all it has) is left alone, never stripped to a bare config.
func TestRemoveHyprlandKeepsExclusiveEntry(t *testing.T) {
	cfg := t.TempDir()
	t.Setenv("XDG_CONFIG_HOME", cfg)
	hypr := filepath.Join(cfg, "hypr")
	if err := os.MkdirAll(hypr, 0o755); err != nil {
		t.Fatal(err)
	}
	entry := filepath.Join(hypr, "hyprland.conf")
	text := brand.ConfigBlockMarker("#") + " exclusive mode\n# replaced\n\n" + hyprConfBlock() + "source = " + filepath.Join(hypr, "user.conf") + "\n"
	if err := os.WriteFile(entry, []byte(text), 0o644); err != nil {
		t.Fatal(err)
	}
	removeHyprland()
	if data, _ := os.ReadFile(entry); string(data) != text {
		t.Fatalf("exclusive entry changed:\n%s", data)
	}
}
