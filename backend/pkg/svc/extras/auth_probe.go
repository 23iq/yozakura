package extras

import (
	"bytes"
	"context"
	"os"
	"path/filepath"
	"strconv"
	"time"
)

// authRunner is a Runner that also tells, while a command runs, whether it
// waits for the user's password (the queue shows it as Progress.Auth, so
// a full-screen surface can step aside for the polkit dialog).
type authRunner interface {
	RunAuth(ctx context.Context, argv []string, env []string, line func(string), auth func(bool)) (int, error)
}

// authPoll is how often a privileged job's processes are looked at.
var authPoll = 400 * time.Millisecond

// procRoot is the proc filesystem the probe reads (tests point it at a fake).
var procRoot = "/proc"

// RunAuth is Run that reports through auth whether a process of the
// command's group is pkexec: pkexec replaces itself with the program once
// the user is authorized, so a pkexec still running is at the password
// prompt. auth gets every change and false when the command ends.
func (r ExecRunner) RunAuth(ctx context.Context, argv []string, env []string, line func(string), auth func(bool)) (int, error) {
	stop := make(chan struct{})
	done := make(chan struct{})
	watching := false // set before run returns: started runs in its goroutine
	started := func(pgid int) {
		watching = true
		go func() {
			defer close(done)
			watchAuth(pgid, stop, auth)
		}()
	}
	code, err := r.run(ctx, argv, env, line, started)
	close(stop)
	if watching {
		<-done
	}
	return code, err
}

// watchAuth polls the process group until stop, reporting changes.
func watchAuth(pgid int, stop <-chan struct{}, auth func(bool)) {
	waiting := false
	t := time.NewTicker(authPoll)
	defer t.Stop()
	for {
		if now := pkexecWaiting(procRoot, pgid); now != waiting {
			waiting = now
			auth(now)
		}
		select {
		case <-stop:
			if waiting {
				auth(false)
			}
			return
		case <-t.C:
		}
	}
}

// pkexecWaiting reports a process named pkexec in process group pgid.
func pkexecWaiting(proc string, pgid int) bool {
	entries, err := os.ReadDir(proc)
	if err != nil {
		return false
	}
	for _, e := range entries {
		if _, err := strconv.Atoi(e.Name()); err != nil {
			continue
		}
		data, err := os.ReadFile(filepath.Join(proc, e.Name(), "stat"))
		if err != nil {
			continue
		}
		if comm, grp, ok := parseStat(data); ok && grp == pgid && comm == "pkexec" {
			return true
		}
	}
	return false
}

// parseStat reads the command name and the process group of a
// /proc/<pid>/stat line: "pid (comm) state ppid pgrp ..."; comm may itself
// contain spaces and parentheses, so it ends at the last ")".
func parseStat(data []byte) (comm string, pgrp int, ok bool) {
	open := bytes.IndexByte(data, '(')
	end := bytes.LastIndexByte(data, ')')
	if open < 0 || end < open {
		return "", 0, false
	}
	f := bytes.Fields(data[end+1:])
	if len(f) < 3 {
		return "", 0, false
	}
	n, err := strconv.Atoi(string(f[2]))
	if err != nil {
		return "", 0, false
	}
	return string(data[open+1 : end]), n, true
}
