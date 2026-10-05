package migrate

import (
	"encoding/json"
	"os"
	"path/filepath"
	"strings"
	"testing"

	"yozakura/backend/pkg/paths"
)

func setup(t *testing.T) (paths.Paths, Legacy, string) {
	home := t.TempDir()
	l := Legacy{ConfigDir: filepath.Join(home, ".config/ambxst"), DataDir: filepath.Join(home, ".local/share/ambxst")}
	p := paths.Paths{ConfigDir: filepath.Join(home, ".config/yozakura"), DataDir: filepath.Join(home, ".local/share/yozakura"), CacheDir: filepath.Join(home, ".cache/yozakura")}
	os.MkdirAll(filepath.Join(l.ConfigDir, "config"), 0o755)
	os.MkdirAll(l.DataDir, 0o755)
	os.WriteFile(filepath.Join(l.ConfigDir, "binds.json"), []byte(`{"a":{"action":"ambxst.launcher"}}`), 0o644)
	os.WriteFile(filepath.Join(l.ConfigDir, "config", "bar.json"), []byte(`{"position":"top"}`), 0o644)
	os.WriteFile(filepath.Join(l.DataDir, "hyprland.lua"), []byte("generated"), 0o644)
	os.WriteFile(filepath.Join(l.DataDir, "pinnedapps.json"), []byte("[]"), 0o644)
	return p, l, home
}

func TestMigrateCopiesAndRewrites(t *testing.T) {
	p, l, _ := setup(t)
	res, err := Run(p, l)
	if err != nil || !res.Migrated {
		t.Fatalf("Run: %v %+v", err, res)
	}
	b, _ := os.ReadFile(filepath.Join(p.ConfigDir, "binds.json"))
	if !strings.Contains(string(b), "yozakura.launcher") || strings.Contains(string(b), "ambxst.") {
		t.Fatalf("binds not rewritten: %s", b)
	}
	if _, err := os.Stat(filepath.Join(p.DataDir, "pinnedapps.json")); err != nil {
		t.Fatal("data not copied")
	}
	if _, err := os.Stat(filepath.Join(p.DataDir, "hyprland.lua")); err == nil {
		t.Fatal("generated compositor files must not be copied")
	}
	legacy, _ := os.ReadFile(filepath.Join(l.ConfigDir, "binds.json"))
	if !strings.Contains(string(legacy), "ambxst.launcher") {
		t.Fatal("legacy dir must be untouched")
	}
}

func TestMigrateSkipsWhenTargetExists(t *testing.T) {
	p, l, _ := setup(t)
	os.MkdirAll(p.ConfigDir, 0o755)
	os.WriteFile(filepath.Join(p.ConfigDir, "binds.json"), []byte(`{"mine":true}`), 0o644)
	res, _ := Run(p, l)
	if res.Migrated {
		t.Fatal("must not migrate over an existing config dir")
	}
	b, _ := os.ReadFile(filepath.Join(p.ConfigDir, "binds.json"))
	if string(b) != `{"mine":true}` {
		t.Fatal("existing config overwritten")
	}
}

func TestRewriteUserReferences(t *testing.T) {
	home := t.TempDir()
	kitty := filepath.Join(home, ".config/kitty/kitty.conf")
	os.MkdirAll(filepath.Dir(kitty), 0o755)
	os.WriteFile(kitty, []byte("include ~/.cache/ambxst/kitty.conf\nfont_size 11\n"), 0o644)
	hypr := filepath.Join(home, ".config/hypr/hyprland.lua")
	os.MkdirAll(filepath.Dir(hypr), 0o755)
	os.WriteFile(hypr, []byte(`loadfile(os.getenv("HOME") .. "/.local/share/ambxst/hyprland.lua")()`+"\n"), 0o644)
	changed, err := rewriteUserReferences(home, "~/.cache/yozakura", "/.local/share/yozakura")
	if err != nil || len(changed) != 2 {
		t.Fatalf("changed=%v err=%v", changed, err)
	}
	k, _ := os.ReadFile(kitty)
	if !strings.Contains(string(k), "include ~/.cache/yozakura/kitty.conf\n") {
		t.Fatalf("kitty: %s", k)
	}
	h, _ := os.ReadFile(hypr)
	if !strings.Contains(string(h), "/.local/share/yozakura/hyprland.lua") {
		t.Fatalf("hypr: %s", h)
	}
	if _, err := os.Stat(kitty + ".pre-yozakura"); err != nil {
		t.Fatal("backup missing")
	}
}

