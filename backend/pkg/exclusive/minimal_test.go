package exclusive

import (
	"os"
	"path/filepath"
	"strings"
	"testing"

	"yozakura/backend/pkg/brand"
)

// The minimal entry is all Hyprland loads in exclusive mode: it must start
// the polkit agent (the generated config only starts one off Hyprland),
// name a restore command that exists and load user.* from the real dir.
func TestMinimalEntry(t *testing.T) {
	for _, lua := range []bool{true, false} {
		got := minimalEntry(lua, "/b/1", "/x/hypr", "/usr/lib/polkit-kde-authentication-agent-1")
		if !strings.Contains(got, brand.Command("install", "--restore")) {
			t.Errorf("lua=%v: no working restore command:\n%s", lua, got)
		}
		if strings.Contains(got, "exclusive restore") {
			t.Errorf("lua=%v: names a command that does not exist", lua)
		}
		if !strings.Contains(got, "/x/hypr/user.") || strings.Contains(got, "~/.config/hypr") {
			t.Errorf("lua=%v: user file not from the hypr dir:\n%s", lua, got)
		}
		want := "exec-once = /usr/lib/polkit-kde-authentication-agent-1"
		if lua {
			want = `hl.exec_cmd("/usr/lib/polkit-kde-authentication-agent-1")`
		}
		if !strings.Contains(got, want) {
			t.Errorf("lua=%v: no polkit agent start (%s):\n%s", lua, want, got)
		}
	}
	if got := minimalEntry(false, "/b", "/x/hypr", ""); strings.Contains(got, "exec-once") {
		t.Errorf("no agent found: nothing started:\n%s", got)
	}
}

// An entry written before the shell had its own polkit agent started the
// external agent directly; its exact line becomes the fallback command,
// CRLF kept. Edited lines, a non-exclusive entry and a symlinked entry stay.
func TestUpdatePolkitRewritesTheGeneratedLine(t *testing.T) {
	old := []string{"/usr/lib/hyprpolkitagent/hyprpolkitagent", "systemctl --user start hyprpolkitagent"}
	const fallback = "/opt/bin/yozakura polkit-fallback"
	for _, c := range []struct {
		lua    bool
		polkit string
	}{{false, old[0]}, {false, old[1]}, {true, old[0]}, {true, old[1]}} {
		hypr := t.TempDir()
		name := confEntry
		if c.lua {
			name = luaEntry
		}
		path := filepath.Join(hypr, name)
		body := minimalEntry(c.lua, "/b/1", hypr, c.polkit)
		if err := os.WriteFile(path, []byte(body), 0o600); err != nil {
			t.Fatal(err)
		}
		if wrote, err := UpdatePolkit(hypr, old, fallback); err != nil || !wrote {
			t.Fatalf("lua=%v %q: wrote %v, %v", c.lua, c.polkit, wrote, err)
		}
		got, _ := os.ReadFile(path)
		if want := minimalEntry(c.lua, "/b/1", hypr, fallback); string(got) != want {
			t.Errorf("lua=%v %q:\n%s\nwant\n%s", c.lua, c.polkit, got, want)
		}
		if info, _ := os.Stat(path); info.Mode().Perm() != 0o600 {
			t.Errorf("mode changed: %v", info.Mode())
		}
		if wrote, _ := UpdatePolkit(hypr, old, fallback); wrote {
			t.Errorf("lua=%v: rewrote an up-to-date entry", c.lua)
		}
	}

	// CRLF
	hypr := t.TempDir()
	path := filepath.Join(hypr, confEntry)
	crlf := strings.ReplaceAll(minimalEntry(false, "/b", hypr, old[0]), "\n", "\r\n")
	if err := os.WriteFile(path, []byte(crlf), 0o644); err != nil {
		t.Fatal(err)
	}
	if wrote, _ := UpdatePolkit(hypr, old, fallback); !wrote {
		t.Fatal("CRLF entry not updated")
	}
	if got, _ := os.ReadFile(path); !strings.Contains(string(got), "exec-once = "+fallback+"\r\n") {
		t.Errorf("CRLF lost:\n%q", got)
	}

	// Left alone: an edited line, an entry that is not exclusive mode's, a symlink.
	for name, setup := range map[string]func(hypr string){
		"edited": func(hypr string) {
			body := strings.Replace(minimalEntry(false, "/b", hypr, old[0]), "exec-once = "+old[0], "exec-once = "+old[0]+" --verbose", 1)
			os.WriteFile(filepath.Join(hypr, confEntry), []byte(body), 0o644)
		},
		"user entry": func(hypr string) {
			os.WriteFile(filepath.Join(hypr, confEntry), []byte("exec-once = "+old[0]+"\n"), 0o644)
		},
		"symlink": func(hypr string) {
			real := filepath.Join(t.TempDir(), "hyprland.conf")
			os.WriteFile(real, []byte(minimalEntry(false, "/b", hypr, old[0])), 0o644)
			os.Symlink(real, filepath.Join(hypr, confEntry))
		},
	} {
		hypr := t.TempDir()
		setup(hypr)
		before, _ := os.ReadFile(filepath.Join(hypr, confEntry))
		if wrote, err := UpdatePolkit(hypr, old, fallback); wrote || err != nil {
			t.Errorf("%s: wrote %v, %v", name, wrote, err)
		}
		if after, _ := os.ReadFile(filepath.Join(hypr, confEntry)); string(after) != string(before) {
			t.Errorf("%s: changed", name)
		}
	}
}
