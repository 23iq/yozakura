package convert

import (
	"bufio"
	"context"
	"errors"
	"fmt"
	"io"
	"os"
	"path/filepath"
	"strconv"
	"strings"
	"sync"
	"syscall"
	"time"

	"yozakura/backend/pkg/proc"
)

// ProgressFunc receives the fraction done (0..1), or -1 while unknown.
type ProgressFunc func(float64)

// Run executes the plan's steps in order inside p.Work (each bound to ctx
// and to its timeout: cancelling kills the step's whole process group).
// The source is first linked into the work dir under a neutral name, so
// tools never see the user's file name. The result is left at p.Out.
func (p *Plan) Run(ctx context.Context, onProgress ProgressFunc) error {
	if onProgress == nil {
		onProgress = func(float64) {}
	}
	if p.Src != "" && p.Input != "" {
		src, err := filepath.Abs(p.Src)
		if err != nil {
			return err
		}
		if err := placeInput(src, filepath.Join(p.Work, p.Input)); err != nil {
			return err
		}
	}
	for _, st := range p.Steps {
		if err := ctx.Err(); err != nil {
			return err
		}
		if st.Native != nil {
			onProgress(-1)
			if err := st.Native(); err != nil {
				return err
			}
			continue
		}
		if st.Dir == "" {
			st.Dir = p.Work
		}
		if st.Collect != "" {
			if err := os.MkdirAll(filepath.Join(p.Work, st.Collect), 0o755); err != nil {
				return err
			}
		}
		if err := runStep(ctx, st, p.Duration, onProgress); err != nil {
			return err
		}
		if st.Collect != "" {
			if err := collect(filepath.Join(p.Work, st.Collect), filepath.Join(p.Work, st.Out)); err != nil {
				return err
			}
		}
	}
	if fi, err := os.Stat(p.Out); err != nil || fi.Size() == 0 {
		return errors.New("the converter wrote no output")
	}
	return nil
}

// patternChars mean something to ImageMagick or ffmpeg in a file name.
// ImageMagick resolves a symlink to its target's name, so a source whose
// path holds one is hard-linked, else copied, never symlinked.
const patternChars = "%[]*?{}@~:"

func placeInput(src, dst string) error {
	_ = os.Remove(dst)
	if err := os.Link(src, dst); err == nil {
		return nil
	}
	if !strings.ContainsAny(src, patternChars) {
		return os.Symlink(src, dst)
	}
	in, err := os.Open(src)
	if err != nil {
		return err
	}
	defer in.Close()
	out, err := os.OpenFile(dst, os.O_CREATE|os.O_EXCL|os.O_WRONLY, 0o600)
	if err != nil {
		return err
	}
	if _, err := io.Copy(out, in); err != nil {
		out.Close()
		return err
	}
	return out.Close()
}

// errTimeout is a step that ran past its timeout.
var errTimeout = errors.New("timed out")

func runStep(ctx context.Context, st Step, duration float64, onProgress ProgressFunc) error {
	stepCtx := ctx
	if st.Timeout > 0 {
		var cancel context.CancelFunc
		stepCtx, cancel = context.WithTimeoutCause(ctx, st.Timeout, errTimeout)
		defer cancel()
	}
	cmd := proc.Command(context.Background(), st.Prog, st.Args...)
	cmd.Dir = st.Dir
	cmd.SysProcAttr = &syscall.SysProcAttr{Setpgid: true}
	tail := &tailBuffer{max: 64}
	cmd.Stderr = tail
	var stdout io.ReadCloser
	if st.Progress {
		var err error
		if stdout, err = cmd.StdoutPipe(); err != nil {
			return err
		}
	} else {
		cmd.Stdout = tail // LibreOffice reports load errors on stdout
	}
	onProgress(-1)
	if err := proc.StartTied(cmd); err != nil {
		return fmt.Errorf("cannot start %s: %v", filepath.Base(st.Prog), err)
	}
	pgid := cmd.Process.Pid
	release := trackGroup(pgid, filepath.Base(st.Prog))
	// the whole group goes when the step ends, however it ends: helpers
	// such as soffice.bin must not outlive their step
	defer func() {
		_ = syscall.Kill(-pgid, syscall.SIGKILL)
		release()
	}()
	done := make(chan struct{})
	go func() {
		select {
		case <-stepCtx.Done():
			_ = syscall.Kill(-pgid, syscall.SIGKILL)
		case <-done:
		}
	}()
	if stdout != nil {
		readProgress(stdout, duration, onProgress)
	}
	err := cmd.Wait()
	close(done)
	if ctx.Err() != nil {
		return ctx.Err()
	}
	if errors.Is(context.Cause(stepCtx), errTimeout) {
		return fmt.Errorf("%s timed out after %s", filepath.Base(st.Prog), st.Timeout)
	}
	if err != nil {
		if msg := ErrorLine(tail.String()); msg != "" {
			return errors.New(msg)
		}
		return fmt.Errorf("%s failed (%v)", filepath.Base(st.Prog), err)
	}
	return nil
}

