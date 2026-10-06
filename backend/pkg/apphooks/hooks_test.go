package apphooks

import (
	"os"
	"path/filepath"
	"syscall"
	"testing"
)

type fake struct {
	env     Env
	signals []string
	running bool
}

func newFake(t *testing.T) *fake {
	home := t.TempDir()
	f := &fake{}
	f.env = Env{
		Home: home, ConfigHome: filepath.Join(home, ".config"),
		CacheDir: filepath.Join(home, ".cache", "yozakura"), AppID: "yozakura",
		Running: func(string) bool { return f.running },
		Signal:  func(p string, s syscall.Signal) { f.signals = append(f.signals, p) },
	}
	return f
}

func write(t *testing.T, p, s string) {
	t.Helper()
	if err := os.MkdirAll(filepath.Dir(p), 0o755); err != nil {
		t.Fatal(err)
	}
	if err := os.WriteFile(p, []byte(s), 0o644); err != nil {
		t.Fatal(err)
	}
}

func read(t *testing.T, p string) string {
	t.Helper()
	b, err := os.ReadFile(p)
	if err != nil {
		return "<missing>"
	}
	return string(b)
}

func TestKittyMissingFile(t *testing.T) {
	f := newFake(t)
	conf := filepath.Join(f.env.ConfigHome, "kitty", "kitty.conf")
	h := kittyHook{}
	if err := os.MkdirAll(filepath.Dir(conf), 0o755); err != nil {
		t.Fatal(err)
	}
	if h.Status(f.env).State != StateDisconnected {
		t.Fatal("want disconnected")
	}
	st, err := h.Apply(f.env)
	if err != nil || st.State != StateConnected {
		t.Fatalf("%v %v", st, err)
	}
	want := "# >>> yozakura >>>\ninclude ~/.cache/yozakura/kitty.conf\n# <<< yozakura <<<\n"
	if got := read(t, conf); got != want {
		t.Fatalf("got %q", got)
	}
	if len(f.signals) != 1 {
		t.Fatal("no SIGUSR1")
	}
	if _, err := h.Apply(f.env); err != nil || read(t, conf) != want || len(f.signals) != 1 {
		t.Fatal("not idempotent")
	}
	if st, _ := h.Revert(f.env); st.State != StateDisconnected || read(t, conf) != "<missing>" {
		t.Fatalf("revert: %v %q", st, read(t, conf))
	}
}

func TestKittyExistingFileRevertByteIdentical(t *testing.T) {
	f := newFake(t)
	conf := filepath.Join(f.env.ConfigHome, "kitty", "kitty.conf")
	orig := "font_size 12\nbackground #000"
	write(t, conf, orig)
	h := kittyHook{}
	if _, err := h.Apply(f.env); err != nil {
		t.Fatal(err)
	}
	if _, err := h.Revert(f.env); err != nil || read(t, conf) != orig {
		t.Fatalf("got %q", read(t, conf))
	}
}

func TestKittyManualIncludeIsConnected(t *testing.T) {
	f := newFake(t)
	conf := filepath.Join(f.env.ConfigHome, "kitty", "kitty.conf")
	orig := "include " + filepath.Join(f.env.CacheDir, "kitty.conf") + "\n"
	write(t, conf, orig)
	h := kittyHook{}
	if st := h.Status(f.env); st.State != StateConnected {
		t.Fatal(st)
	}
	if _, err := h.Apply(f.env); err != nil || read(t, conf) != orig {
		t.Fatal("duplicate block")
	}
	if _, err := h.Revert(f.env); err != nil || read(t, conf) != orig {
		t.Fatal("revert touched manual include")
	}
}

func TestKittyAbsent(t *testing.T) {
	f := newFake(t)
	t.Setenv("PATH", "")
	if st := (kittyHook{}).Status(f.env); st.State != StateAbsent {
		t.Fatal(st)
	}
}

