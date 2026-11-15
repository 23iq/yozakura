package convert

import (
	"bytes"
	"context"
	"encoding/binary"
	"errors"
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

// Numbers past int64 stay exact; strings a YAML 1.1 reader would take for
// a bool or a number are quoted.
func TestDataEdgeValues(t *testing.T) {
	got, err := roundTrip(t, "yaml", "big: 123456789012345678901234567890\nneg: -0x_FF\nsmall: 7\n", "json")
	if err != nil || !strings.Contains(got, `"big": 123456789012345678901234567890`) || !strings.Contains(got, `"neg": -255`) ||
		!strings.Contains(got, `"small": 7`) {
		t.Fatalf("yaml->json: %v %s", err, got)
	}
	got, err = roundTrip(t, "csv", "a,b,c\nyes,No,1:20\n", "yaml")
	if err != nil || !strings.Contains(got, `a: "yes"`) || !strings.Contains(got, `b: "No"`) || !strings.Contains(got, `c: "1:20"`) {
		t.Fatalf("csv->yaml: %v %s", err, got)
	}
}

// A data file over the native cap is refused before it is read.
func TestNativeInputSizeCap(t *testing.T) {
	src := filepath.Join(t.TempDir(), "big.json")
	f, _ := os.Create(src)
	_ = f.Truncate(maxNativeInput + 1)
	f.Close()
	err := ConvertNative(src, "json", filepath.Join(t.TempDir(), "o.yaml"), "yaml", QualityBalanced)
	if err == nil || !strings.Contains(err.Error(), "too large") {
		t.Fatalf("got %v", err)
	}
}

// A native step that panics fails the job; one that hangs is left behind
// on cancel and at its timeout.
func TestNativeStepIsContained(t *testing.T) {
	work := t.TempDir()
	run := func(ctx context.Context, st Step) error {
		st.Out = "out"
		p := &Plan{Work: work, Out: filepath.Join(work, "out"), Steps: []Step{st}}
		return p.Run(ctx, nil)
	}
	err := run(context.Background(), Step{Native: func() error { panic("decoder bug") }})
	if err == nil || !strings.Contains(err.Error(), "decoder bug") {
		t.Fatalf("panic: %v", err)
	}
	block := make(chan struct{})
	defer close(block)
	hang := func() error { <-block; return nil }
	ctx, cancel := context.WithCancel(context.Background())
	time.AfterFunc(50*time.Millisecond, cancel)
	start := time.Now()
	if err := run(ctx, Step{Native: hang}); !errors.Is(err, context.Canceled) || time.Since(start) > 5*time.Second {
		t.Fatalf("cancel: %v after %s", err, time.Since(start))
	}
	if err := run(context.Background(), Step{Native: hang, Timeout: 50 * time.Millisecond}); !errors.Is(err, errNativeTimeout) {
		t.Fatalf("timeout: %v", err)
	}
}
