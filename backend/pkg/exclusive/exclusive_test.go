package exclusive

import (
	"encoding/json"
	"errors"
	"os"
	"path/filepath"
	"reflect"
	"strings"
	"testing"

	"yozakura/backend/pkg/brand"
	"yozakura/backend/pkg/yozd/ipc"
)

// luaHome builds a Lua setup like the real one: an entry with requires, a
// monitors file, a subdir, a relative symlink, an executable script and an
// entry-adjacent file linked from outside ~/.config/hypr.
func luaHome(t *testing.T) (string, string) {
	home := t.TempDir()
	hypr := filepath.Join(home, ".config/hypr")
	write(t, filepath.Join(hypr, "hyprland.lua"), "require(\"monitors\")\nrequire(\"custom.rules\")\n", 0o644)
	write(t, filepath.Join(hypr, "monitors.lua"), "hl.monitor({ output = \"DP-1\", mode = \"2560x1440@165\", position = \"0x0\", scale = 1 })\n", 0o644)
	write(t, filepath.Join(hypr, "custom/rules.lua"), "hl.config({ input = { kb_layout = \"us,ru\", kb_options = \"grp:alt_shift_toggle\", repeat_rate = 30 } })\n", 0o600)
	write(t, filepath.Join(hypr, "scripts/run.sh"), "#!/bin/sh\n", 0o755)
	if err := os.Symlink("custom/rules.lua", filepath.Join(hypr, "rules-link.lua")); err != nil {
		t.Fatal(err)
	}
	return home, hypr
}

func newSystemd() *fakeSystemd {
	return &fakeSystemd{
		enabled: map[string]bool{"waybar.service": true, "dunst.service": false, "quickshell-foo.service": true, "quickshell-yozakura.service": true},
		active:  map[string]bool{"waybar.service": true},
		listed:  []string{"quickshell-foo.service", "quickshell-yozakura.service", "other.service"},
	}
}

func TestEnableLua(t *testing.T) {
	home, hypr := luaHome(t)
	sd, rec := newSystemd(), &recorder{}
	before := snapshot(t, hypr)
	st, err := Enable(testOptions(t, home, sd, rec))
	if err != nil {
		t.Fatal(err)
	}
	if !st.Active || st.Compositor != "hyprland" {
		t.Fatalf("status %+v", st)
	}
	if !reflect.DeepEqual(st.DisabledUnits, []string{"waybar.service", "quickshell-foo.service"}) {
		t.Fatalf("disabled units %v", st.DisabledUnits)
	}
	if sd.enabled["quickshell-yozakura.service"] != true {
		t.Fatal("our own unit was disabled")
	}
	sameTree(t, before, snapshot(t, filepath.Join(st.Backup, "hypr")))

	var m manifest
	data, _ := os.ReadFile(filepath.Join(st.Backup, "manifest.json"))
	if err := json.Unmarshal(data, &m); err != nil {
		t.Fatal(err)
	}
	if m.Version != 1 || m.Entry != "hyprland.lua" || m.ImportedDisplays != 1 || !m.ImportedKeyboard ||
		!reflect.DeepEqual(m.DisabledUnits, st.DisabledUnits) || m.Created == "" {
		t.Fatalf("manifest %+v", m)
	}

	entry, _ := os.ReadFile(filepath.Join(hypr, "hyprland.lua"))
	if !strings.Contains(string(entry), brand.HyprLuaBlock()) || strings.Contains(string(entry), "require(\"monitors\")") {
		t.Fatalf("minimal entry:\n%s", entry)
	}
	if strings.Index(string(entry), brand.HyprLuaLoadLine()) > strings.Index(string(entry), "user.lua") {
		t.Fatal("user.lua must load after the generated config")
	}
	if user, err := os.ReadFile(filepath.Join(hypr, "user.lua")); err != nil || !strings.HasPrefix(string(user), "--") {
		t.Fatalf("user.lua: %q %v", user, err)
	}
	// untouched user files stay
	if _, err := os.Stat(filepath.Join(hypr, "custom/rules.lua")); err != nil {
		t.Fatal(err)
	}
	if rec.imports != 1 || len(rec.monitors) != 1 || rec.monitors[0].Name != "DP-1" || rec.monitors[0].Refresh != 165 {
		t.Fatalf("imported monitors %+v", rec.monitors)
	}
	if rec.kb == nil || !reflect.DeepEqual(rec.kb.Layouts, []string{"us", "ru"}) || rec.kb.RepeatRate != 30 {
		t.Fatalf("imported keyboard %+v", rec.kb)
	}
	if rec.reloads != 1 {
		t.Fatalf("reloads %d", rec.reloads)
	}
}