// fullSetup builds a legacy install shaped like a real one: config with
// command strings and preset names, data with big dirs and a mods tree,
// state, cache, notes, plus the user's own files that point at it.
func fullSetup(t *testing.T) (paths.Paths, Legacy, string) {
	home := t.TempDir()
	l := Legacy{
		ConfigDir: filepath.Join(home, ".config/ambxst"),
		DataDir:   filepath.Join(home, ".local/share/ambxst"),
		StateDir:  filepath.Join(home, ".local/state/ambxst"),
		CacheDir:  filepath.Join(home, ".cache/ambxst"),
		NotesDir:  filepath.Join(home, ".local/share/ambxst-notes"),
	}
	p := paths.Paths{
		ConfigDir: filepath.Join(home, ".config/yozakura"),
		DataDir:   filepath.Join(home, ".local/share/yozakura"),
		StateDir:  filepath.Join(home, ".local/state/yozakura"),
		CacheDir:  filepath.Join(home, ".cache/yozakura"),
	}
	write := func(path, text string) {
		t.Helper()
		os.MkdirAll(filepath.Dir(path), 0o755)
		if err := os.WriteFile(path, []byte(text), 0o644); err != nil {
			t.Fatal(err)
		}
	}
	write(filepath.Join(l.ConfigDir, "config/system.json"), `{"lock_cmd": "ambxst lock", "onTimeout": "ambxst screen off", "src": "~/.local/src/ambxst"}`)
	write(filepath.Join(l.ConfigDir, "config/notch.json"), `{"customText": "Ambxst"}`)
	write(filepath.Join(l.ConfigDir, "presets/active_preset"), "Ambxst Default")
	write(filepath.Join(l.ConfigDir, "binds.json"), `{"ambxst": {"launcher": {"key": "Super_L", "action": {"id": "ambxst.launcher"}}}, "defaultAmbxstBinds": {}, "custom": [{"actions": [{"dispatcher": "exec", "argument": "sh -c 'echo x > \"$XDG_RUNTIME_DIR/ambxst_ipc.pipe\"'"}, {"argument": "ambxst-polkit"}]}]}`)
	write(filepath.Join(l.DataDir, "chats/1.json"), `{"title":"hi"}`)
	write(filepath.Join(l.DataDir, "agents/sessions.json"), `{"cwd":"/home/x/.local/share/ambxst/agents/a"}`)
	write(filepath.Join(l.DataDir, "clipboard-pinned.db"), "SQLite format 3\x00\x01ambxst.launcher")
	write(filepath.Join(l.DataDir, "shell_repo"), filepath.Join(home, ".local/src/ambxst"))
	write(filepath.Join(l.DataDir, "axctl.toml"), "generated")
	write(filepath.Join(l.DataDir, "hyprland.axctl.lua"), "generated")
	write(filepath.Join(l.DataDir, "niri.kdl"), "generated")
	write(filepath.Join(l.DataDir, "venv-depth/bin/python"), "#!python")
	write(filepath.Join(l.DataDir, "depth-models/models/m.onnx"), "weights")
	write(filepath.Join(l.DataDir, "whisper/bin/whisper-server"), "bin")
	write(filepath.Join(l.DataDir, "mods/packages/a/yozakura.mod.json"), "{}")
	write(filepath.Join(l.DataDir, "mods/generations/g1/shell.qml"), "old generation")
	write(filepath.Join(l.StateDir, "clipboard.key"), "secret")
	write(filepath.Join(l.CacheDir, "wallpapers.json"), `{"currentWall": "/w/a.jpg"}`)
	write(filepath.Join(l.CacheDir, "kitty.conf"), "color0 #000")
	write(filepath.Join(l.CacheDir, "ambxst.tdesktop-theme"), "old theme")
	write(filepath.Join(l.NotesDir, "index.json"), "[]")
	write(filepath.Join(home, ".config/kitty/kitty.conf"), "include ~/.cache/ambxst/kitty.conf\n")
	write(filepath.Join(home, ".config/hypr/hyprland.lua"), "-- Ambxst\nloadfile(os.getenv(\"HOME\") .. \"/.local/share/ambxst/hyprland.lua\")()\nloadfile(\"custom/sakura.lua\")()\n")
	write(filepath.Join(home, ".config/hypr/hypridle.conf"), "$lock_cmd = ambxst lock || hyprlock\n")
	write(filepath.Join(home, ".config/hypr/custom/keybinds.lua"), "hl.bind(\"X\", hl.dsp.exec_cmd(\"ambxst run config\"))\nhl.exec_cmd(\"systemctl --user start ambxst-polkit.service\")\n")
	write(filepath.Join(home, ".config/nvim/lua/ambxst/init.lua"), "M.palette_file = vim.fn.expand(\"~/.cache/ambxst/nvim-palette.lua\")\n")
	return p, l, home
}

