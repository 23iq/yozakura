// Package proc is the single place the backend spawns child processes.
//
// Every command is context-bound (exec.CommandContext) so a service shutdown
// or a timeout kills it instead of leaking it. Arguments are always argv,
// never a string built into a script.
package proc

import (
	"bytes"
	"context"
	"fmt"
	"io"
	"os/exec"
	"strings"
	"time"
)

// DefaultTimeout bounds one-shot commands that were not given a deadline.
const DefaultTimeout = 15 * time.Second

// Options tunes RunWith. The zero value means: DefaultTimeout, no stdin,
// inherited dir and environment.
type Options struct {
	// Timeout overrides DefaultTimeout. Negative disables the implicit
	// timeout (the context alone governs the lifetime).
	Timeout time.Duration
	Stdin   io.Reader
	Dir     string
	Env     []string
	// Combined returns stdout+stderr interleaved as the output.
	Combined bool
}

// Error is returned when a command fails. It carries the captured stderr.
type Error struct {
	Name   string
	Args   []string
	Err    error
	Stderr string
}

func (e *Error) Error() string {
	msg := fmt.Sprintf("%s: %v", e.Name, e.Err)
	if s := strings.TrimSpace(e.Stderr); s != "" {
		msg += ": " + s
	}
	return msg
}

func (e *Error) Unwrap() error { return e.Err }

// Run runs name with args and returns its stdout. Stderr is captured into
// the returned error. DefaultTimeout applies unless ctx ends sooner.
func Run(ctx context.Context, name string, args ...string) ([]byte, error) {
	return RunWith(ctx, Options{}, name, args...)
}

// RunWith is Run with Options.
func RunWith(ctx context.Context, o Options, name string, args ...string) ([]byte, error) {
	if ctx == nil {
		ctx = context.Background()
	}
	if o.Timeout >= 0 {
		d := o.Timeout
		if d == 0 {
			d = DefaultTimeout
		}
		var cancel context.CancelFunc
		ctx, cancel = context.WithTimeout(ctx, d)
		defer cancel()
	}
	cmd := exec.CommandContext(ctx, name, args...)
	cmd.Stdin = o.Stdin
	cmd.Dir = o.Dir
	if o.Env != nil {
		cmd.Env = o.Env
	}
	var out, errb bytes.Buffer
	cmd.Stdout = &out
	if o.Combined {
		cmd.Stderr = &out
	} else {
		cmd.Stderr = &errb
	}
	if err := cmd.Run(); err != nil {
		if cerr := ctx.Err(); cerr != nil {
			err = fmt.Errorf("%w (%v)", err, cerr)
		}
		e := &Error{Name: name, Args: args, Err: err, Stderr: errb.String()}
		if o.Combined {
			e.Stderr = out.String()
		}
		return out.Bytes(), e
	}
	return out.Bytes(), nil
}

// Do runs name with args and returns only the error (output discarded).
func Do(ctx context.Context, name string, args ...string) error {
	_, err := Run(ctx, name, args...)
	return err
}

// Combined runs name with args and returns stdout and stderr interleaved.
func Combined(ctx context.Context, name string, args ...string) ([]byte, error) {
	return RunWith(ctx, Options{Combined: true}, name, args...)
}

// Command builds a context-bound command without starting it, for callers
// that wire pipes, env or stdin first (long-running children, streams).
func Command(ctx context.Context, name string, args ...string) *exec.Cmd {
	if ctx == nil {
		ctx = context.Background()
	}
	return exec.CommandContext(ctx, name, args...)
}

// Start starts a long-running child bound to ctx (killed when ctx ends). The
// caller owns Wait.
func Start(ctx context.Context, name string, args ...string) (*exec.Cmd, error) {
	cmd := Command(ctx, name, args...)
	if err := cmd.Start(); err != nil {
		return nil, &Error{Name: name, Args: args, Err: err}
	}
	return cmd, nil
}
