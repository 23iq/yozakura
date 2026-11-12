package apphooks

import (
	"errors"
	"os"
	"path/filepath"
	"testing"
)

func TestBlockRoundTrip(t *testing.T) {
	for _, orig := range []string{"", "a", "a\n", "a\n\n", "a\nb\n\nc", "\n"} {
		with, changed := UpsertBlock(orig, "app", "include x")
		if !changed {
			t.Fatalf("%q: not changed", orig)
		}
		if again, ch := UpsertBlock(with, "app", "include x"); ch || again != with {
			t.Fatalf("%q: not idempotent", orig)
		}
		got, ch := RemoveBlock(with, "app")
		if !ch || got != orig {
			t.Fatalf("%q: round trip gave %q", orig, got)
		}
	}
}

func TestUpsertReplacesInPlace(t *testing.T) {
	with, _ := UpsertBlock("a\n", "app", "one")
	mid := with + "tail\n"
	out, ch := UpsertBlock(mid, "app", "two")
	want := "a\n\n# >>> app >>>\ntwo\n# <<< app <<<\ntail\n"
	if !ch || out != want {
		t.Fatalf("got %q", out)
	}
}

func TestHasLine(t *testing.T) {
	c := "# include x\n  include   x  \n"
	if !HasLine(c, "include x") || HasLine("# include x\n", "include x") {
		t.Fatal("HasLine")
	}
}

func TestWriteFileSafe(t *testing.T) {
	d := t.TempDir()
	p := filepath.Join(d, "sub", "f")
	if err := WriteFileSafe(p, []byte("x")); err != nil {
		t.Fatal(err)
	}
	if b, _ := os.ReadFile(p); string(b) != "x" {
		t.Fatal("content")
	}
	if os.Getuid() != 0 {
		ro := filepath.Join(d, "ro")
		_ = os.Mkdir(ro, 0o555)
		if err := WriteFileSafe(filepath.Join(ro, "f"), []byte("x")); !errors.Is(err, ErrManaged) {
			t.Fatalf("readonly dir: %v", err)
		}
	}
}

// A marked block of another marker (the greeting line in ~/.bashrc) is
// added and removed without touching the rest; a file it created goes.
func TestMarkedBlockFile(t *testing.T) {
	home := t.TempDir()
	env := Env{Home: home, ConfigHome: filepath.Join(home, ".config"), DataDir: filepath.Join(home, "data"), AppID: "app"}
	rc := filepath.Join(home, ".bashrc")
	orig := "export A=1\n# >>> app >>>\nother\n# <<< app <<<\n"
	if err := os.WriteFile(rc, []byte(orig), 0o644); err != nil {
		t.Fatal(err)
	}
	changed, err := UpsertMarkedBlock(env, "greet", "app fetch", rc, ". /x")
	if err != nil || !changed {
		t.Fatalf("upsert: %v %v", changed, err)
	}
	if again, _ := UpsertMarkedBlock(env, "greet", "app fetch", rc, ". /x"); again {
		t.Error("second upsert changed the file")
	}
	data, _ := os.ReadFile(rc)
	if want := orig + "\n# >>> app fetch >>>\n. /x\n# <<< app fetch <<<\n"; string(data) != want {
		t.Errorf("got %q", data)
	}
	if _, err := RevertMarkedBlock(env, "greet", "app fetch", rc); err != nil {
		t.Fatal(err)
	}
	if data, _ := os.ReadFile(rc); string(data) != orig {
		t.Errorf("revert gave %q", data)
	}
	// created: removed again
	zrc := filepath.Join(home, "z", ".zshrc")
	if _, err := UpsertMarkedBlock(env, "greet-z", "app fetch", zrc, ". /x"); err != nil {
		t.Fatal(err)
	}
	if _, err := RevertMarkedBlock(env, "greet-z", "app fetch", zrc); err != nil {
		t.Fatal(err)
	}
	if _, err := os.Stat(zrc); !errors.Is(err, os.ErrNotExist) {
		t.Errorf("created file left: %v", err)
	}
	// read-only: refused, untouched
	ro := filepath.Join(home, "ro")
	if err := os.WriteFile(ro, []byte("x\n"), 0o444); err != nil {
		t.Fatal(err)
	}
	if err := os.Chmod(home, 0o555); err != nil {
		t.Fatal(err)
	}
	defer os.Chmod(home, 0o755)
	if os.Geteuid() != 0 {
		if _, err := UpsertMarkedBlock(env, "greet", "app fetch", ro, ". /x"); !errors.Is(err, ErrManaged) {
			t.Errorf("read-only file: %v", err)
		}
	}
}

