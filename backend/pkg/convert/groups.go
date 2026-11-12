package convert

import (
	"os"
	"path/filepath"
	"strconv"
	"strings"
	"sync"
	"syscall"
)

// Every step runs in its own process group. The backend only gets a death
// signal into the direct child, so helpers it forks (soffice.bin under the
// soffice script) could outlive a killed daemon. Each running group is
// recorded as a file <dir>/<owner pid>-<pgid> holding the program name; a
// later start kills the groups of owners that are gone whose processes
// still carry that name (the daemon and a `convert` CLI share the dir).

var (
	groupMu  sync.Mutex
	groupDir string
)

// TrackGroupsIn sets the directory running process groups are recorded in
// ("" = not recorded).
func TrackGroupsIn(dir string) {
	groupMu.Lock()
	groupDir = dir
	groupMu.Unlock()
	if dir != "" {
		_ = os.MkdirAll(dir, 0o700)
	}
}

func trackGroup(pgid int, prog string) func() {
	groupMu.Lock()
	dir := groupDir
	groupMu.Unlock()
	if dir == "" {
		return func() {}
	}
	f := filepath.Join(dir, strconv.Itoa(os.Getpid())+"-"+strconv.Itoa(pgid))
	_ = os.WriteFile(f, []byte(prog), 0o600)
	return func() { _ = os.Remove(f) }
}

// KillStaleGroups kills the groups recorded in dir by processes that are
// gone, when their members still run a program of the recorded name, and
// forgets those records.
func KillStaleGroups(dir string) int {
	return killStaleGroups(dir, ownerAlive)
}

func ownerAlive(pid int) bool {
	if pid == os.Getpid() {
		return true
	}
	err := syscall.Kill(pid, 0)
	return err == nil || err == syscall.EPERM
}

func killStaleGroups(dir string, alive func(int) bool) int {
	entries, err := os.ReadDir(dir)
	if err != nil {
		return 0
	}
	killed := 0
	for _, e := range entries {
		ownerStr, pgidStr, ok := strings.Cut(e.Name(), "-")
		owner, err1 := strconv.Atoi(ownerStr)
		pgid, err2 := strconv.Atoi(pgidStr)
		path := filepath.Join(dir, e.Name())
		if ok && err1 == nil && alive(owner) {
			continue
		}
		prog, _ := os.ReadFile(path)
		_ = os.Remove(path)
		if !ok || err1 != nil || err2 != nil || pgid <= 1 || pgid == syscall.Getpgrp() {
			continue
		}
		if groupRuns(pgid, strings.TrimSpace(string(prog))) {
			_ = syscall.Kill(-pgid, syscall.SIGKILL)
			killed++
		}
	}
	return killed
}

// groupRuns: some process of group pgid has a command name sharing the
// recorded program's first letters (comm is cut at 15 bytes; soffice ->
// soffice.bin, oosplash).
func groupRuns(pgid int, prog string) bool {
	procs, _ := filepath.Glob("/proc/[0-9]*/stat")
	for _, p := range procs {
		b, err := os.ReadFile(p)
		if err != nil {
			continue
		}
		s := string(b)
		lp, rp := strings.IndexByte(s, '('), strings.LastIndexByte(s, ')')
		if lp < 0 || rp < lp {
			continue
		}
		comm := s[lp+1 : rp]
		f := strings.Fields(s[rp+1:])
		if len(f) < 3 || f[2] != strconv.Itoa(pgid) {
			continue
		}
		if sameProgram(comm, prog) {
			return true
		}
	}
	return false
}

func sameProgram(comm, prog string) bool {
	if prog == "" {
		return false
	}
	if strings.HasPrefix(comm, prog) || strings.HasPrefix(prog, comm) {
		return true
	}
	// the LibreOffice launcher hands over to these
	return (prog == "soffice" || prog == "libreoffice") && (strings.HasPrefix(comm, "soffice") || comm == "oosplash")
}
