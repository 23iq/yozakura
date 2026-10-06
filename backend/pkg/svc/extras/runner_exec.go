package extras

import (
	"bufio"
	"bytes"
	"context"
	"errors"
	"fmt"
	"io"
	"net/http"
	"net/url"
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
	if errors.Is(err, exec.ErrWaitDelay) && cmd.ProcessState != nil && cmd.ProcessState.Success() {
		return 0, nil // exited fine; a grandchild kept the pipe open
	}
	var ee *exec.ExitError
	if errors.As(err, &ee) {
		code := ee.ExitCode()
		if ws, ok := ee.Sys().(syscall.WaitStatus); ok && ws.Signaled() {
			code = 128 + int(ws.Signal())
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

// scriptRedirectHosts are where the allowlisted installer URLs redirect
// to (claude.ai -> downloads.claude.ai, opencode.ai -> GitHub raw).
var scriptRedirectHosts = map[string]bool{"downloads.claude.ai": true, "raw.githubusercontent.com": true}

const maxScriptRedirects = 3

// ErrScriptRejected wraps installer downloads refused by policy (host,
// scheme, redirects, size, not a script) as opposed to network errors.
var ErrScriptRejected = errors.New("installer rejected")

// scriptFetcher downloads installer scripts over https from allowlisted
// hosts only, on every redirect hop.
type scriptFetcher struct {
	initial, hops map[string]bool
	transport     http.RoundTripper // nil: default
}

func (f scriptFetcher) check(u *url.URL, hosts map[string]bool) error {
	if u.Scheme != "https" || u.User != nil || (!hosts[u.Hostname()] && !f.initial[u.Hostname()]) {
		return fmt.Errorf("%w: url %q not allowed", ErrScriptRejected, u.Redacted())
	}
	return nil
}

func (f scriptFetcher) client() *http.Client {
	return &http.Client{
		Transport: f.transport,
		CheckRedirect: func(req *http.Request, via []*http.Request) error {
			if len(via) > maxScriptRedirects {
				return fmt.Errorf("%w: too many redirects", ErrScriptRejected)
			}
			return f.check(req.URL, f.hops)
		},
	}
}

// DownloadScript fetches a catalog installer script to a private temp file
// and returns its path.
func DownloadScript(ctx context.Context, rawURL string) (string, error) {
	return scriptFetcher{initial: scriptHosts, hops: scriptRedirectHosts}.fetch(ctx, rawURL)
}

func (f scriptFetcher) fetch(ctx context.Context, rawURL string) (string, error) {
	u, err := url.Parse(rawURL)
	if err != nil {
		return "", err
	}
	if err := f.check(u, nil); err != nil {
		return "", err
	}
	ctx, cancel := context.WithTimeout(ctx, scriptTimeout)
	defer cancel()
	req, err := http.NewRequestWithContext(ctx, http.MethodGet, rawURL, nil)
	if err != nil {
		return "", err
	}
	resp, err := f.client().Do(req)
	if err != nil {
		return "", err
	}
	defer resp.Body.Close()
	if resp.StatusCode != http.StatusOK {
		return "", fmt.Errorf("download %s: %s", rawURL, resp.Status)
	}
	data, err := io.ReadAll(io.LimitReader(resp.Body, maxScriptBytes+1))
	if err != nil {
		return "", err
	}
	if len(data) > maxScriptBytes {
		return "", fmt.Errorf("%w: too large", ErrScriptRejected)
	}
	if !bytes.HasPrefix(data, []byte("#!")) {
		return "", fmt.Errorf("%w: not a script (no #! line)", ErrScriptRejected)
	}
	tmp, err := os.CreateTemp("", "yozakura-install-*.sh")
	if err != nil {
		return "", err
	}
	_, err = tmp.Write(data)
	if cerr := tmp.Close(); err == nil {
		err = cerr
	}
	if err != nil {
		os.Remove(tmp.Name())
		return "", err
	}
	return tmp.Name(), nil
}
