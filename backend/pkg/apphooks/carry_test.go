package apphooks

import (
	"os"
	"path/filepath"
	"strings"
	"testing"
)

func TestRevertKeepsPreexistingEmptyFile(t *testing.T) {
	f := newFake(t)
	conf := filepath.Join(f.env.ConfigHome, "kitty", "kitty.conf")
	write(t, conf, "")
	h := kittyHook{}
	if st, err := h.Apply(f.env); err != nil || st.State != StateConnected {
		t.Fatalf("%v %v", st, err)
	}
	if _, err := h.Revert(f.env); err != nil {
		t.Fatal(err)
	}
	if got := read(t, conf); got != "" {
		t.Fatalf("want empty file kept, got %q", got)
	}
}

func TestRevertThroughSymlinkKeepsLink(t *testing.T) {
	f := newFake(t)
	real := filepath.Join(f.env.Home, "dots", "foot.ini")
	write(t, real, "")
	conf := filepath.Join(f.env.ConfigHome, "foot", "foot.ini")
	if err := os.MkdirAll(filepath.Dir(conf), 0o755); err != nil {
		t.Fatal(err)
	}
	if err := os.Symlink(real, conf); err != nil {
		t.Fatal(err)
	}
	h, _ := Get("foot")
	if _, err := h.Apply(f.env); err != nil {
		t.Fatal(err)
	}
	if _, err := h.Revert(f.env); err != nil {
		t.Fatal(err)
	}
	if st, err := os.Lstat(conf); err != nil || st.Mode()&os.ModeSymlink == 0 {
		t.Fatal("link gone")
	}
	if got := read(t, real); got != "" {
		t.Fatalf("target changed: %q", got)
	}
}

func TestDiscordEmptyObjectAndEmptyThemesSurvive(t *testing.T) {
	for _, orig := range []string{"{}", "{}\n", "{\n  \"enabledThemes\": []\n}\n"} {
		f := newFake(t)
		file := discordSettings(f, "vesktop")
		write(t, file, orig)
		h := discordHook{}
		if st, err := h.Apply(f.env); err != nil || st.State != StateConnected {
			t.Fatalf("%q: %v %v", orig, st, err)
		}
		if _, err := h.Revert(f.env); err != nil {
			t.Fatal(err)
		}
		if got := read(t, file); got != orig {
			t.Fatalf("want %q got %q", orig, got)
		}
	}
}

func TestDiscordContinuesPastManagedClient(t *testing.T) {
	f := newFake(t)
	managed := discordSettings(f, "Vencord")
	write(t, discordSettings(f, "vesktop"), "{}")
	if err := os.MkdirAll(filepath.Dir(managed), 0o755); err != nil {
		t.Fatal(err)
	}
	if err := os.Symlink("/nix/store/abc-settings.json", managed); err != nil {
		t.Fatal(err)
	}
	// good clients before and after the managed one
	write(t, discordSettings(f, "equibop"), "{}")
	st, _ := discordHook{}.Apply(f.env)
	if st.State != StateManaged {
		t.Fatalf("want managed aggregate, got %v", st)
	}
	for _, d := range []string{"vesktop", "equibop"} {
		if !strings.Contains(read(t, discordSettings(f, d)), "yozakura.css") {
			t.Fatalf("%s skipped", d)
		}
	}
}

func TestGhosttyQuotedOptionalInclude(t *testing.T) {
	f := newFake(t)
	conf := filepath.Join(f.env.ConfigHome, "ghostty", "config")
	write(t, conf, "config-file = \"?~/.cache/yozakura/ghostty.conf\"\n")
	h, _ := Get("ghostty")
	if st := h.Status(f.env); st.State != StateConnected {
		t.Fatal(st)
	}
}

func TestQtForeignFileNotConnected(t *testing.T) {
	f := newFake(t)
	fakeQt(t, "qt6ct")
	write(t, filepath.Join(f.env.ConfigHome, "environment.d", "90-yozakura-qt.conf"), "QT_QPA_PLATFORMTHEME=gtk3\n")
	h, _ := Get("qt")
	if st := h.Status(f.env); st.State == StateConnected {
		t.Fatal(st)
	}
}

func TestAlacrittyOurBlockPlusUserGeneralIsError(t *testing.T) {
	f := newFake(t)
	conf := filepath.Join(f.env.ConfigHome, "alacritty", "alacritty.toml")
	write(t, conf, "")
	h, _ := Get("alacritty")
	if st, err := h.Apply(f.env); err != nil || st.State != StateConnected {
		t.Fatalf("%v %v", st, err)
	}
	write(t, conf, read(t, conf)+"\n[general]\nlive_config_reload = true\n")
	if st := h.Status(f.env); st.State != StateError {
		t.Fatal(st)
	}
}

type recHook struct {
	id  string
	err error
	n   *int
}

func (h recHook) ID() string                { return h.id }
func (h recHook) Status(Env) Status         { return Status{ID: h.id} }
func (h recHook) Apply(Env) (Status, error) { return Status{ID: h.id}, nil }
func (h recHook) Revert(Env) (Status, error) {
	*h.n++
	return Status{ID: h.id, State: StateDisconnected}, h.err
}

func TestRevertAllContinuesPastFailure(t *testing.T) {
	n := 0
	res := RevertAll(Env{}, []Hook{recHook{"a", os.ErrPermission, &n}, recHook{"b", nil, &n}})
	if n != 2 || len(res) != 2 || res[0].State != StateError || res[1].State != StateDisconnected {
		t.Fatalf("%d %v", n, res)
	}
}

func TestApplyByIDUnknown(t *testing.T) {
	if _, err := ApplyByID(Env{}, "nope"); err == nil {
		t.Fatal("want error")
	}
}
