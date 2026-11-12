// Package procscan finds and signals processes by their exact identity
// (owner, process name, argv elements) read from /proc, instead of a
// `pkill -f` regex over the joined command line, which also matches an
// editor or a path that merely contains the pattern.
package procscan

import (
	"bytes"
	"os"
	"path/filepath"
	"strconv"
	"strings"
	"syscall"
)

// Proc is one process as /proc shows it.
type Proc struct {
	PID int
	UID int
	// Comm is the kernel's process name (/proc/<pid>/comm, max 15 bytes).
	Comm string
	// Argv is the NUL-split command line (empty for kernel threads).
	Argv []string
}

// Arg0Base is the base name of argv[0] ("" without argv).
func (p Proc) Arg0Base() string {
	if len(p.Argv) == 0 {
		return ""
	}
	return filepath.Base(p.Argv[0])
}

// HasArg reports whether one of argv[1:] equals arg exactly.
func (p Proc) HasArg(arg string) bool {
	for _, a := range p.argsAfter0() {
		if a == arg {
			return true
		}
	}
	return false
}

func (p Proc) argsAfter0() []string {
	if len(p.Argv) < 2 {
		return nil
	}
	return p.Argv[1:]
}

// List reads every process under root (normally "/proc"). Processes that
// exit while being read, or whose files cannot be read, are skipped.
func List(root string) []Proc {
	entries, err := os.ReadDir(root)
	if err != nil {
		return nil
	}
	var out []Proc
	for _, e := range entries {
		pid, err := strconv.Atoi(e.Name())
		if err != nil || pid <= 0 {
			continue
		}
		dir := filepath.Join(root, e.Name())
		info, err := os.Stat(dir)
		if err != nil {
			continue
		}
		st, ok := info.Sys().(*syscall.Stat_t)
		if !ok {
			continue
		}
		p := Proc{PID: pid, UID: int(st.Uid)}
		if data, err := os.ReadFile(filepath.Join(dir, "comm")); err == nil {
			p.Comm = strings.TrimRight(string(data), "\n")
		}
		if data, err := os.ReadFile(filepath.Join(dir, "cmdline")); err == nil && len(data) > 0 {
			data = bytes.TrimRight(data, "\x00")
			for _, a := range bytes.Split(data, []byte{0}) {
				p.Argv = append(p.Argv, string(a))
			}
		}
		out = append(out, p)
	}
	return out
}

// Killer signals the processes of one user that a matcher selects.
type Killer struct {
	Root string // "/proc"
	UID  int    // only processes owned by this uid are signalled
	Self int    // never signalled
	Kill func(pid int, sig syscall.Signal) error
}

// Default signals the current user's processes, never this one.
func Default() Killer {
	return Killer{Root: "/proc", UID: os.Getuid(), Self: os.Getpid(), Kill: syscall.Kill}
}

// Signal sends sig to every process of k.UID (except k.Self) that match
// selects and returns their pids.
func (k Killer) Signal(match func(Proc) bool, sig syscall.Signal) []int {
	var hit []int
	for _, p := range List(k.Root) {
		if p.UID != k.UID || p.PID == k.Self || !match(p) {
			continue
		}
		if k.Kill(p.PID, sig) == nil {
			hit = append(hit, p.PID)
		}
	}
	return hit
}

// NamedAny reports whether the process is one of names by exact name: its
// kernel name, the base of argv[0], or a Nix wrapper's ".<name>-wrapped".
func NamedAny(p Proc, names ...string) bool {
	base := p.Arg0Base()
	for _, n := range names {
		if n == "" {
			continue
		}
		wrapped := "." + n + "-wrapped"
		if base == n || base == wrapped || p.Comm == commOf(n) || p.Comm == commOf(wrapped) {
			return true
		}
	}
	return false
}

// commOf is name as the kernel stores it in comm: cut to 15 bytes.
func commOf(name string) string {
	if len(name) > 15 {
		return name[:15]
	}
	return name
}
