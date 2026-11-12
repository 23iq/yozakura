package main

import (
	"os"
	"path/filepath"
	"strings"
	"testing"

	"yozakura/backend/pkg/brand"
)

const (
	oldConfPolkit = "exec-once = systemctl --user start hyprpolkitagent # yozakura: polkit"
	oldLuaPolkit  = `hl.on("hyprland.start", function() hl.exec_cmd("systemctl --user start hyprpolkitagent") end) -- yozakura: polkit`
	newConfPolkit = "exec-once = /opt/bin/yozakura polkit-fallback # yozakura: polkit"
	newLuaPolkit  = `hl.on("hyprland.start", function() hl.exec_cmd("/opt/bin/yozakura polkit-fallback") end) -- yozakura: polkit`
)

func writeHypr(t *testing.T, home, name, body string) string {
	t.Helper()
	dir := filepath.Join(home, ".config/hypr")
	if err := os.MkdirAll(dir, 0o755); err != nil {
		t.Fatal(err)
	}
	path := filepath.Join(dir, name)
	if err := os.WriteFile(path, []byte(body), 0o644); err != nil {
		t.Fatal(err)
	}
	return path
}

func readText(t *testing.T, path string) string {
	t.Helper()
	b, err := os.ReadFile(path)
	if err != nil {
		t.Fatal(err)
	}
	return string(b)
}

// The startup repair turns the installer's old line into polkit-fallback,
// once, in both entry languages, and goodbye still finds the new line.
func TestRepairMigratesInstallerPolkitLine(t *testing.T) {
	for _, tc := range []struct{ name, old, want string }{
		{"hyprland.conf", oldConfPolkit, newConfPolkit},
		{"hyprland.lua", oldLuaPolkit, newLuaPolkit},
	} {
		t.Run(tc.name, func(t *testing.T) {
			home := t.TempDir()
			body := "monitor = , preferred, auto, 1\n\n" + tc.old + "\n"
			path := writeHypr(t, home, tc.name, body)

			repairHyprlandEntry(home, "/opt/bin/yozakura")
			got := readText(t, path)
			if want := "monitor = , preferred, auto, 1\n\n" + tc.want + "\n"; got != want {
				t.Fatalf("got:\n%s\nwant:\n%s", got, want)
			}

			repairHyprlandEntry(home, "/other/yozakura")
			if again := readText(t, path); again != got {
				t.Fatalf("second repair changed the line:\n%s", again)
			}

			if n, err := removePolkitLines(path); n != 1 || err != nil {
				t.Fatalf("goodbye removed %d lines (%v)", n, err)
			}
			if left := readText(t, path); strings.Contains(left, "polkit") {
				t.Fatalf("polkit line left after goodbye:\n%s", left)
			}
		})
	}
}

// Only the exact old line with our marker changes: the user's own agent
// line, one without the marker or one they edited stays as it is.
func TestRepairLeavesOtherPolkitLines(t *testing.T) {
	home := t.TempDir()
	body := strings.Join([]string{
		"exec-once = systemctl --user start hyprpolkitagent",
		"exec-once = /usr/lib/polkit-gnome/polkit-gnome-authentication-agent-1 # yozakura: polkit",
		"exec-once = systemctl --user start hyprpolkitagent && notify-send hi # yozakura: polkit",
		"# exec-once = systemctl --user start hyprpolkitagent # yozakura: polkit",
		"",
	}, "\n")
	path := writeHypr(t, home, "hyprland.conf", body)
	lua := writeHypr(t, home, "hyprland.lua", `hl.exec_cmd("systemctl --user start hyprpolkitagent") -- yozakura: polkit`+"\n")

	repairHyprlandEntry(home, "/opt/bin/yozakura")
	if got := readText(t, path); got != body {
		t.Fatalf("user lines changed:\n%s", got)
	}
	if got := readText(t, lua); strings.Contains(got, "polkit-fallback") {
		t.Fatalf("lua line in another form changed:\n%s", got)
	}
}

// Like the rest of the repair, nothing is written while an entry is a
// Home Manager link into the Nix store.
func TestRepairPolkitSkipsHomeManagerEntry(t *testing.T) {
	home := t.TempDir()
	lua := writeHypr(t, home, "hyprland.lua", oldLuaPolkit+"\n")
	// isHomeManagerManaged reads the link text, so a /nix/store target that
	// does not exist here is enough.
	if err := os.Symlink("/nix/store/abc-home-manager-files/hypr/hyprland.conf", filepath.Join(home, ".config/hypr/hyprland.conf")); err != nil {
		t.Fatal(err)
	}
	repairHyprlandEntry(home, "/opt/bin/yozakura")
	if got := readText(t, lua); got != oldLuaPolkit+"\n" {
		t.Fatalf("changed: %s", got)
	}
	if ok, err := migratePolkitLine(lua, ""); ok || err != nil {
		t.Fatalf("no launcher: wrote %v (%v)", ok, err)
	}
}

// Exclusive mode's minimal entry, written before the shell had its own
// agent, started hyprpolkitagent directly: the repair points it at
// polkit-fallback, in the generated entry only.
func TestRepairMigratesExclusiveEntryPolkitLine(t *testing.T) {
	home := t.TempDir()
	marker := brand.ConfigBlockMarker("#") + " exclusive mode"
	body := marker + "\n# This file was replaced by exclusive mode.\n\nexec-once = /usr/lib/hyprpolkitagent/hyprpolkitagent\nsource = /x/user.conf\n"
	path := writeHypr(t, home, "hyprland.conf", body)
	repairHyprlandEntry(home, "/opt/bin/yozakura")
	want := strings.Replace(body, "/usr/lib/hyprpolkitagent/hyprpolkitagent", "/opt/bin/yozakura polkit-fallback", 1)
	if got := readText(t, path); got != want {
		t.Fatalf("got:\n%s\nwant:\n%s", got, want)
	}
	user := "exec-once = /usr/lib/hyprpolkitagent/hyprpolkitagent\n"
	path = writeHypr(t, home, "hyprland.conf", user)
	repairHyprlandEntry(home, "/opt/bin/yozakura")
	if got := readText(t, path); got != user {
		t.Fatalf("a user entry changed:\n%s", got)
	}
}

// The installer and the repair write the same text (install.sh mirrors it).
func TestPolkitEntryLineForms(t *testing.T) {
	if got := polkitEntryLine(false, "/opt/bin/yozakura polkit-fallback"); got != newConfPolkit {
		t.Errorf("conf: %s", got)
	}
	if got := polkitEntryLine(true, "/opt/bin/yozakura polkit-fallback"); got != newLuaPolkit {
		t.Errorf("lua: %s", got)
	}
	for _, l := range []string{newConfPolkit, oldConfPolkit} {
		if !isPolkitLine(l, false) {
			t.Errorf("goodbye misses %q", l)
		}
	}
	for _, l := range []string{newLuaPolkit, oldLuaPolkit} {
		if !isPolkitLine(l, true) {
			t.Errorf("goodbye misses %q", l)
		}
	}
}
