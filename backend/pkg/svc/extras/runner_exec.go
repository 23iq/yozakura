package extras

import (
	"bufio"
	"bytes"
	"context"
	"errors"
	"fmt"
	"io"
	"net/http"
	"os"
	"os/exec"
	"syscall"
	"time"
)

const (
	scriptTimeout  = 2 * time.Minute
	maxScriptBytes = 4 << 20
)

// ExecRunner runs jobs as real processes in their own process group; cancel
// sends SIGTERM to the group, then SIGKILL after a grace period.
type ExecRunner struct{}

// Run implements Runner. stdout and stderr are merged; lines are split on
// \n and \r so redrawn progress bars arrive one by one.
func (ExecRunner) Run(ctx context.Context, argv []string, env []string, line func(string)) (int, error) {
	if len(argv) == 0 {
		return 0, errors.New("empty command")
	}
	cmd := exec.CommandContext(ctx, argv[0], argv[1:]...)
	cmd.Env = append(os.Environ(), env...)
	cmd.Stdin = nil
	cmd.SysProcAttr = &syscall.SysProcAttr{Setpgid: true}
	cmd.Cancel = func() error {
		if cmd.Process == nil {
			return nil
		}
		return syscall.Kill(-cmd.Process.Pid, syscall.SIGTERM)
	}
	cmd.WaitDelay = 10 * time.Second
	pr, pw := io.Pipe()
	cmd.Stdout, cmd.Stderr = pw, pw
	done := make(chan struct{})
	go func() {
		defer close(done)
		splitLines(pr, line)
	}()
	err := cmd.Start()
	if err == nil {
		err = cmd.Wait()
	}
	pw.Close()
	<-done
	var ee *exec.ExitError
	if errors.As(err, &ee) {
		code := ee.ExitCode()
		if code < 0 { // killed by a signal
			code = 128 + int(syscall.SIGTERM)
		}
		return code, nil
	}
	return 0, err
}

// splitLines calls emit for each line of r, splitting on \n, \r and \r\n.
func splitLines(r io.Reader, emit func(string)) {
	sc := bufio.NewScanner(r)
	sc.Buffer(make([]byte, 64*1024), 1024*1024)
	sc.Split(func(data []byte, atEOF bool) (int, []byte, error) {
		if i := bytes.IndexAny(data, "\r\n"); i >= 0 {
			adv := i + 1
			if data[i] == '\r' && i+1 < len(data) && data[i+1] == '\n' {
				adv++
			} else if data[i] == '\r' && i+1 == len(data) && !atEOF {
				return 0, nil, nil
			}
			return adv, data[:i], nil
		}
		if atEOF && len(data) > 0 {
			return len(data), data, nil
		}
		return 0, nil, nil
	})
	for sc.Scan() {
		emit(sc.Text())
	}
	_, _ = io.Copy(io.Discard, r) // drain after an over-long line
}

// DownloadScript fetches a catalog installer script (host allowlist
// re-checked) to a private temp file and returns its path.
func DownloadScript(ctx context.Context, url string) (string, error) {
	if err := (&ScriptSpec{URL: url}).validate(); err != nil {
		return "", err
	}
	ctx, cancel := context.WithTimeout(ctx, scriptTimeout)
	defer cancel()
	req, err := http.NewRequestWithContext(ctx, http.MethodGet, url, nil)
	if err != nil {
		return "", err
	}
	resp, err := http.DefaultClient.Do(req)
	if err != nil {
		return "", err
	}
	defer resp.Body.Close()
	if resp.StatusCode != http.StatusOK {
		return "", fmt.Errorf("download %s: %s", url, resp.Status)
	}
	f, err := os.CreateTemp("", "yozakura-install-*.sh")
	if err != nil {
		return "", err
	}
	n, err := io.Copy(f, io.LimitReader(resp.Body, maxScriptBytes+1))
	if cerr := f.Close(); err == nil {
		err = cerr
	}
	if err == nil && n > maxScriptBytes {
		err = errors.New("installer script too large")
	}
	if err != nil {
		os.Remove(f.Name())
		return "", err
	}
	return f.Name(), nil
}
