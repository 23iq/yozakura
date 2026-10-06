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

// ExecRunner runs jobs as real processes in their own process group (a
// daemon stop never signals them); cancel sends SIGTERM to the group, then
// SIGKILL after a grace period.
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
	// Output goes to an unlinked temp file the daemon follows, never to a
	// pipe: when the daemon goes away (reload) mid-install, a pipe would
	// SIGPIPE pacman/paru mid-transaction; a file just keeps the output.
	out, follow, err := outputFile()
	if err != nil {
		return 0, err
	}
	cmd.Stdout, cmd.Stderr = out, out
	exited := make(chan struct{})
	done := make(chan struct{})
	go func() {
		defer close(done)
		splitLines(&followReader{f: follow, exited: exited}, line)
	}()
	err = cmd.Start()
	out.Close() // the child holds its own copy
	if err == nil {
		err = cmd.Wait()
	}
	close(exited)
	<-done
	follow.Close()
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

// outputFile is a temp file opened for writing (the child's output) and
// for reading (followed), already unlinked: it lives while either is open.
func outputFile() (w, r *os.File, err error) {
	w, err = os.CreateTemp("", "extras-job-*.log")
	if err != nil {
		return nil, nil, err
	}
	defer os.Remove(w.Name())
	r, err = os.Open(w.Name())
	if err != nil {
		w.Close()
		return nil, nil, err
	}
	return w, r, nil
}

// followReader reads a growing file like tail -f until exited is closed,
// then returns what is left and EOF.
type followReader struct {
	f      *os.File
	exited chan struct{}
	last   bool
}

func (r *followReader) Read(p []byte) (int, error) {
	for {
		n, err := r.f.Read(p)
		if n > 0 || (err != nil && err != io.EOF) {
			return n, err
		}
		if r.last {
			return 0, io.EOF
		}
		select {
		case <-r.exited:
			r.last = true // one more read after the exit: the rest
		case <-time.After(50 * time.Millisecond):
		}
	}
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