func readFile(t *testing.T, path string) string {
	t.Helper()
	b, err := os.ReadFile(path)
	if err != nil {
		t.Fatalf("read %s: %v", path, err)
	}
	return string(b)
}

func TestMigrateFullInstall(t *testing.T) {
	p, l, home := fullSetup(t)
	res, err := runWithHome(p, l, home)
	if err != nil || !res.Migrated {
		t.Fatalf("Run: %v %+v", err, res)
	}

	sys := readFile(t, filepath.Join(p.ConfigDir, "config/system.json"))
	if !strings.Contains(sys, `"yozakura lock"`) || !strings.Contains(sys, `"yozakura screen off"`) {
		t.Errorf("commands not rewritten: %s", sys)
	}
	if !strings.Contains(sys, "~/.local/src/ambxst") {
		t.Errorf("source checkout path must stay: %s", sys)
	}
	if got := readFile(t, filepath.Join(p.ConfigDir, "config/notch.json")); !strings.Contains(got, `"Yozakura"`) {
		t.Errorf("display name not rewritten: %s", got)
	}
	if got := readFile(t, filepath.Join(p.ConfigDir, "presets/active_preset")); got != "Yozakura Default" {
		t.Errorf("active preset: %q", got)
	}
	binds := readFile(t, filepath.Join(p.ConfigDir, "binds.json"))
	var parsed map[string]json.RawMessage
	if err := json.Unmarshal([]byte(binds), &parsed); err != nil {
		t.Fatalf("binds.json: %v", err)
	}
	if _, ok := parsed["yozakura"]; !ok || parsed["ambxst"] != nil || parsed["defaultAmbxstBinds"] != nil {
		t.Errorf("binds root not renamed: %s", binds)
	}
	if !strings.Contains(binds, `"yozakura.launcher"`) || !strings.Contains(binds, "yozakura_ipc.pipe") || !strings.Contains(binds, `"ambxst-polkit"`) {
		t.Errorf("binds: %s", binds)
	}

	for _, rel := range []string{"chats/1.json", "agents/sessions.json", "clipboard-pinned.db", "shell_repo", "mods/packages/a/yozakura.mod.json"} {
		if _, err := os.Stat(filepath.Join(p.DataDir, rel)); err != nil {
			t.Errorf("data %s not copied", rel)
		}
	}
	if got := readFile(t, filepath.Join(p.DataDir, "agents/sessions.json")); !strings.Contains(got, "/.local/share/yozakura/agents/a") {
		t.Errorf("agents store paths not rewritten: %s", got)
	}
	if got := readFile(t, filepath.Join(p.DataDir, "clipboard-pinned.db")); !strings.Contains(got, "ambxst.launcher") {
		t.Error("binary files must be copied verbatim")
	}
	if got := readFile(t, filepath.Join(p.DataDir, "shell_repo")); !strings.HasSuffix(got, ".local/src/ambxst") {
		t.Errorf("shell_repo must keep the checkout path: %s", got)
	}
	for _, rel := range []string{"axctl.toml", "hyprland.axctl.lua", "niri.kdl", "mods/generations"} {
		if _, err := os.Lstat(filepath.Join(p.DataDir, rel)); err == nil {
			t.Errorf("%s must be regenerated, not copied", rel)
		}
	}
	for _, rel := range []string{"venv-depth", "depth-models", "whisper"} {
		target, err := os.Readlink(filepath.Join(p.DataDir, rel))
		if err != nil || target != filepath.Join(l.DataDir, rel) {
			t.Errorf("%s: want symlink to legacy, got %q %v", rel, target, err)
		}
	}
	if readFile(t, filepath.Join(p.StateDir, "clipboard.key")) != "secret" {
		t.Error("state not copied")
	}
	if _, err := os.Stat(filepath.Join(p.CacheDir, "wallpapers.json")); err != nil {
		t.Error("wallpaper state (cache) not copied")
	}
	if _, err := os.Stat(filepath.Join(p.CacheDir, "ambxst.tdesktop-theme")); err == nil {
		t.Error("legacy-named generated theme must not be copied")
	}
	if _, err := os.Stat(filepath.Join(home, ".local/share/yozakura-notes/index.json")); err != nil {
		t.Error("notes not copied")
	}

	// User files: kitty/nvim/hypr side files right away; the hypr entry file
	// waits until the new generated config exists.
	if got := readFile(t, filepath.Join(home, ".config/kitty/kitty.conf")); !strings.Contains(got, "~/.cache/yozakura/kitty.conf") {
		t.Errorf("kitty: %s", got)
	}
	if got := readFile(t, filepath.Join(home, ".config/nvim/lua/ambxst/init.lua")); !strings.Contains(got, "~/.cache/yozakura/nvim-palette.lua") {
		t.Errorf("nvim: %s", got)
	}
	if got := readFile(t, filepath.Join(home, ".config/hypr/hypridle.conf")); !strings.Contains(got, "yozakura lock || hyprlock") {
		t.Errorf("hypridle: %s", got)
	}
	kb := readFile(t, filepath.Join(home, ".config/hypr/custom/keybinds.lua"))
	if !strings.Contains(kb, `"yozakura run config"`) || !strings.Contains(kb, "ambxst-polkit.service") {
		t.Errorf("keybinds: %s", kb)
	}
	entry := filepath.Join(home, ".config/hypr/hyprland.lua")
	if got := readFile(t, entry); !strings.Contains(got, "/.local/share/ambxst/hyprland.lua") {
		t.Errorf("hypr entry must wait for the generated config: %s", got)
	}
	if len(res.Pending) != 1 || res.Pending[0] != entry {
		t.Errorf("pending: %v", res.Pending)
	}

	// Legacy dirs untouched.
	if got := readFile(t, filepath.Join(l.ConfigDir, "config/system.json")); !strings.Contains(got, `"ambxst lock"`) {
		t.Error("legacy config modified")
	}
	if _, err := os.Stat(filepath.Join(l.CacheDir, "ambxst.tdesktop-theme")); err != nil {
		t.Error("legacy cache modified")
	}

	// Log marker.
	var logged Log
	if err := json.Unmarshal([]byte(readFile(t, filepath.Join(p.DataDir, MarkerFile))), &logged); err != nil {
		t.Fatalf("marker: %v", err)
	}
	if len(logged.Pending) != 1 || len(logged.Notes) == 0 || len(logged.UserFiles) == 0 {
		t.Errorf("marker content: %+v", logged)
	}

	// The generated config shows up: the pending entry file is finished.
	os.WriteFile(filepath.Join(p.DataDir, "hyprland.lua"), []byte("-- new"), 0o644)
	done, err := finishPendingWithHome(p, home)
	if err != nil || len(done) != 1 {
		t.Fatalf("finish: %v %v", done, err)
	}
	got := readFile(t, entry)
	if !strings.Contains(got, "/.local/share/yozakura/hyprland.lua") || !strings.Contains(got, "-- Yozakura") {
		t.Errorf("hypr entry: %s", got)
	}
	if _, err := os.Stat(entry + ".pre-yozakura"); err != nil {
		t.Error("hypr backup missing")
	}
	json.Unmarshal([]byte(readFile(t, filepath.Join(p.DataDir, MarkerFile))), &logged)
	if len(logged.Pending) != 0 {
		t.Errorf("pending not cleared: %v", logged.Pending)
	}

	// Re-running is a no-op.
	res2, err := runWithHome(p, l, home)
	if err != nil || res2.Migrated {
		t.Fatalf("second run: %v %+v", err, res2)
	}
	if done, _ := finishPendingWithHome(p, home); len(done) != 0 {
		t.Errorf("second finish: %v", done)
	}
}

