package apphooks

import (
	"os"
	"path/filepath"
	"strings"
	"testing"
)

func TestGhosttyAppendAndRevert(t *testing.T) {
	f := newFake(t)
	conf := filepath.Join(f.env.ConfigHome, "ghostty", "config")
	orig := "font-size = 12\n"
	write(t, conf, orig)
	h, _ := Get("ghostty")
	f.running = true
	st, err := h.Apply(f.env)
	if err != nil || st.State != StateConnected || !st.NeedsRestart {
		t.Fatalf("%v %v", st, err)
	}
	// optional include (?): a missing theme file is no error in ghostty
	want := orig + "\n# >>> yozakura >>>\nconfig-file = ?~/.cache/yozakura/ghostty.conf\n# <<< yozakura <<<\n"
	if got := read(t, conf); got != want {
		t.Fatalf("got %q", got)
	}
	// the hint belongs to the apply that changed the file, not to every status
	if h.Status(f.env).NeedsRestart {
		t.Fatal("restart hint on a plain status")
	}
	if st, _ := h.Apply(f.env); st.NeedsRestart {
		t.Fatal("restart hint on an apply that changed nothing")
	}
	if _, err := h.Apply(f.env); err != nil || read(t, conf) != want {
		t.Fatal("not idempotent")
	}
	if _, err := h.Revert(f.env); err != nil || read(t, conf) != orig {
		t.Fatalf("revert %q", read(t, conf))
	}
}

func TestGhosttyManualConfigFile(t *testing.T) {
	f := newFake(t)
	conf := filepath.Join(f.env.ConfigHome, "ghostty", "config")
	orig := "config-file=?" + filepath.Join(f.env.CacheDir, "ghostty.conf") + "\n"
	write(t, conf, orig)
	h, _ := Get("ghostty")
	if st := h.Status(f.env); st.State != StateConnected {
		t.Fatal(st)
	}
	if _, err := h.Apply(f.env); err != nil || read(t, conf) != orig {
		t.Fatal("duplicate")
	}
}

func TestFootBlockAtTop(t *testing.T) {
	f := newFake(t)
	conf := filepath.Join(f.env.ConfigHome, "foot", "foot.ini")
	orig := "[main]\nfont=monospace:size=11\n"
	write(t, conf, orig)
	h, _ := Get("foot")
	if _, err := h.Apply(f.env); err != nil {
		t.Fatal(err)
	}
	got := read(t, conf)
	if !strings.HasPrefix(got, "# >>> yozakura >>>\ninclude=~/.cache/yozakura/foot.ini\n# <<< yozakura <<<\n\n[main]") {
		t.Fatalf("got %q", got)
	}
	if _, err := h.Revert(f.env); err != nil || read(t, conf) != orig {
		t.Fatalf("revert %q", read(t, conf))
	}
}

func TestFootMissingFileCreatedAndRemoved(t *testing.T) {
	f := newFake(t)
	conf := filepath.Join(f.env.ConfigHome, "foot", "foot.ini")
	if err := os.MkdirAll(filepath.Dir(conf), 0o755); err != nil {
		t.Fatal(err)
	}
	h, _ := Get("foot")
	if _, err := h.Apply(f.env); err != nil {
		t.Fatal(err)
	}
	if want := "# >>> yozakura >>>\ninclude=~/.cache/yozakura/foot.ini\n# <<< yozakura <<<\n"; read(t, conf) != want {
		t.Fatalf("got %q", read(t, conf))
	}
	if _, err := h.Revert(f.env); err != nil || read(t, conf) != "<missing>" {
		t.Fatal("not removed")
	}
}

func TestAlacrittyAbsentFileCreated(t *testing.T) {
	f := newFake(t)
	conf := filepath.Join(f.env.ConfigHome, "alacritty", "alacritty.toml")
	if err := os.MkdirAll(filepath.Dir(conf), 0o755); err != nil {
		t.Fatal(err)
	}
	h, _ := Get("alacritty")
	if _, err := h.Apply(f.env); err != nil {
		t.Fatal(err)
	}
	want := "# >>> yozakura >>>\n[general]\nimport = [\"~/.cache/yozakura/alacritty.toml\"]\n# <<< yozakura <<<\n"
	if read(t, conf) != want {
		t.Fatalf("got %q", read(t, conf))
	}
	if _, err := h.Revert(f.env); err != nil || read(t, conf) != "<missing>" {
		t.Fatal("not removed")
	}
}