// readProgress parses ffmpeg's -progress lines (out_time_us=...) into a
// fraction of the source duration.
func readProgress(r io.Reader, duration float64, onProgress ProgressFunc) {
	sc := bufio.NewScanner(r)
	last := -2.0
	for sc.Scan() {
		f, ok := ParseProgressLine(sc.Text(), duration)
		if ok && (f-last >= 0.005 || f == 1) {
			last = f
			onProgress(f)
		}
	}
	_, _ = io.Copy(io.Discard, r)
}

// ParseProgressLine reads one ffmpeg -progress line; ok when it moved the
// fraction (-1 when the duration is unknown).
func ParseProgressLine(line string, duration float64) (float64, bool) {
	k, v, found := strings.Cut(strings.TrimSpace(line), "=")
	if !found {
		return 0, false
	}
	switch k {
	case "out_time_us", "out_time_ms": // both are microseconds
		us, err := strconv.ParseFloat(v, 64)
		if err != nil || us < 0 {
			return 0, false
		}
		if duration <= 0 {
			return -1, true
		}
		return min(1, us/1e6/duration), true
	case "progress":
		if v == "end" {
			return 1, true
		}
	}
	return 0, false
}

// collect moves the single file a program wrote into dir to out.
func collect(dir, out string) error {
	entries, err := os.ReadDir(dir)
	if err != nil {
		return err
	}
	for _, e := range entries {
		if e.Type().IsRegular() {
			return os.Rename(filepath.Join(dir, e.Name()), out)
		}
	}
	return errors.New("the converter wrote no output")
}

// ProbeDuration asks ffprobe for a media file's length in seconds (0 when
// unknown: progress is then indeterminate).
func (t *Tools) ProbeDuration(ctx context.Context, src string) float64 {
	if t == nil || t.ffprobe == "" {
		return 0
	}
	ctx, cancel := context.WithTimeout(ctx, 10*time.Second)
	defer cancel()
	out, err := proc.Run(ctx, t.ffprobe, "-v", "error", "-show_entries", "format=duration", "-of", "default=noprint_wrappers=1:nokey=1", src)
	if err != nil {
		return 0
	}
	d, err := strconv.ParseFloat(strings.TrimSpace(string(out)), 64)
	if err != nil || d < 0 {
		return 0
	}
	return d
}

// ErrorLine picks the line of a tool's output that says what went wrong:
// the last meaningful one, without ffmpeg's "[codec @ 0x...]" prefixes and
// generic trailers, at most 160 characters.
func ErrorLine(out string) string {
	lines := strings.Split(strings.ReplaceAll(out, "\r", "\n"), "\n")
	for i := len(lines) - 1; i >= 0; i-- {
		l := strings.TrimSpace(lines[i])
		if j := strings.Index(l, "] "); strings.HasPrefix(l, "[") && j > 0 {
			l = strings.TrimSpace(l[j+2:])
		}
		low := strings.ToLower(l)
		if l == "" || generic(low) {
			continue
		}
		if r := []rune(l); len(r) > 160 {
			l = string(r[:159]) + "…"
		}
		return l
	}
	return ""
}

func generic(low string) bool {
	for _, g := range []string{"conversion failed", "exiting normally", "error opening output files",
		"error while filtering", "nothing was written", "convert ", "usage:", "warning: failed to launch javaldx"} {
		if strings.HasPrefix(low, g) {
			return true
		}
	}
	return strings.HasPrefix(low, "javaldx") || strings.HasPrefix(low, "[warning]")
}

// tailBuffer keeps the last max lines written to it.
type tailBuffer struct {
	mu    sync.Mutex
	max   int
	lines []string
	part  string
}

func (b *tailBuffer) Write(p []byte) (int, error) {
	b.mu.Lock()
	defer b.mu.Unlock()
	s := b.part + string(p)
	parts := strings.Split(s, "\n")
	b.part = parts[len(parts)-1]
	if len(b.part) > 4096 {
		b.part = b.part[len(b.part)-4096:]
	}
	b.lines = append(b.lines, parts[:len(parts)-1]...)
	if over := len(b.lines) - b.max; over > 0 {
		b.lines = b.lines[over:]
	}
	return len(p), nil
}

func (b *tailBuffer) String() string {
	b.mu.Lock()
	defer b.mu.Unlock()
	return strings.Join(append(append([]string(nil), b.lines...), b.part), "\n")
}
