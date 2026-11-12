package convert

import (
	"bytes"
	"encoding/binary"
	"hash/crc32"
	"os"
	"path/filepath"
	"strings"
	"testing"
	"time"
)

// A self-referencing alias and a billion-laughs document are refused with
// a short error, quickly, for every target.
func TestYAMLAliasBombsAreRefused(t *testing.T) {
	laughs := "a: &a [\"lol\",\"lol\",\"lol\",\"lol\",\"lol\",\"lol\",\"lol\",\"lol\",\"lol\"]\n" +
		"b: &b [*a,*a,*a,*a,*a,*a,*a,*a,*a]\nc: &c [*b,*b,*b,*b,*b,*b,*b,*b,*b]\n" +
		"d: &d [*c,*c,*c,*c,*c,*c,*c,*c,*c]\ne: &e [*d,*d,*d,*d,*d,*d,*d,*d,*d]\n" +
		"f: &f [*e,*e,*e,*e,*e,*e,*e,*e,*e]\ng: &g [*f,*f,*f,*f,*f,*f,*f,*f,*f]\n" +
		"h: &h [*g,*g,*g,*g,*g,*g,*g,*g,*g]\ni: &i [*h,*h,*h,*h,*h,*h,*h,*h,*h]\n"
	for name, src := range map[string]string{"cycle": "a: &a [*a]\n", "nested cycle": "a: &a {b: [1, *a]}\n", "laughs": laughs} {
		for _, to := range []string{"json", "csv", "toml", "yaml"} {
			start := time.Now()
			_, err := roundTrip(t, "yaml", src, to)
			if err == nil || !strings.Contains(err.Error(), "aliases") {
				t.Errorf("%s -> %s: %v", name, to, err)
			}
			if time.Since(start) > 5*time.Second {
				t.Errorf("%s -> %s took %s", name, to, time.Since(start))
			}
		}
	}
	// a plain shared anchor still works
	if got, err := roundTrip(t, "yaml", "x: &x [1]\ny: *x\n", "json"); err != nil || !strings.Contains(got, `"y": [`) {
		t.Fatalf("shared anchor: %v %s", err, got)
	}
}

// A tiny PNG that declares a huge canvas is refused before decoding.
func TestNativeImageSizeCap(t *testing.T) {
	var b bytes.Buffer
	b.WriteString("\x89PNG\r\n\x1a\n")
	ihdr := make([]byte, 13)
	binary.BigEndian.PutUint32(ihdr[0:], 60000)
	binary.BigEndian.PutUint32(ihdr[4:], 60000)
	ihdr[8], ihdr[9] = 8, 2 // 8-bit RGB
	chunk := func(typ string, data []byte) {
		_ = binary.Write(&b, binary.BigEndian, uint32(len(data)))
		b.WriteString(typ)
		b.Write(data)
		_ = binary.Write(&b, binary.BigEndian, crc32.ChecksumIEEE(append([]byte(typ), data...)))
	}
	chunk("IHDR", ihdr)
	chunk("IEND", nil)
	dir := t.TempDir()
	src := filepath.Join(dir, "huge.png")
	_ = os.WriteFile(src, b.Bytes(), 0o644)
	err := ConvertNative(src, "png", filepath.Join(dir, "o.jpg"), "jpg", QualityBalanced)
	if err == nil || !strings.Contains(err.Error(), "too large") {
		t.Fatalf("huge canvas: %v", err)
	}
}
