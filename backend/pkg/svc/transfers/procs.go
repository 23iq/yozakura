package transfers

import (
	"os"
	"path/filepath"
	"strconv"
	"strings"
)

// Proc is a light /proc snapshot entry.
type Proc struct {
	PID  int
	Comm string   // /proc/<pid>/comm
	Args []string // /proc/<pid>/cmdline
}

// procRoot is replaced by tests with a fake tree.
var procRoot = "/proc"

// ListProcs reads comm (and cmdline when keep(comm) is true) for every
// process. Cheap: one small read per process, cmdline only for matches.
func ListProcs(keep func(comm string) bool) []Proc {
	entries, err := os.ReadDir(procRoot)
	if err != nil {
		return nil
	}
	var out []Proc
	for _, e := range entries {
		pid, err := strconv.Atoi(e.Name())
		if err != nil {
			continue
		}
		comm, err := os.ReadFile(filepath.Join(procRoot, e.Name(), "comm"))
		if err != nil {
			continue
		}
		c := strings.TrimSpace(string(comm))
		if keep != nil && !keep(c) {
			continue
		}
		p := Proc{PID: pid, Comm: c}
		if raw, err := os.ReadFile(filepath.Join(procRoot, e.Name(), "cmdline")); err == nil {
			for _, a := range strings.Split(strings.TrimRight(string(raw), "\x00"), "\x00") {
				if a != "" {
					p.Args = append(p.Args, a)
				}
			}
		}
		out = append(out, p)
	}
	return out
}

// ProcRunning reports whether a process with one of these comm names exists.
func ProcRunning(names ...string) bool {
	set := map[string]bool{}
	for _, n := range names {
		set[n] = true
	}
	return len(ListProcs(func(c string) bool { return set[c] })) > 0
}

// ProcPath joins a path below the (possibly faked) /proc root.
func ProcPath(parts ...string) string {
	return filepath.Join(append([]string{procRoot}, parts...)...)
}
