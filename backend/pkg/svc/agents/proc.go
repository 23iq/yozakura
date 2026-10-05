package agents

import (
	"bufio"
	"encoding/json"
	"io"
	"os"
	"os/exec"
	"sync"
	"syscall"
	"time"
	"yozakura/backend/pkg/brand"
)

// proc is a line-oriented child process (JSON lines on stdin/stdout).
type proc struct {
	cmd    *exec.Cmd
	stdin  io.WriteCloser
	wmu    sync.Mutex
	stderr *tailBuffer
	done   chan struct{}
	err    error
	closed bool
}

// startProc spawns bin in cwd; onLine is called from the reader goroutine
// for every stdout line, onExit once after the process is reaped.
func startProc(bin string, args []string, cwd string, env []string, onLine func([]byte), onExit func(err error, stderr string)) (*proc, error) {
	cmd := exec.Command(bin, args...)
	cmd.Dir = cwd
	cmd.Env = append(cleanEnv(os.Environ()), env...)
	// Own group (stop() signals it) and SIGTERM when the daemon dies.
	cmd.SysProcAttr = &syscall.SysProcAttr{Setpgid: true, Pdeathsig: syscall.SIGTERM}
	stdin, err := cmd.StdinPipe()
	if err != nil {
		return nil, err
	}
	stdout, err := cmd.StdoutPipe()
	if err != nil {
		return nil, err
	}
	p := &proc{cmd: cmd, stdin: stdin, stderr: &tailBuffer{max: 8 << 10}, done: make(chan struct{})}
	cmd.Stderr = p.stderr
	if err := cmd.Start(); err != nil {
		return nil, err
	}
	go func() {
		sc := bufio.NewScanner(stdout)
		sc.Buffer(make([]byte, 0, 256<<10), 64<<20)
		for sc.Scan() {
			line := sc.Bytes()
			if len(line) == 0 {
				continue
			}
			cp := make([]byte, len(line))
			copy(cp, line)
			onLine(cp)
		}
		p.err = cmd.Wait()
		// Report the exit before stop() returns, so callers see final state.
		if onExit != nil {
			onExit(p.err, p.stderr.String())
		}
		close(p.done)
	}()
	return p, nil
}

// writePrivateFile writes data to a new 0600 file in $XDG_RUNTIME_DIR (or
// the temp dir) and returns its path; the caller removes it.
func writePrivateFile(pattern string, data []byte) (string, error) {
	dir := os.Getenv("XDG_RUNTIME_DIR")
	if dir == "" {
		dir = os.TempDir()
	}
	f, err := os.CreateTemp(dir, brand.AppID+"-"+pattern) // mode 0600
	if err != nil {
		return "", err
	}
	if _, err := f.Write(data); err != nil {
		_ = f.Close()
		_ = os.Remove(f.Name())
		return "", err
	}
	if err := f.Close(); err != nil {
		_ = os.Remove(f.Name())
		return "", err
	}
	return f.Name(), nil
}

// cleanEnv drops variables that would make a nested Claude Code refuse to
// start or attach to our own session.
func cleanEnv(env []string) []string {
	out := env[:0:0]
	for _, kv := range env {
		switch {
		case hasPrefix(kv, "CLAUDECODE="), hasPrefix(kv, "CLAUDE_CODE_SESSION_ID="),
			hasPrefix(kv, "CLAUDE_CODE_MESSAGING_"), hasPrefix(kv, "CLAUDE_CODE_CHILD_SESSION="),
			hasPrefix(kv, "CLAUDE_CODE_ENTRYPOINT="), hasPrefix(kv, "CLAUDE_PID="):
			continue
		}
		out = append(out, kv)
	}
	return out
}

func hasPrefix(s, p string) bool { return len(s) >= len(p) && s[:len(p)] == p }

func (p *proc) writeJSON(v any) error {
	data, err := json.Marshal(v)
	if err != nil {
		return err
	}
	p.wmu.Lock()
	defer p.wmu.Unlock()
	if p.closed {
		return io.ErrClosedPipe
	}
	_, err = p.stdin.Write(append(data, '\n'))
	return err
}

// stop closes stdin, then SIGTERM/SIGKILLs the process group.
func (p *proc) stop() {
	p.wmu.Lock()
	if !p.closed {
		p.closed = true
		_ = p.stdin.Close()
	}
	p.wmu.Unlock()
	select {
	case <-p.done:
		return
	case <-time.After(300 * time.Millisecond):
	}
	pid := p.cmd.Process.Pid
	_ = syscall.Kill(-pid, syscall.SIGTERM)
	select {
	case <-p.done:
	case <-time.After(2 * time.Second):
		_ = syscall.Kill(-pid, syscall.SIGKILL)
		<-p.done
	}
}

// tailBuffer keeps the last max bytes written (stderr).
type tailBuffer struct {
	mu  sync.Mutex
	buf []byte
	max int
}

func (t *tailBuffer) Write(b []byte) (int, error) {
	t.mu.Lock()
	defer t.mu.Unlock()
	t.buf = append(t.buf, b...)
	if len(t.buf) > t.max {
		t.buf = t.buf[len(t.buf)-t.max:]
	}
	return len(b), nil
}

func (t *tailBuffer) String() string {
	t.mu.Lock()
	defer t.mu.Unlock()
	return string(t.buf)
}
