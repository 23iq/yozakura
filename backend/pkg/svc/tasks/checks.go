package tasks

import (
	"bufio"
	"context"
	"encoding/json"
	"errors"
	"os"
	"os/exec"
	"path/filepath"
	"regexp"
	"strings"
	"syscall"
	"time"
)

// DetectCheck suggests a check command for a project: a Makefile `check`
// (or `test`) target, package.json's test script, `go test ./...` for a Go
// module, `cargo test` for a Rust crate. "" when nothing is recognised.
func DetectCheck(dir string) string {
	if mk := firstExisting(dir, "Makefile", "makefile", "GNUmakefile"); mk != "" {
		for _, target := range []string{"check", "test"} {
			if hasMakeTarget(mk, target) {
				return "make " + target
			}
		}
	}
	if data, err := os.ReadFile(filepath.Join(dir, "package.json")); err == nil {
		var pkg struct {
			Scripts map[string]string `json:"scripts"`
		}
		if json.Unmarshal(data, &pkg) == nil {
			if t := pkg.Scripts["test"]; t != "" && !strings.Contains(t, "no test specified") {
				return packageRunner(dir) + " test"
			}
		}
	}
	if fileExists(filepath.Join(dir, "go.mod")) {
		return "go test ./..."
	}
	if fileExists(filepath.Join(dir, "Cargo.toml")) {
		return "cargo test"
	}
	if fileExists(filepath.Join(dir, "pyproject.toml")) && fileExists(filepath.Join(dir, "tests")) {
		return "pytest"
	}
	return ""
}

func packageRunner(dir string) string {
	switch {
	case fileExists(filepath.Join(dir, "pnpm-lock.yaml")):
		return "pnpm"
	case fileExists(filepath.Join(dir, "yarn.lock")):
		return "yarn"
	case fileExists(filepath.Join(dir, "bun.lockb")), fileExists(filepath.Join(dir, "bun.lock")):
		return "bun"
	}
	return "npm"
}

func firstExisting(dir string, names ...string) string {
	for _, n := range names {
		if p := filepath.Join(dir, n); fileExists(p) {
			return p
		}
	}
	return ""
}

func fileExists(p string) bool { _, err := os.Stat(p); return err == nil }

var makeTarget = regexp.MustCompile(`^([A-Za-z0-9_.\- ]+):([^=]|$)`)

func hasMakeTarget(path, target string) bool {
	f, err := os.Open(path)
	if err != nil {
		return false
	}
	defer f.Close()
	sc := bufio.NewScanner(f)
	for sc.Scan() {
		m := makeTarget.FindStringSubmatch(sc.Text())
		if m == nil {
			continue
		}
		for _, t := range strings.Fields(m[1]) {
			if t == target {
				return true
			}
		}
	}
	return false
}

// checkTailBytes is how much check output is kept (and sent to the agent).
const checkTailBytes = 6 << 10

// runCheck runs the project check command in dir. The command is the
// user's own configured command line, so it goes through `sh -c` as a
// fixed script argument (no other data is interpolated into it).
func runCheck(dir, command string, timeout time.Duration, now func() time.Time) CheckRun {
	start := now()
	cr := CheckRun{Command: command, At: start.UnixMilli()}
	if strings.TrimSpace(command) == "" {
		cr.Status = CheckSkipped
		return cr
	}
	ctx, cancel := context.WithTimeout(context.Background(), timeout)
	defer cancel()
	cmd := exec.CommandContext(ctx, "sh", "-c", command)
	cmd.Dir = dir
	cmd.Env = append(os.Environ(), "CI=1", "NO_COLOR=1")
	cmd.SysProcAttr = &syscall.SysProcAttr{Setpgid: true}
	cmd.Cancel = func() error { return syscall.Kill(-cmd.Process.Pid, syscall.SIGKILL) }
	cmd.WaitDelay = 5 * time.Second
	buf := &tail{max: checkTailBytes}
	cmd.Stdout, cmd.Stderr = buf, buf
	err := cmd.Run()
	cr.DurationMs = now().Sub(start).Milliseconds()
	cr.OutputTail = strings.ToValidUTF8(buf.String(), "")
	var exitErr *exec.ExitError
	switch {
	case ctx.Err() == context.DeadlineExceeded:
		cr.Status, cr.ExitCode = CheckTimeout, -1
	case err == nil:
		cr.Status = CheckPass
	case errors.As(err, &exitErr):
		cr.Status, cr.ExitCode = CheckFail, exitErr.ExitCode()
	default:
		cr.Status, cr.ExitCode = CheckFail, -1
		cr.OutputTail += "\n" + err.Error()
	}
	return cr
}

// tail keeps the last max bytes written.
type tail struct {
	buf []byte
	max int
}

func (t *tail) Write(p []byte) (int, error) {
	t.buf = append(t.buf, p...)
	if len(t.buf) > t.max {
		t.buf = t.buf[len(t.buf)-t.max:]
	}
	return len(p), nil
}

func (t *tail) String() string { return string(t.buf) }
