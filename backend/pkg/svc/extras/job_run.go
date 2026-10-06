package extras

import (
	"context"
	"errors"
	"fmt"
	"io"
	"os"
	"path/filepath"
	"strings"
	"time"
)

// execute runs the job's commands (Pre, then Argv) and returns its final
// state and failure reason. Output goes to <logDir>/<job id>.log.
func (q *Queue) execute(ctx context.Context, j *qjob) (state, reason string) {
	logw := q.openLog(j)
	defer logw.Close()

	q.mu.Lock()
	j.prog.State = JobRunning
	p := j.prog
	q.mu.Unlock()
	q.send(p)

	argv := append([]string(nil), j.Argv...)
	if j.ScriptURL != "" {
		path, err := q.fetch(ctx, j.ScriptURL)
		if err != nil {
			fmt.Fprintf(logw, "download %s: %v\n", j.ScriptURL, err)
			if q.wasCancelled(j) {
				return JobCancelled, ""
			}
			if errors.Is(err, ErrScriptRejected) {
				return JobFailed, ReasonError
			}
			return JobFailed, ReasonNetwork
		}
		defer os.Remove(path)
		for i, a := range argv {
			if a == ScriptFile {
				argv[i] = path
			}
		}
	}
	cmds := append(append([][]string(nil), j.Pre...), argv)
	for _, cmd := range cmds {
		if q.wasCancelled(j) { // cancelled before this command started
			return JobCancelled, ""
		}
		fmt.Fprintf(logw, "$ %s\n", strings.Join(cmd, " "))
		seen := ""
		code, err := q.run.Run(ctx, cmd, jobEnv, func(line string) {
			fmt.Fprintln(logw, line)
			r := lineReason(line)
			if r == ReasonAuthCancelled && !privileged(j.Kind) {
				r = "" // e.g. an npm 401 "not authorized" is a plain error
			}
			if r != "" && (seen == "" || r == ReasonAuthCancelled) {
				seen = r
			}
			q.progress(j, line)
		})
		if code == 0 && err == nil {
			continue // finished despite a late cancel: keep the result
		}
		if q.wasCancelled(j) {
			return JobCancelled, ""
		}
		if code == 0 {
			fmt.Fprintf(logw, "error: %v\n", err)
			return JobFailed, ReasonError
		}
		fmt.Fprintf(logw, "exit status %d\n", code)
		r := exitReason(cmd, code, seen)
		if r == ReasonAuthCancelled {
			return JobCancelled, r
		}
		return JobFailed, r
	}
	return JobDone, ""
}

func (q *Queue) wasCancelled(j *qjob) bool {
	q.mu.Lock()
	defer q.mu.Unlock()
	return j.cancelled
}

// progress updates the job from one output line and emits on change.
// Percent is monotonic within a job.
func (q *Queue) progress(j *qjob, line string) {
	pct, phase, ok := ParseLine(j.Kind, line)
	if !ok {
		return
	}
	if pct < 0 {
		pct = pkgPercent(phase, j.Pkgs)
	}
	q.mu.Lock()
	changed := false
	if pct > j.prog.Percent { // never goes back (e.g. pacman hook counters)
		j.prog.Percent, changed = pct, true
	}
	if phase != "" && phase != j.prog.Phase {
		j.prog.Phase, changed = phase, true
	}
	p := j.prog
	q.mu.Unlock()
	if changed {
		q.send(p)
	}
}

type nopCloser struct{ io.Writer }

func (nopCloser) Close() error { return nil }

// openLog creates the job log; logging failures never fail the job.
func (q *Queue) openLog(j *qjob) io.WriteCloser {
	if err := os.MkdirAll(q.logDir, 0o700); err != nil {
		return nopCloser{io.Discard}
	}
	path := filepath.Join(q.logDir, j.ID+".log")
	f, err := os.OpenFile(path, os.O_CREATE|os.O_WRONLY|os.O_TRUNC, 0o600)
	if err != nil {
		return nopCloser{io.Discard}
	}
	q.mu.Lock()
	j.prog.Log = path
	q.mu.Unlock()
	fmt.Fprintf(f, "# %s %s entries=%s\n", time.Now().Format(time.RFC3339), j.Kind, strings.Join(j.Entries, ","))
	return f
}
