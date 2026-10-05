package voice

import (
	"encoding/binary"
	"errors"
	"math"
	"strings"
	"testing"
)

func TestCleanTranscript(t *testing.T) {
	cases := map[string]string{
		"  Hello   world. ":             "Hello world.",
		"[BLANK_AUDIO]":                 "",
		" (music) Привет [laughs] мир ": "Привет мир",
		"Thank you.":                    "",
		"Субтитры сделал DimaTorzok":    "",
		"Thank you. See you tomorrow.":  "Thank you. See you tomorrow.",
		"♪ la la ♪ こんにちは":               "こんにちは",
	}
	for in, want := range cases {
		if got := CleanTranscript(in); got != want {
			t.Errorf("CleanTranscript(%q) = %q, want %q", in, got, want)
		}
	}
}

func TestFormatDictation(t *testing.T) {
	cases := []struct {
		in        string
		punct, sp bool
		want      string
	}{
		{"Hello, world.", true, true, "Hello, world. "},
		{"Hello, world.", false, false, "hello world"},
		{"Привет, как дела?", false, true, "привет как дела "},
		{"I think so.", false, false, "I think so"},
		{"NASA launched.", false, false, "NASA launched"},
		{"こんにちは。元気？", false, false, "こんにちは元気"},
		{"", true, true, ""},
	}
	for _, c := range cases {
		if got := FormatDictation(c.in, c.punct, c.sp); got != c.want {
			t.Errorf("FormatDictation(%q,%v,%v) = %q, want %q", c.in, c.punct, c.sp, got, c.want)
		}
	}
}

func TestLangCode(t *testing.T) {
	for in, want := range map[string]string{"russian": "ru", "English": "en", "japanese": "ja", "ja": "ja", "klingon": ""} {
		if got := LangCode(in); got != want {
			t.Errorf("LangCode(%q) = %q, want %q", in, got, want)
		}
	}
}

func TestEncodeWAV(t *testing.T) {
	w := EncodeWAV([]int16{1, -1, 300})
	if len(w) != 44+6 || string(w[:4]) != "RIFF" || string(w[8:16]) != "WAVEfmt " {
		t.Fatalf("bad header %q", w[:16])
	}
	if sr := binary.LittleEndian.Uint32(w[24:]); sr != SampleRate {
		t.Fatalf("rate %d", sr)
	}
	if got := DecodePCM(w[44:]); got[1] != -1 || got[2] != 300 {
		t.Fatalf("samples %v", got)
	}
}

func TestBandsPeakAtSineFrequency(t *testing.T) {
	frame := make([]int16, FrameSamples)
	for i := range frame {
		frame[i] = int16(16000 * math.Sin(2*math.Pi*1000*float64(i)/SampleRate))
	}
	b := Bands(frame)
	peak := 0
	for i := range b {
		if b[i] > b[peak] {
			peak = i
		}
	}
	// band containing 1 kHz on the 80 Hz..7 kHz log scale
	want := int(math.Log(1000.0/80) / math.Log(7000.0/80) * BandCount)
	if peak < want-1 || peak > want+1 || b[peak] < 0.8 {
		t.Fatalf("peak band %d (%.2f), want ~%d; bands %v", peak, b[peak], want, b)
	}
	if lv := LevelFromEnergy(FrameEnergy(frame)); lv < 0.8 || lv > 0.9 { // -9 dBFS RMS → 0.85
		t.Fatalf("level %.2f for a -9 dBFS RMS sine", lv)
	}
	if LevelFromEnergy(0) != 0 {
		t.Fatal("silence level")
	}
}

func TestTyperFallbacks(t *testing.T) {
	var calls []string
	ty := &Typer{
		Run: func(stdin, name string, args ...string) error {
			calls = append(calls, name+" "+strings.Join(args, " ")+"|"+stdin)
			if name == "wtype" && len(args) > 0 && args[0] == "--" {
				return errors.New("compositor lacks virtual-keyboard")
			}
			return nil
		},
		LookPath: func(n string) (string, error) { return "/usr/bin/" + n, nil },
	}
	used, err := ty.Type("héllo", "auto")
	if err != nil || used != "ydotool" {
		t.Fatalf("auto fallback: used=%q err=%v calls=%v", used, err, calls)
	}
	calls = nil
	if used, err := ty.Type("x", "clipboard"); err != nil || used != "clipboard" || len(calls) != 2 || calls[0] != "wl-copy |x" {
		t.Fatalf("clipboard: %q %v %v", used, err, calls)
	}
	ty.LookPath = func(n string) (string, error) { return "", errors.New("missing") }
	if _, err := ty.Type("x", "auto"); err == nil {
		t.Fatal("no tools should fail")
	}
}
