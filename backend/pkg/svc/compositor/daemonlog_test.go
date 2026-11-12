package compositor

import (
	"bytes"
	"strings"
	"testing"
	"time"
)

func TestLineLogPrefixesWholeLines(t *testing.T) {
	var out bytes.Buffer
	l := newLineLog(&out, "[yozd] ")
	l.Write([]byte("first\nsec"))
	l.Write([]byte("ond\n\n"))
	if got := out.String(); got != "[yozd] first\n[yozd] second\n" {
		t.Fatalf("got %q", got)
	}
	out.Reset()
	l.Write([]byte(strings.Repeat("x", daemonLogLineMax+10) + "\n"))
	if got := out.String(); len(got) != len("[yozd] ")+daemonLogLineMax+len("...\n") {
		t.Fatalf("long line not cut: %d bytes", len(got))
	}
}

func TestLineLogIsRateBounded(t *testing.T) {
	var out bytes.Buffer
	now := time.Unix(1000, 0)
	l := newLineLog(&out, "> ")
	l.now = func() time.Time { return now }
	for i := 0; i < daemonLogBurst+5; i++ {
		l.Write([]byte("spam\n"))
	}
	if n := strings.Count(out.String(), "\n"); n != daemonLogBurst {
		t.Fatalf("%d lines in one window", n)
	}
	now = now.Add(daemonLogWindow)
	l.Write([]byte("later\n"))
	if !strings.HasSuffix(out.String(), "> (5 more lines dropped)\n> later\n") {
		t.Fatalf("no drop note: %q", out.String()[len(out.String())-60:])
	}
}
