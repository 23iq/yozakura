// Package gotune sets the Go runtime's memory and CPU policy of the
// long-running processes (the shell daemon, the compositor daemon). Short
// CLI invocations exit before a GC policy matters and keep Go's defaults.
//
// Every setting yields to its environment variable: with GOMEMLIMIT, GOGC
// or GOMAXPROCS set, the runtime has already applied the user's value and
// gotune leaves that one alone.
package gotune

import (
	"runtime"
	"runtime/debug"
)

// Policy is the runtime policy of one process.
type Policy struct {
	// MemLimit is the soft memory limit in bytes (runtime/debug.SetMemoryLimit).
	MemLimit int64
	// GCPercent is the heap growth that triggers a collection (GOGC).
	GCPercent int
	// MaxProcs caps GOMAXPROCS; a machine with fewer CPUs keeps its count.
	// 0 leaves GOMAXPROCS alone.
	MaxProcs int
}

// The values are deliberately loose: they trim the idle footprint of a
// process that runs for the whole session, never its ability to work.
//
//   - The memory limit is soft. It only makes the collector run (and return
//     memory to the OS) more eagerly as the heap nears it; allocations past
//     it still succeed, and the runtime caps GC work at about half the CPU,
//     so even a live heap above the limit slows the daemon, never stops it.
//     512 MiB is several times the daemon's working set, with room for its
//     largest transient payloads (multi-monitor screenshots and clipboard
//     images are tens of MiB each, MCP tool results less).
//   - GOGC 50 lets the heap grow by half its live size between collections
//     instead of doubling: a lower peak footprint for twice the (tiny) GC
//     work of a mostly idle, small-heap daemon.
//   - The compositor daemon is I/O bound (compositor events, small JSON
//     replies): two Ps are plenty and keep the runtime from starting a GC
//     worker per core on large machines.
//   - The shell daemon keeps every CPU: it encodes screenshots in process,
//     one PNG band per P (internal/screenshot), so a cap would make a
//     capture slower on any machine with more CPUs than the cap. Idle Ps
//     cost no CPU; the idle footprint is trimmed by the two settings above.
var (
	// Daemon is the policy of the shell daemon (`yozakura` without args).
	Daemon = Policy{MemLimit: 512 << 20, GCPercent: 50}
	// CompositorDaemon is the policy of `yozd daemon`: compositor events
	// and small JSON replies only.
	CompositorDaemon = Policy{MemLimit: 256 << 20, GCPercent: 50, MaxProcs: 2}
)

// Settings is what Plan decided; zero fields are left at the runtime's value.
type Settings struct {
	MemLimit  int64
	GCPercent int
	MaxProcs  int
}

// Plan works out which settings to apply given the environment (getenv)
// and the current GOMAXPROCS (procs).
func Plan(p Policy, getenv func(string) string, procs int) Settings {
	var s Settings
	if getenv("GOMEMLIMIT") == "" && p.MemLimit > 0 {
		s.MemLimit = p.MemLimit
	}
	if getenv("GOGC") == "" && p.GCPercent > 0 {
		s.GCPercent = p.GCPercent
	}
	if getenv("GOMAXPROCS") == "" && p.MaxProcs > 0 && procs > p.MaxProcs {
		s.MaxProcs = p.MaxProcs
	}
	return s
}

// Apply plans p and applies it to the runtime; it returns what it set.
func Apply(p Policy, getenv func(string) string) Settings {
	s := Plan(p, getenv, runtime.GOMAXPROCS(0))
	if s.MemLimit > 0 {
		debug.SetMemoryLimit(s.MemLimit)
	}
	if s.GCPercent > 0 {
		debug.SetGCPercent(s.GCPercent)
	}
	if s.MaxProcs > 0 {
		runtime.GOMAXPROCS(s.MaxProcs)
	}
	return s
}
