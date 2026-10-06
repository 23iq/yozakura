package exclusive

import (
	"encoding/json"
	"os"
	"path/filepath"
	"reflect"
	"strings"
	"sync"
	"syscall"
	"testing"
	"time"
)

func noLeftovers(t *testing.T, home string) {
	t.Helper()
	if m, _ := filepath.Glob(filepath.Join(home, ".config", ".hypr.*")); len(m) > 0 {
		t.Fatalf("staging leftovers: %v", m)
	}
}

func TestRestoreReadOnlyDirTwice(t *testing.T) {
	home, hypr := luaHome(t)
	t.Cleanup(func() { _ = removeTree(home) })
	write(t, filepath.Join(hypr, "ro/locked.conf"), "x\n", 0o444)
	if err := os.Chmod(filepath.Join(hypr, "ro"), 0o555); err != nil {
		t.Fatal(err)
	}
	o := testOptions(t, home, newSystemd(), &recorder{})
	before := snapshot(t, hypr)
	for i := 0; i < 2; i++ {
		if _, err := Enable(o); err != nil {
			t.Fatalf("enable %d: %v", i, err)
		}
		if _, err := Restore(o, ""); err != nil {
			t.Fatalf("restore %d: %v", i, err)
		}
		sameTree(t, before, snapshot(t, hypr))
		noLeftovers(t, home)
	}
}

func TestManifestPersistedPerUnit(t *testing.T) {
	home, _ := luaHome(t)
	sd := newSystemd()
	o := testOptions(t, home, sd, &recorder{})
	var seen []manifest
	sd.onDisable = func(string) {
		dirs := backups(t, home)
		m, err := readManifest(filepath.Join(o.backupRoot(), dirs[len(dirs)-1]))
		if err != nil {
			t.Fatal(err)
		}
		seen = append(seen, m)
	}
	if _, err := Enable(o); err != nil {
		t.Fatal(err)
	}
	if len(seen) != 2 {
		t.Fatalf("disable calls %d", len(seen))
	}
	want := []unitRecord{{Name: "waybar.service", WasActive: true}, {Name: "quickshell-foo.service"}}
	if !reflect.DeepEqual(seen[0].Units, want) || len(seen[0].DisabledUnits) != 0 {
		t.Fatalf("candidates must be recorded before the first disable: %+v", seen[0])
	}
	if !reflect.DeepEqual(seen[1].DisabledUnits, []string{"waybar.service"}) || !seen[1].Units[0].Disabled {
		t.Fatalf("each disable must be persisted: %+v", seen[1])
	}
}

func TestEnableRefusesMarkedBackup(t *testing.T) {
	home, hypr := luaHome(t)
	sd := newSystemd()
	o := testOptions(t, home, sd, &recorder{})
	marked := exclusiveMarker("--") + "\n"
	// The entry gains the marker between the active check and the backup.
	o.Now = func() time.Time {
		write(t, filepath.Join(hypr, "hyprland.lua"), marked, 0o644)
		return time.Date(2026, 10, 6, 12, 0, 0, 0, time.Local)
	}
	if _, err := Enable(o); err == nil {
		t.Fatal("want a refusal")
	}
	if len(backups(t, home)) != 0 || len(sd.disabled) != 0 {
		t.Fatal("changes made despite refusal")
	}
	if data, _ := os.ReadFile(filepath.Join(hypr, "hyprland.lua")); string(data) != marked {
		t.Fatal("entry changed")
	}
}

func TestReplacedTreesNeverOverwritten(t *testing.T) {
	home, hypr := luaHome(t)
	o := testOptions(t, home, newSystemd(), &recorder{})
	o.Now = func() time.Time { return time.Date(2026, 10, 6, 12, 0, 0, 0, time.Local) }
	st, err := Enable(o)
	if err != nil {
		t.Fatal(err)
	}
	first, err := Restore(o, "")
	if err != nil {
		t.Fatal(err)
	}
	write(t, filepath.Join(hypr, "later.lua"), "-- later\n", 0o644)
	second, err := Restore(o, st.Backup) // inactive: allowed with an explicit backup
	if err != nil {
		t.Fatal(err)
	}
	if first.Replaced == second.Replaced || !strings.HasSuffix(second.Replaced, "-1") {
		t.Fatalf("replaced paths %q %q", first.Replaced, second.Replaced)
	}
	if _, err := os.Stat(filepath.Join(first.Replaced, "user.lua")); err != nil {
		t.Fatal("first replaced tree lost")
	}
	if _, err := os.Stat(filepath.Join(second.Replaced, "later.lua")); err != nil {
		t.Fatal("second replaced tree incomplete")
	}
}

func TestMissingConfigDir(t *testing.T) {
	home := t.TempDir()
	o := testOptions(t, home, newSystemd(), &recorder{})
	st, err := Enable(o)
	if err != nil {
		t.Fatal(err)
	}
	if !st.Active {
		t.Fatal("not active")
	}
	var m manifest
	data, _ := os.ReadFile(filepath.Join(st.Backup, "manifest.json"))
	_ = json.Unmarshal(data, &m)
	if !m.HyprMissing || m.Entry != "hyprland.conf" {
		t.Fatalf("manifest %+v", m)
	}
	if _, err := Restore(o, ""); err != nil {
		t.Fatal(err)
	}
	if _, err := os.Lstat(filepath.Join(home, ".config/hypr")); !os.IsNotExist(err) {
		t.Fatal("restore must leave no hypr dir")
	}
	noLeftovers(t, home)
}

func TestCopyTreeRejectsSpecialFiles(t *testing.T) {
	src := filepath.Join(t.TempDir(), "src")
	write(t, filepath.Join(src, "a.conf"), "x", 0o644)
	if err := syscall.Mkfifo(filepath.Join(src, "pipe"), 0o644); err != nil {
		t.Skip("mkfifo:", err)
	}
	if err := copyTree(src, filepath.Join(t.TempDir(), "dst")); err == nil || !strings.Contains(err.Error(), "pipe") {
		t.Fatalf("want special-file error, got %v", err)
	}
}

func TestConcurrentEnableMakesOneBackup(t *testing.T) {
	home, _ := luaHome(t)
	rec := &recorder{}
	o := testOptions(t, home, newSystemd(), rec)
	var mu sync.Mutex
	now := o.Now
	o.Now = func() time.Time { mu.Lock(); defer mu.Unlock(); return now() }
	var wg sync.WaitGroup
	errs := make([]error, 2)
	for i := range errs {
		wg.Add(1)
		go func(i int) {
			defer wg.Done()
			_, errs[i] = Enable(o)
		}(i)
	}
	wg.Wait()
	if errs[0] != nil || errs[1] != nil {
		t.Fatal(errs)
	}
	if len(backups(t, home)) != 1 || rec.imports != 1 {
		t.Fatalf("backups %v imports %d", backups(t, home), rec.imports)
	}
}
