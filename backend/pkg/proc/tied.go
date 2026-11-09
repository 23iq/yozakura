package proc

import (
	"os/exec"
	"runtime"
	"sync"
	"syscall"
)

// StartTied starts cmd with Pdeathsig=SIGTERM so the child dies with the
// backend, keeping any other SysProcAttr fields (Setpgid, ...) it already has.
//
// Linux delivers Pdeathsig when the *thread* that forked the child exits, not
// when the process does (prctl(2) PR_SET_PDEATHSIG; golang/go#27505). A plain
// cmd.Start runs on whatever OS thread the calling goroutine happens to be on,
// and the Go runtime terminates a thread when a goroutine that locked it
// (runtime.LockOSThread) returns without unlocking: a long-lived agent or MCP
// server spawned on such a thread would get SIGTERM at a random moment while
// the backend keeps running. StartTied therefore forks every child from one
// spawner goroutine that locks its thread and never returns, so the "parent
// thread" lives exactly as long as the process.
func StartTied(cmd *exec.Cmd) error {
	if cmd.SysProcAttr == nil {
		cmd.SysProcAttr = &syscall.SysProcAttr{}
	}
	cmd.SysProcAttr.Pdeathsig = syscall.SIGTERM
	spawnerOnce.Do(func() { go spawnLoop() })
	done := make(chan error, 1)
	spawnReqs <- spawnReq{cmd: cmd, done: done}
	return <-done
}

type spawnReq struct {
	cmd  *exec.Cmd
	done chan error
}

var (
	spawnerOnce sync.Once
	spawnReqs   = make(chan spawnReq)
)

// spawnLoop owns the spawner thread for the life of the process: it locks
// the thread and never unlocks or returns.
func spawnLoop() {
	runtime.LockOSThread()
	for r := range spawnReqs {
		r.done <- r.cmd.Start()
	}
}