func TestKittyNixStoreSymlinkManaged(t *testing.T) {
	f := newFake(t)
	conf := filepath.Join(f.env.ConfigHome, "kitty", "kitty.conf")
	if err := os.MkdirAll(filepath.Dir(conf), 0o755); err != nil {
		t.Fatal(err)
	}
	// Dangling link into the Nix store: resolves there without needing /nix.
	if err := os.Symlink("/nix/store/abc-kitty.conf", conf); err != nil {
		t.Fatal(err)
	}
	if st := (kittyHook{}).Status(f.env); st.State != StateManaged {
		t.Fatalf("status %v", st)
	}
	st, err := (kittyHook{}).Apply(f.env)
	if st.State != StateManaged || err != nil {
		t.Fatalf("%v %v", st, err)
	}
	if _, lerr := os.Lstat(conf); lerr != nil {
		t.Fatal("link replaced")
	}
	if got, _ := os.Readlink(conf); got != "/nix/store/abc-kitty.conf" {
		t.Fatal("link changed")
	}
}

func discordSettings(f *fake, dir string) string {
	return filepath.Join(f.env.ConfigHome, dir, "settings", "settings.json")
}

func TestDiscordApplyRevert(t *testing.T) {
	f := newFake(t)
	p := discordSettings(f, "vesktop")
	orig := "{\n  \"zeta\": 1,\n  \"enabledThemes\": [\n    \"other.css\"\n  ],\n  \"alpha\": {\n    \"x\": true\n  }\n}"
	write(t, p, orig)
	h := discordHook{}
	f.running = true
	st, err := h.Apply(f.env)
	if err != nil || st.State != StateConnected || !st.NeedsRestart {
		t.Fatalf("%v %v", st, err)
	}
	want := "{\n  \"zeta\": 1,\n  \"enabledThemes\": [\n    \"other.css\",\n    \"yozakura.css\"\n  ],\n  \"alpha\": {\n    \"x\": true\n  }\n}"
	if got := read(t, p); got != want {
		t.Fatalf("got %q", got)
	}
	if st, _ := h.Apply(f.env); st.NeedsRestart || read(t, p) != want {
		t.Fatal("not idempotent")
	}
	if _, err := h.Revert(f.env); err != nil || read(t, p) != orig {
		t.Fatalf("revert %q", read(t, p))
	}
}

func TestDiscordMissingKeyAndFile(t *testing.T) {
	f := newFake(t)
	p := discordSettings(f, "Vencord")
	write(t, p, "{\"a\":1}\n")
	h := discordHook{}
	if _, err := h.Apply(f.env); err != nil {
		t.Fatal(err)
	}
	if got := read(t, p); got != "{\n  \"a\": 1,\n  \"enabledThemes\": [\n    \"yozakura.css\"\n  ]\n}\n" {
		t.Fatalf("got %q", got)
	}
	if _, err := h.Revert(f.env); err != nil || read(t, p) != "{\n  \"a\": 1\n}\n" {
		t.Fatalf("revert %q", read(t, p))
	}
	// dir exists, file missing
	f2 := newFake(t)
	p2 := discordSettings(f2, "vesktop")
	if err := os.MkdirAll(filepath.Dir(filepath.Dir(p2)), 0o755); err != nil {
		t.Fatal(err)
	}
	if _, err := h.Apply(f2.env); err != nil || read(t, p2) == "<missing>" {
		t.Fatal("not created")
	}
	if _, err := h.Revert(f2.env); err != nil || read(t, p2) != "<missing>" {
		t.Fatal("not removed")
	}
}

func TestDiscordUnparsableUntouched(t *testing.T) {
	f := newFake(t)
	p := discordSettings(f, "vesktop")
	write(t, p, "{ nope")
	st, err := (discordHook{}).Apply(f.env)
	if st.State != StateError || st.Reason == "" || err != nil || read(t, p) != "{ nope" {
		t.Fatalf("%v %v", st, err)
	}
}

func TestDiscordFlatpakAndAbsent(t *testing.T) {
	f := newFake(t)
	h := discordHook{}
	if h.Status(f.env).State != StateAbsent {
		t.Fatal("want absent")
	}
	p := filepath.Join(f.env.Home, ".var/app/dev.vencord.Vesktop/config/vesktop/settings/settings.json")
	write(t, p, "{}")
	if st, err := h.Apply(f.env); err != nil || st.State != StateConnected {
		t.Fatal(st, err)
	}
}

func TestRegistry(t *testing.T) {
	if _, ok := Get("kitty"); !ok {
		t.Fatal("kitty")
	}
	if len(All()) < 2 {
		t.Fatal("all")
	}
}
