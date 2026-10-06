package routines

import (
	"bytes"
	"context"
	"fmt"
	"os"
	"os/exec"
	"strings"
	"syscall"
	"time"

	"yozakura/backend/pkg/brand"
	"yozakura/backend/pkg/paths"
)

// settle is how long a step's command may run before the routine moves on
// (it keeps running: apps launched by a step must outlive it).
const settle = 10 * time.Second

// ExecArgv runs argv from $HOME in its own session. It waits for the
// command up to `settle`; a command still running then is left alone and
// counts as started.
func ExecArgv(ctx context.Context, argv []string) (string, error) {
	if len(argv) == 0 {
		return "", fmt.Errorf("empty command")
	}
	name := argv[0]
	if name == brand.Daemon {
		name = paths.DaemonBinary()
	}
	cmd := exec.Command(name, argv[1:]...)
	if home, err := os.UserHomeDir(); err == nil {
		cmd.Dir = home
	}
	cmd.SysProcAttr = &syscall.SysProcAttr{Setsid: true}
	var out bytes.Buffer
	cmd.Stdout = &out
	cmd.Stderr = &out
	if err := cmd.Start(); err != nil {
		return "", err
	}
	done := make(chan error, 1)
	go func() { done <- cmd.Wait() }()
	t := time.NewTimer(settle)
	defer t.Stop()
	select {
	case err := <-done:
		text := strings.TrimSpace(out.String())
		// The daemon CLI prints errors and still exits 0.
		if err == nil && strings.HasPrefix(text, "Error:") {
			err = fmt.Errorf("%s", strings.TrimSpace(strings.TrimPrefix(text, "Error:")))
		}
		if err != nil && text != "" {
			return text, fmt.Errorf("%v: %s", err, firstLine(text))
		}
		return text, err
	case <-t.C:
		return "started", nil
	case <-ctx.Done():
		return "", ctx.Err()
	}
}