func TestMigrateNoLegacy(t *testing.T) {
	home := t.TempDir()
	p := paths.Paths{ConfigDir: filepath.Join(home, ".config/yozakura"), DataDir: filepath.Join(home, ".local/share/yozakura")}
	res, err := runWithHome(p, Legacy{ConfigDir: filepath.Join(home, ".config/ambxst")}, home)
	if err != nil || res.Migrated || res.Skipped == "" {
		t.Fatalf("%+v %v", res, err)
	}
	if _, err := os.Stat(p.ConfigDir); err == nil {
		t.Fatal("nothing to migrate must not create the config dir")
	}
}

func TestCommandRulesScope(t *testing.T) {
	cfg := applyRules(`{"ambxst": {"x": {"argument": "ambxst run launcher"}}, "exec": "ambxst", "polkit": "ambxst-polkit", "theme": "ambxst.css", "bin": "/usr/bin/ambxst run x"}`, configRules())
	for _, want := range []string{`{"ambxst": {`, `"yozakura run launcher"`, `"exec": "yozakura"`, `"ambxst-polkit"`, `"yozakura.css"`, `"/usr/bin/ambxst run x"`} {
		if !strings.Contains(cfg, want) {
			t.Errorf("config rules: missing %s in %s", want, cfg)
		}
	}
	home := t.TempDir()
	write := func(rel, text string) string {
		path := filepath.Join(home, rel)
		os.MkdirAll(filepath.Dir(path), 0o755)
		os.WriteFile(path, []byte(text), 0o644)
		return path
	}
	nvim := write(".config/nvim/colors/ambxst.lua", "local m = require(\"ambxst\")\nvim.g.colors_name = \"ambxst\"\nlocal f = \"~/.cache/ambxst/nvim-palette.lua\"\n")
	fish := write(".config/fish/config.fish", "alias q 'ambxst'\nset -x X ~/.local/share/ambxst/whisper\n")
	bashrc := write(".bashrc", "alias y=\"ambxst run launcher\"\n")
	hypr := write(".config/hypr/execs.lua", "exec-once = ambxst\nhl.exec_cmd(\"ambxst\")\nhl.exec_cmd(\"ambxst run overview\")\n")
	if _, err := rewriteUserReferences(home, "/.cache/yozakura", "/.local/share/yozakura"); err != nil {
		t.Fatal(err)
	}
	if got := readFile(t, nvim); got != "local m = require(\"ambxst\")\nvim.g.colors_name = \"ambxst\"\nlocal f = \"~/.cache/yozakura/nvim-palette.lua\"\n" {
		t.Errorf("nvim must only get paths:\n%s", got)
	}
	if got := readFile(t, fish); got != "alias q 'yozakura'\nset -x X ~/.local/share/yozakura/whisper\n" {
		t.Errorf("fish:\n%s", got)
	}
	if got := readFile(t, bashrc); got != "alias y=\"yozakura run launcher\"\n" {
		t.Errorf("bashrc:\n%s", got)
	}
	if got := readFile(t, hypr); got != "exec-once = yozakura\nhl.exec_cmd(\"yozakura\")\nhl.exec_cmd(\"yozakura run overview\")\n" {
		t.Errorf("hypr commands:\n%s", got)
	}
}