func TestAlacrittyWithGeneralNeverRewritten(t *testing.T) {
	f := newFake(t)
	conf := filepath.Join(f.env.ConfigHome, "alacritty", "alacritty.toml")
	orig := "[general]\nimport = [\"~/x.toml\"]\n"
	write(t, conf, orig)
	h, _ := Get("alacritty")
	st, err := h.Apply(f.env)
	if err != nil || st.State != StateError || !strings.HasPrefix(st.Reason, "manual:") ||
		!strings.Contains(st.Reason, "~/.cache/yozakura/alacritty.toml") {
		t.Fatalf("%v %v", st, err)
	}
	if read(t, conf) != orig {
		t.Fatal("file touched")
	}
}

func TestAlacrittyManualImportConnected(t *testing.T) {
	f := newFake(t)
	conf := filepath.Join(f.env.ConfigHome, "alacritty", "alacritty.toml")
	orig := "[general]\nimport = [\"" + filepath.Join(f.env.CacheDir, "alacritty.toml") + "\"]\n"
	write(t, conf, orig)
	h, _ := Get("alacritty")
	if st := h.Status(f.env); st.State != StateConnected {
		t.Fatal(st)
	}
}

func TestAlacrittyWithoutGeneralAppendsBlock(t *testing.T) {
	f := newFake(t)
	conf := filepath.Join(f.env.ConfigHome, "alacritty", "alacritty.toml")
	orig := "[window]\nopacity = 0.9\n"
	write(t, conf, orig)
	h, _ := Get("alacritty")
	if _, err := h.Apply(f.env); err != nil {
		t.Fatal(err)
	}
	if !strings.Contains(read(t, conf), "[general]\nimport") {
		t.Fatal(read(t, conf))
	}
	if _, err := h.Revert(f.env); err != nil || read(t, conf) != orig {
		t.Fatalf("revert %q", read(t, conf))
	}
}

func TestTerminalNixStoreManaged(t *testing.T) {
	f := newFake(t)
	conf := filepath.Join(f.env.ConfigHome, "foot", "foot.ini")
	if err := os.MkdirAll(filepath.Dir(conf), 0o755); err != nil {
		t.Fatal(err)
	}
	if err := os.Symlink("/nix/store/abc-foot.ini", conf); err != nil {
		t.Fatal(err)
	}
	h, _ := Get("foot")
	if st := h.Status(f.env); st.State != StateManaged {
		t.Fatal(st)
	}
	if _, err := h.Apply(f.env); err != nil {
		t.Fatal(err)
	}
	if got, _ := os.Readlink(conf); got != "/nix/store/abc-foot.ini" {
		t.Fatal("link changed")
	}
}

// An environment.d file of an older build is removed; one the user wrote
// under the same name is kept.
func TestRemoveLegacyQtEnv(t *testing.T) {
	f := newFake(t)
	file := filepath.Join(f.env.ConfigHome, "environment.d", "90-yozakura-qt.conf")
	write(t, file, "# Written by yozakura (Settings > Terminal & Apps). Removed when theming is switched off.\nQT_QPA_PLATFORMTHEME=qt6ct\n")
	if got, err := RemoveLegacyQtEnv(f.env); err != nil || got != file || read(t, file) != "<missing>" {
		t.Fatalf("%q %v", got, err)
	}
	write(t, file, "QT_QPA_PLATFORMTHEME=gtk3\n")
	if got, err := RemoveLegacyQtEnv(f.env); err != nil || got != "" || read(t, file) != "QT_QPA_PLATFORMTHEME=gtk3\n" {
		t.Fatal("foreign file removed")
	}
	if _, ok := Get("qt"); ok {
		t.Fatal("qt is no longer a hook")
	}
}
