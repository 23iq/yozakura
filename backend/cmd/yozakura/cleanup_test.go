package main

import (
	"bytes"
	"errors"
	"os"
	"path/filepath"
	"strings"
	"testing"

	"yozakura/backend/pkg/brand"
)

func TestRunCleanupsCallsEveryStepAndSummarises(t *testing.T) {
	var ran []string
	var out bytes.Buffer
	steps := []cleanupStep{
		{"a", func(CleanupEnv) ([]string, error) { ran = append(ran, "a"); return []string{"thing a"}, nil }},
		{"b", func(CleanupEnv) ([]string, error) { ran = append(ran, "b"); return nil, errors.New("boom") }},
		{"c", func(CleanupEnv) ([]string, error) { ran = append(ran, "c"); return nil, nil }},
	}
	res := runCleanups(CleanupEnv{Out: &out}, steps)
	if strings.Join(ran, "") != "abc" || len(res) != 3 {
		t.Fatalf("ran %v", ran)
	}
	for _, want := range []string{"removed [a] thing a", "could not finish [b]: boom"} {
		if !strings.Contains(out.String(), want) {
			t.Errorf("summary lacks %q:\n%s", want, out.String())
		}
	}
}

func TestRegisterCleanupReplacesByName(t *testing.T) {
	saved := registeredCleanups()
	t.Cleanup(func() { cleanupSteps = saved })
	calls := 0
	RegisterCleanup("dup-test", func(CleanupEnv) ([]string, error) { calls += 10; return nil, nil })
	RegisterCleanup("dup-test", func(CleanupEnv) ([]string, error) { calls++; return nil, nil })
	if len(registeredCleanups()) != len(saved)+1 {
		t.Fatal("duplicate name registered twice")
	}
	registeredCleanups()[len(saved)].fn(CleanupEnv{})
	if calls != 1 {
		t.Fatalf("calls=%d", calls)
	}
}

// Every real step on a HOME where nothing was ever installed: no error, no
// output of removals, and a second run is the same.
func TestRealCleanupsIdempotentOnEmptyHome(t *testing.T) {
	home := t.TempDir()
	t.Setenv("HOME", home)
	for _, k := range []string{"XDG_CONFIG_HOME", "XDG_DATA_HOME", "XDG_STATE_HOME", "XDG_CACHE_HOME"} {
		t.Setenv(k, "")
	}
	t.Cleanup(func() { pkexecRm = realPkexecRm })
	pkexecRm = func(...string) error { t.Fatal("pkexec called"); return nil }
	for i := 0; i < 2; i++ {
		var out bytes.Buffer
		env := CleanupEnv{Out: &out, Confirm: func(string) bool { return false }, Purge: true, Home: home}
		for _, r := range runCleanups(env, registeredCleanups()) {
			if r.Err != nil || len(r.Removed) != 0 {
				t.Fatalf("run %d step %s: %+v\n%s", i, r.Name, r, out.String())
			}
		}
	}
}

func TestPolkitLineRemovalIsExact(t *testing.T) {
	app := brand.AppID
	dir := t.TempDir()
	conf := filepath.Join(dir, "hyprland.conf")
	lua := filepath.Join(dir, "hyprland.lua")
	confSrc := "bind = a, b\n\nexec-once = systemctl --user start hyprpolkitagent # " + app + ": polkit\n" +
		"exec-once = systemctl --user start hyprpolkitagent\n" +
		"exec-once = polkit-gnome # polkit\n" +
		"exec-once = foo # " + app + ": polkit-other\n"
	luaSrc := "hl.config({})\n\nhl.on(\"hyprland.start\", function() hl.exec_cmd(\"systemctl --user start hyprpolkitagent\") end) -- " + app + ": polkit\n" +
		"hl.on(\"hyprland.start\", function() hl.exec_cmd(\"systemctl --user start hyprpolkitagent\") end)\n" +
		"-- " + app + ": polkit\n"
	os.WriteFile(conf, []byte(confSrc), 0o644)
	os.WriteFile(lua, []byte(luaSrc), 0o644)
	if n, err := removePolkitLines(conf); n != 1 || err != nil {
		t.Fatalf("conf n=%d err=%v", n, err)
	}
	if n, err := removePolkitLines(lua); n != 1 || err != nil {
		t.Fatalf("lua n=%d err=%v", n, err)
	}
	gotConf, _ := os.ReadFile(conf)
	wantConf := "bind = a, b\nexec-once = systemctl --user start hyprpolkitagent\nexec-once = polkit-gnome # polkit\nexec-once = foo # " + app + ": polkit-other\n"
	if string(gotConf) != wantConf {
		t.Fatalf("conf:\n%s", gotConf)
	}
	gotLua, _ := os.ReadFile(lua)
	wantLua := "hl.config({})\nhl.on(\"hyprland.start\", function() hl.exec_cmd(\"systemctl --user start hyprpolkitagent\") end)\n-- " + app + ": polkit\n"
	if string(gotLua) != wantLua {
		t.Fatalf("lua:\n%s", gotLua)
	}
	// A lua marker in a .conf (and the reverse) is not ours.
	if isPolkitLine("exec-once = x -- "+app+": polkit", false) || isPolkitLine("hl.on(x) # "+app+": polkit", true) {
		t.Fatal("matched the other language's marker")
	}
}

func TestBinLinksOnlyOurs(t *testing.T) {
	dir := t.TempDir()
	mine := filepath.Join(t.TempDir(), brand.AppID)
	other := filepath.Join(t.TempDir(), brand.Daemon)
	os.WriteFile(mine, nil, 0o755)
	os.WriteFile(other, nil, 0o755)
	os.Symlink(mine, filepath.Join(dir, brand.AppID))
	os.Symlink(other, filepath.Join(dir, brand.Daemon))
	got := binLinksIn(dir, map[string]bool{mine: true})
	if len(got) != 1 || filepath.Base(got[0]) != brand.AppID {
		t.Fatalf("links %v", got)
	}
}

func TestPurgeNeedsFlagAndConfirmation(t *testing.T) {
	data := t.TempDir()
	state := t.TempDir()
	t.Setenv("XDG_DATA_HOME", data)
	t.Setenv("XDG_STATE_HOME", state)
	dirs := purgeDirs()
	for _, d := range dirs {
		os.MkdirAll(d, 0o755)
	}
	keep := filepath.Join(data, brand.AppID, "keep")
	os.WriteFile(keep, nil, 0o644)
	yes := func(string) bool { return true }
	if r, _ := cleanupPurge(CleanupEnv{Confirm: yes}); len(r) != 0 || !fileExists(dirs[0]) {
		t.Fatal("purged without --purge")
	}
	if r, _ := cleanupPurge(CleanupEnv{Purge: true, Confirm: func(string) bool { return false }}); len(r) != 0 || !fileExists(dirs[0]) {
		t.Fatal("purged without confirmation")
	}
	r, err := cleanupPurge(CleanupEnv{Purge: true, Confirm: yes})
	if err != nil || len(r) != len(dirs) {
		t.Fatalf("removed %v err %v", r, err)
	}
	for _, d := range dirs {
		if fileExists(d) {
			t.Errorf("%s still there", d)
		}
	}
	if !fileExists(keep) {
		t.Error("purge removed unrelated data")
	}
}