func TestMigrateSymlinkedLegacyRoots(t *testing.T) {
	p, l, home := setup(t)
	// Dotfiles setups: the legacy dirs are symlinks into a repo.
	for i, dir := range []string{l.ConfigDir, l.DataDir} {
		real := filepath.Join(home, "dotfiles", []string{"config", "data"}[i])
		if err := os.MkdirAll(filepath.Dir(real), 0o755); err != nil {
			t.Fatal(err)
		}
		if err := os.Rename(dir, real); err != nil {
			t.Fatal(err)
		}
		if err := os.Symlink(real, dir); err != nil {
			t.Fatal(err)
		}
	}
	res, err := Run(p, l)
	if err != nil || !res.Migrated {
		t.Fatalf("Run: %v %+v", err, res)
	}
	for _, dir := range []string{p.ConfigDir, p.DataDir} {
		st, err := os.Lstat(dir)
		if err != nil || st.Mode()&os.ModeSymlink != 0 || !st.IsDir() {
			t.Fatalf("%s must be a real directory, not a link to the legacy one (%v)", dir, err)
		}
	}
	b, _ := os.ReadFile(filepath.Join(p.ConfigDir, "binds.json"))
	if !strings.Contains(string(b), "yozakura.launcher") {
		t.Fatalf("binds not rewritten: %s", b)
	}
	legacy, _ := os.ReadFile(filepath.Join(home, "dotfiles", "config", "binds.json"))
	if !strings.Contains(string(legacy), "ambxst.launcher") {
		t.Fatalf("the legacy (dotfiles) files must stay untouched: %s", legacy)
	}
}
