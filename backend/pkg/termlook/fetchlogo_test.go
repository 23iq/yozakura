package termlook

import (
	"bytes"
	"errors"
	"image"
	"image/png"
	"os"
	"path/filepath"
	"strings"
	"testing"
)

func writePNG(t *testing.T, path string, w, h int) {
	t.Helper()
	var b bytes.Buffer
	if err := png.Encode(&b, image.NewRGBA(image.Rect(0, 0, w, h))); err != nil {
		t.Fatal(err)
	}
	if err := os.WriteFile(path, b.Bytes(), 0o644); err != nil {
		t.Fatal(err)
	}
}

func TestCheckLogoPath(t *testing.T) {
	dir := t.TempDir()
	file := func(name, content string) string {
		p := filepath.Join(dir, name)
		if err := os.WriteFile(p, []byte(content), 0o644); err != nil {
			t.Fatal(err)
		}
		return p
	}
	art := file("art.txt", "$1 /\\\n$2/  \\\n")
	ansi := file("art.ans", "\x1b[31m##\x1b[0m\n")
	pic := filepath.Join(dir, "logo.png")
	writePNG(t, pic, 64, 64)
	wide := filepath.Join(dir, "wide.png")
	writePNG(t, wide, 400, 100)
	link := filepath.Join(dir, "link.txt")
	if err := os.Symlink(art, link); err != nil {
		t.Fatal(err)
	}
	big := file("big.txt", strings.Repeat("x", MaxTextLogo+1))
	// hidden: a dot file, a file under a dot directory (~/.ssh), a link to one
	if err := os.Mkdir(filepath.Join(dir, ".ssh"), 0o700); err != nil {
		t.Fatal(err)
	}
	key := file(".ssh/id_ed25519", "-----BEGIN OPENSSH PRIVATE KEY-----\n")
	dotFile := file(".token", "secret\n")
	keyLink := filepath.Join(dir, "key.txt")
	if err := os.Symlink(key, keyLink); err != nil {
		t.Fatal(err)
	}
	cases := []struct {
		path string
		kind string
		err  error
	}{
		{art, LogoText, nil},
		{link, LogoText, nil},
		{ansi, LogoANSI, nil},
		{pic, LogoImage, nil},
		{"", "", ErrLogoPath},
		{"art.txt", "", ErrLogoPath},
		{filepath.Join(dir, "a\nb.txt"), "", ErrLogoPath},
		{filepath.Join(dir, "a\x1bb.txt"), "", ErrLogoPath},
		{filepath.Join(dir, "missing.txt"), "", ErrLogoMissing},
		{dir, "", ErrLogoNotFile},
		{"/dev/null", "", ErrLogoNotFile},
		{big, "", ErrLogoTooLarge},
		{key, "", ErrLogoHidden},
		{dotFile, "", ErrLogoHidden},
		{keyLink, "", ErrLogoHidden},
		{filepath.Join(dir, ".ssh", "..", "art.txt"), LogoText, nil},
		{file("bin.dat", "GIF89a\x00\x01\x02"), "", ErrLogoFormat},
		{file("latin1.txt", "caf\xe9\n"), "", ErrLogoFormat},
		{file("blank.txt", "  \n\n"), "", ErrLogoFormat},
		{file("fake.png", "\x89PNG\r\n\x1a\nnot really"), "", ErrLogoFormat},
	}
	for _, c := range cases {
		got, err := CheckLogoPath(c.path)
		if !errors.Is(err, c.err) || (err == nil && got.Kind != c.kind) {
			t.Errorf("%q: kind %q err %v, want %q %v", c.path, got.Kind, err, c.kind, c.err)
		}
	}
	got, _ := CheckLogoPath(pic)
	if got.Width != ImageLogoWidth || got.Height != 10 {
		t.Errorf("square picture: %dx%d cells", got.Width, got.Height)
	}
	if got, _ := CheckLogoPath(wide); got.Height != 4 {
		t.Errorf("wide picture height %d, want the minimum 4", got.Height)
	}
	if LogoError(ErrLogoTooLarge) != "logo_too_large" || LogoError(nil) != "" {
		t.Error("LogoError keys")
	}
}