func TestEnableIsIdempotent(t *testing.T) {
	home, _ := luaHome(t)
	sd, rec := newSystemd(), &recorder{}
	o := testOptions(t, home, sd, rec)
	first, err := Enable(o)
	if err != nil {
		t.Fatal(err)
	}
	second, err := Enable(o)
	if err != nil {
		t.Fatal(err)
	}
	if len(backups(t, home)) != 1 || rec.imports != 1 || rec.reloads != 1 || len(sd.disabled) != 2 {
		t.Fatalf("second enable was not a no-op: backups %v imports %d reloads %d", backups(t, home), rec.imports, rec.reloads)
	}
	if !reflect.DeepEqual(first, second) {
		t.Fatalf("status differs: %+v vs %+v", first, second)
	}
}

func TestReloadFailureRestores(t *testing.T) {
	home, hypr := luaHome(t)
	sd, rec := newSystemd(), &recorder{}
	o := testOptions(t, home, sd, rec)
	calls := 0
	o.Reload = func() error {
		calls++
		if calls == 1 {
			return errors.New("config errors: line 3")
		}
		return nil
	}
	before := snapshot(t, hypr)
	st, err := Enable(o)
	if err == nil || !strings.Contains(err.Error(), "line 3") {
		t.Fatalf("want reload error, got %v", err)
	}
	if st.Active {
		t.Fatal("still active after rollback")
	}
	sameTree(t, before, snapshot(t, hypr))
	if !sd.enabled["waybar.service"] || !sd.enabled["quickshell-foo.service"] {
		t.Fatal("units not re-enabled")
	}
	if calls != 2 {
		t.Fatalf("rollback must reload the restored config, reloads %d", calls)
	}
	if len(rec.unimports) != 1 || rec.unimports[0]["keyboard.layouts"] != "us" {
		t.Fatalf("rollback must revert the import: %v", rec.unimports)
	}
	if !reflect.DeepEqual(sd.started, []string{"waybar.service"}) {
		t.Fatalf("only units that were running restart: %v", sd.started)
	}
	if len(backups(t, home)) != 0 {
		t.Fatalf("failed attempt left a backup: %v", backups(t, home))
	}
}

func TestImportFailureRestores(t *testing.T) {
	home, hypr := luaHome(t)
	sd, rec := newSystemd(), &recorder{}
	o := testOptions(t, home, sd, rec)
	o.Import = func([]ipc.OutputConfig, *ipc.KeyboardSettings) (map[string]any, error) {
		return nil, errors.New("bad config")
	}
	before := snapshot(t, hypr)
	if _, err := Enable(o); err == nil {
		t.Fatal("want import error")
	}
	sameTree(t, before, snapshot(t, hypr))
	if len(sd.disabled) != 0 || len(rec.unimports) != 0 || rec.reloads != 0 || len(backups(t, home)) != 0 {
		t.Fatalf("import failure must only drop the backup: %+v %v", rec, backups(t, home))
	}
}

