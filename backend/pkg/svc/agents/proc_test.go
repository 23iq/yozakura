package agents

import (
	"syscall"
	"testing"
)

func TestAgentProcessesDieWithTheDaemon(t *testing.T) {
	p, err := startProc("sleep", []string{"5"}, t.TempDir(), nil, func([]byte) {}, nil)
	if err != nil {
		t.Fatal(err)
	}
	defer p.stop()
	if a := p.cmd.SysProcAttr; a == nil || !a.Setpgid || a.Pdeathsig != syscall.SIGTERM {
		t.Errorf("SysProcAttr = %+v, want Setpgid and Pdeathsig=SIGTERM", a)
	}
}
