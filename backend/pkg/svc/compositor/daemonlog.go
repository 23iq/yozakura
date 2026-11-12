package compositor

import (
	"bytes"
	"fmt"
	"io"
	"sync"
	"time"
)

// Limits of the daemon's output in the backend log: a line is cut at
// daemonLogLineMax bytes, and at most daemonLogBurst lines per
// daemonLogWindow pass (the rest is counted and reported once).
const (
	daemonLogLineMax = 1024
	daemonLogBurst   = 100
	daemonLogWindow  = 10 * time.Second
)

// lineLog is the io.Writer the daemon's stdout and stderr go to: whole
// lines, each prefixed, written to out with a size and rate bound, so
// errors of the daemon show in the backend log without flooding it.
type lineLog struct {
	mu     sync.Mutex
	out    io.Writer
	prefix string
	now    func() time.Time

	buf     []byte
	start   time.Time // of the current window
	n       int       // lines written in it
	dropped int       // lines dropped in it
}

func newLineLog(out io.Writer, prefix string) *lineLog {
	return &lineLog{out: out, prefix: prefix, now: time.Now}
}

func (l *lineLog) Write(p []byte) (int, error) {
	l.mu.Lock()
	defer l.mu.Unlock()
	l.buf = append(l.buf, p...)
	for {
		i := bytes.IndexByte(l.buf, '\n')
		if i < 0 {
			break
		}
		l.line(l.buf[:i])
		l.buf = l.buf[i+1:]
	}
	// A line without its end yet is still cut at the bound.
	if len(l.buf) > daemonLogLineMax {
		l.line(l.buf)
		l.buf = nil
	}
	return len(p), nil
}

func (l *lineLog) line(b []byte) {
	b = bytes.TrimRight(b, "\r")
	if len(bytes.TrimSpace(b)) == 0 {
		return
	}
	if now := l.now(); now.Sub(l.start) >= daemonLogWindow {
		if l.dropped > 0 {
			fmt.Fprintf(l.out, "%s(%d more lines dropped)\n", l.prefix, l.dropped)
		}
		l.start, l.n, l.dropped = now, 0, 0
	}
	if l.n >= daemonLogBurst {
		l.dropped++
		return
	}
	l.n++
	if len(b) > daemonLogLineMax {
		b = append(b[:daemonLogLineMax:daemonLogLineMax], "..."...)
	}
	fmt.Fprintf(l.out, "%s%s\n", l.prefix, b)
}