func TestRestoreExact(t *testing.T) {
	home, hypr := luaHome(t)
	outside := filepath.Join(home, "dotfiles/hyprland.lua")
	write(t, outside, "-- dotfiles entry\n", 0o644)
	os.Remove(filepath.Join(hypr, "hyprland.lua"))
	if err := os.Symlink(outside, filepath.Join(hypr, "hyprland.lua")); err != nil {
		t.Fatal(err)
	}
	sd, rec := newSystemd(), &recorder{}
	o := testOptions(t, home, sd, rec)
	before := snapshot(t, hypr)
	st, err := Enable(o)
	if err != nil {
		t.Fatal(err)
	}
	if data, _ := os.ReadFile(outside); string(data) != "-- dotfiles entry\n" {
		t.Fatalf("wrote through the entry symlink: %q", data)
	}
	write(t, filepath.Join(hypr, "user.lua"), "-- my tweak\n", 0o644)
	backup := st.Backup

	st, err = Restore(o, "")
	if err != nil {
		t.Fatal(err)
	}
	if st.Active {
		t.Fatal("still active")
	}
	sameTree(t, before, snapshot(t, hypr))
	if !sd.enabled["waybar.service"] || !sd.enabled["quickshell-foo.service"] {
		t.Fatal("units not re-enabled")
	}
	if _, err := os.Stat(filepath.Join(backup, "manifest.json")); err != nil {
		t.Fatal("backup not kept")
	}
	matches, _ := filepath.Glob(filepath.Join(backup, "replaced-*", "user.lua"))
	if len(matches) != 1 {
		t.Fatal("the replaced tree (with user.lua edits) was not kept in the backup")
	}
	if rec.reloads != 2 {
		t.Fatalf("restore must reload, reloads %d", rec.reloads)
	}
	if st.Replaced == "" || filepath.Dir(st.Replaced) != backup || st.Previous["keyboard.layouts"] != "us" || len(rec.unimports) != 0 {
		t.Fatalf("restore status %+v unimports %v", st, rec.unimports)
	}
	if !reflect.DeepEqual(sd.started, []string{"waybar.service"}) {
		t.Fatalf("only units that were running restart: %v", sd.started)
	}
}

func TestRestoreMissingBackup(t *testing.T) {
	home, hypr := luaHome(t)
	sd, rec := newSystemd(), &recorder{}
	o := testOptions(t, home, sd, rec)
	if _, err := Restore(o, ""); !errors.Is(err, ErrNotActive) {
		t.Fatalf("want ErrNotActive, got %v", err)
	}
	st, err := Enable(o)
	if err != nil {
		t.Fatal(err)
	}
	active := snapshot(t, hypr)
	if err := os.RemoveAll(st.Backup); err != nil {
		t.Fatal(err)
	}
	if _, err := Restore(o, st.Backup); err == nil || !strings.Contains(err.Error(), st.Backup) {
		t.Fatalf("want a clear error naming the backup, got %v", err)
	}
	if _, err := Restore(o, ""); !errors.Is(err, ErrNoBackup) {
		t.Fatalf("want ErrNoBackup, got %v", err)
	}
	sameTree(t, active, snapshot(t, hypr))
	if sd.enabled["waybar.service"] {
		t.Fatal("units changed by a failed restore")
	}
}

func TestConfSplitAcrossSources(t *testing.T) {
	home := t.TempDir()
	hypr := filepath.Join(home, ".config/hypr")
	write(t, filepath.Join(hypr, "hyprland.conf"), "source = ./conf/monitors.conf\nsource = ./conf/input.conf\n", 0o644)
	write(t, filepath.Join(hypr, "conf/monitors.conf"), "monitor = HDMI-A-1,1920x1080@60,0x0,1\n", 0o644)
	write(t, filepath.Join(hypr, "conf/input.conf"), "input {\n    kb_layout = de\n}\n", 0o644)
	sd, rec := newSystemd(), &recorder{}
	o := testOptions(t, home, sd, rec)
	before := snapshot(t, hypr)
	st, err := Enable(o)
	if err != nil {
		t.Fatal(err)
	}
	entry, _ := os.ReadFile(filepath.Join(hypr, "hyprland.conf"))
	if !strings.Contains(string(entry), brand.HyprConfBlock()) || strings.Contains(string(entry), "./conf/") ||
		!strings.Contains(string(entry), "source = ~/.config/hypr/user.conf") {
		t.Fatalf("minimal conf:\n%s", entry)
	}
	if _, err := os.Stat(filepath.Join(hypr, "user.conf")); err != nil {
		t.Fatal(err)
	}
	if _, err := os.Stat(filepath.Join(st.Backup, "hypr/conf/input.conf")); err != nil {
		t.Fatal("backup lost the sourced structure")
	}
	if rec.kb == nil || rec.kb.Layouts[0] != "de" || len(rec.monitors) != 1 {
		t.Fatalf("import %+v %+v", rec.monitors, rec.kb)
	}
	if _, err := Restore(o, filepath.Base(st.Backup)); err != nil {
		t.Fatal(err)
	}
	sameTree(t, before, snapshot(t, hypr))
}

