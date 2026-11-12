package termlook

import (
	"context"
	"os"
	"path/filepath"
	"strconv"
	"strings"
	"syscall"
	"testing"
	"time"
)

// A fastfetch that hangs, run under the login shell (which forks it, and it
// forks a helper): the preview gives up at the budget and nothing of it is
// left running.
func TestRunFetchKillsTheWholeRunOnTimeout(t *testing.T) {
	if _, err := os.Stat("/bin/bash"); err != nil {
		t.Skip("bash not installed")
	}
	dir := t.TempDir()
	pids := filepath.Join(dir, "pids")
	bin := filepath.Join(dir, "fastfetch")
	writeFile(t, bin, "#!/bin/sh\necho $$ >> "+pids+"\nsleep 30 &\necho $! >> "+pids+"\nwait\n")
	if err := os.Chmod(bin, 0o755); err != nil {
		t.Fatal(err)
	}
	oldBudget, oldDelay := fetchBudget, fetchWaitDelay
	fetchBudget, fetchWaitDelay = 300*time.Millisecond, 200*time.Millisecond
	t.Cleanup(func() { fetchBudget, fetchWaitDelay = oldBudget, oldDelay })

	start := time.Now()
	_, err := runFetch(context.Background(), bin, nil, "/bin/bash")
	if d := time.Since(start); d > 2*time.Second {
		t.Errorf("took %v (budget 300ms)", d)
	}
	if err == nil || reasonOf(err) != "timeout" {
		t.Errorf("err %v (%s)", err, reasonOf(err))
	}
	data, _ := os.ReadFile(pids)
	list := strings.Fields(string(data))
	if len(list) != 2 {
		t.Fatalf("pids %q", data)
	}
	deadline := time.Now().Add(2 * time.Second)
	for _, p := range list {
		pid, _ := strconv.Atoi(p)
		for alive(pid) && time.Now().Before(deadline) {
			time.Sleep(20 * time.Millisecond)
		}
		if alive(pid) {
			t.Errorf("process %d left running", pid)
			_ = syscall.Kill(pid, syscall.SIGKILL)
		}
	}
}

// alive: the process exists and is not a zombie waiting for its reaper.
func alive(pid int) bool {
	stat, err := os.ReadFile("/proc/" + strconv.Itoa(pid) + "/stat")
	if err != nil {
		return false
	}
	s := string(stat)
	i := strings.LastIndexByte(s, ')')
	return i < 0 || i+2 >= len(s) || s[i+2] != 'Z'
}
