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