func TestExistingUserFileKept(t *testing.T) {
	home, hypr := luaHome(t)
	write(t, filepath.Join(hypr, "user.lua"), "-- mine\n", 0o644)
	if _, err := Enable(testOptions(t, home, newSystemd(), &recorder{})); err != nil {
		t.Fatal(err)
	}
	if data, _ := os.ReadFile(filepath.Join(hypr, "user.lua")); string(data) != "-- mine\n" {
		t.Fatalf("user.lua overwritten: %q", data)
	}
}

func TestRefusals(t *testing.T) {
	t.Run("other compositor", func(t *testing.T) {
		home, hypr := luaHome(t)
		o := testOptions(t, home, newSystemd(), &recorder{})
		o.Compositor = "niri"
		before := snapshot(t, hypr)
		st, err := Enable(o)
		if !errors.Is(err, ErrNotSupported) || st.Reason == "" {
			t.Fatalf("want ErrNotSupported with a reason, got %v %+v", err, st)
		}
		sameTree(t, before, snapshot(t, hypr))
	})
	for _, link := range []string{".config/hypr", ".config/hypr/hyprland.conf"} {
		t.Run("nix store "+link, func(t *testing.T) {
			home := t.TempDir()
			os.MkdirAll(filepath.Join(home, ".config/hypr"), 0o755)
			p := filepath.Join(home, link)
			os.Remove(p)
			if err := os.Symlink("/nix/store/abc-home-manager-files/hypr", p); err != nil {
				t.Fatal(err)
			}
			sd := newSystemd()
			st, err := Enable(testOptions(t, home, sd, &recorder{}))
			if !errors.Is(err, ErrHomeManager) || !strings.Contains(st.Reason, "Nix") {
				t.Fatalf("want ErrHomeManager, got %v %+v", err, st)
			}
			if len(backups(t, home)) != 0 || len(sd.disabled) != 0 {
				t.Fatal("changes made despite refusal")
			}
			if target, _ := os.Readlink(p); target != "/nix/store/abc-home-manager-files/hypr" {
				t.Fatal("link changed")
			}
		})
	}
	t.Run("linked hypr dir", func(t *testing.T) {
		home := t.TempDir()
		write(t, filepath.Join(home, "dots/hypr/hyprland.conf"), "x\n", 0o644)
		os.MkdirAll(filepath.Join(home, ".config"), 0o755)
		os.Symlink(filepath.Join(home, "dots/hypr"), filepath.Join(home, ".config/hypr"))
		if _, err := Enable(testOptions(t, home, newSystemd(), &recorder{})); !errors.Is(err, ErrLinkedDir) {
			t.Fatalf("want ErrLinkedDir, got %v", err)
		}
	})
}

func TestUnitDisableFailureIsReported(t *testing.T) {
	home, _ := luaHome(t)
	sd := newSystemd()
	sd.failOn = "waybar.service"
	st, err := Enable(testOptions(t, home, sd, &recorder{}))
	if err != nil {
		t.Fatal(err)
	}
	if !reflect.DeepEqual(st.DisabledUnits, []string{"quickshell-foo.service"}) || !strings.Contains(st.Reason, "waybar") {
		t.Fatalf("status %+v", st)
	}
}

// A custom config home (XDG_CONFIG_HOME) is the one that is backed up and
// replaced, not <Home>/.config/hypr.
func TestEnableRestoreInCustomHyprDir(t *testing.T) {
	home := t.TempDir()
	hypr := filepath.Join(home, "xdg", "hypr")
	write(t, filepath.Join(hypr, "hyprland.conf"), "monitor = DP-1,preferred,auto,1\n", 0o644)
	rec := &recorder{}
	o := testOptions(t, home, newSystemd(), rec)
	o.HyprDir = hypr
	before := snapshot(t, hypr)
	st, err := Enable(o)
	if err != nil || !st.Active {
		t.Fatalf("enable: %v %+v", err, st)
	}
	if _, err := os.Stat(filepath.Join(home, ".config", "hypr")); err == nil {
		t.Fatal("touched the default dir")
	}
	if _, err := Restore(o, ""); err != nil {
		t.Fatal(err)
	}
	sameTree(t, before, snapshot(t, hypr))
}