// Markers the user edited (the end line deleted, the block pasted twice):
// which lines are ours cannot be told, so the file is not touched.
func TestMarkedBlockRefusesEditedMarkers(t *testing.T) {
	home := t.TempDir()
	env := Env{Home: home, ConfigHome: filepath.Join(home, ".config"), DataDir: filepath.Join(home, "data"), AppID: "app"}
	rc := filepath.Join(home, ".bashrc")
	for name, content := range map[string]string{
		"end deleted":   "a\n# >>> app fetch >>>\nmy important line\n",
		"start deleted": "a\n. /x\n# <<< app fetch <<<\nmine\n",
		"twice":         "# >>> app fetch >>>\n. /x\n# <<< app fetch <<<\nmine\n# >>> app fetch >>>\n. /x\n# <<< app fetch <<<\n",
		"nested":        "# >>> app fetch >>>\n# >>> app fetch >>>\n. /x\n# <<< app fetch <<<\n# <<< app fetch <<<\n",
		"end first":     "# <<< app fetch <<<\nmine\n# >>> app fetch >>>\n",
	} {
		if err := os.WriteFile(rc, []byte(content), 0o644); err != nil {
			t.Fatal(err)
		}
		if MarkedBlockOK(content, "app fetch") {
			t.Errorf("%s: accepted", name)
		}
		if _, err := UpsertMarkedBlock(env, "greet", "app fetch", rc, ". /x"); !errors.Is(err, ErrBrokenBlock) {
			t.Errorf("%s: upsert %v", name, err)
		}
		if _, err := RevertMarkedBlock(env, "greet", "app fetch", rc); !errors.Is(err, ErrBrokenBlock) {
			t.Errorf("%s: revert %v", name, err)
		}
		if data, _ := os.ReadFile(rc); string(data) != content {
			t.Errorf("%s: file changed to %q", name, data)
		}
	}
	for _, ok := range []string{"", "a\n", "a\n# >>> app fetch >>>\n. /x\n# <<< app fetch <<<\n", "# >>> app >>>\n# <<< app <<<\n"} {
		if !MarkedBlockOK(ok, "app fetch") {
			t.Errorf("well-formed %q refused", ok)
		}
	}
}

// A file we created keeps that mark when our block changes (and only while
// it holds nothing else): off then removes it.
func TestMarkedBlockFileCreatedSurvivesABodyChange(t *testing.T) {
	home := t.TempDir()
	env := Env{Home: home, ConfigHome: filepath.Join(home, ".config"), DataDir: filepath.Join(home, "data"), AppID: "app"}
	rc := filepath.Join(home, ".zshrc")
	for _, body := range []string{". /x", ". /y"} {
		if _, err := UpsertMarkedBlock(env, "greet", "app fetch", rc, body); err != nil {
			t.Fatal(err)
		}
	}
	if _, err := RevertMarkedBlock(env, "greet", "app fetch", rc); err != nil {
		t.Fatal(err)
	}
	if _, err := os.Stat(rc); !errors.Is(err, os.ErrNotExist) {
		t.Errorf("created file left after a body change: %v", err)
	}
	// the user wrote into it: theirs from then on
	if _, err := UpsertMarkedBlock(env, "greet", "app fetch", rc, ". /x"); err != nil {
		t.Fatal(err)
	}
	data, _ := os.ReadFile(rc)
	if err := os.WriteFile(rc, append(data, "alias mine=1\n"...), 0o644); err != nil {
		t.Fatal(err)
	}
	if _, err := UpsertMarkedBlock(env, "greet", "app fetch", rc, ". /y"); err != nil {
		t.Fatal(err)
	}
	if _, err := RevertMarkedBlock(env, "greet", "app fetch", rc); err != nil {
		t.Fatal(err)
	}
	if data, _ := os.ReadFile(rc); string(data) != "alias mine=1\n" {
		t.Errorf("user content: %q", data)
	}
}
