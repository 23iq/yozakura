package transfers

import (
	"sync"
	"time"
)

// Process discovery is shared by the /proc based sources (terminal,
// fileOps, packages): one /proc walk serves all of them within maxAge.

const (
	// Discovery tick while nothing interesting runs.
	idleDiscovery = 3 * time.Second
	// Sampling tick while a tracked process exists.
	activeSampling = time.Second
)

var (
	snapMu   sync.Mutex
	snapAt   time.Time
	snapList []Proc
	snapRoot string
)

// SnapshotProcs returns every process (comm + cmdline), reusing a walk that
// is younger than maxAge.
func SnapshotProcs(maxAge time.Duration) []Proc {
	snapMu.Lock()
	defer snapMu.Unlock()
	if snapRoot == procRoot && time.Since(snapAt) < maxAge {
		return snapList
	}
	snapList = ListProcs(nil)
	snapAt = time.Now()
	snapRoot = procRoot
	return snapList
}

// procsNamed filters a snapshot by comm.
func procsNamed(maxAge time.Duration, names map[string]bool) []Proc {
	var out []Proc
	for _, p := range SnapshotProcs(maxAge) {
		if names[p.Comm] {
			out = append(out, p)
		}
	}
	return out
}

// resetProcSnapshot drops the cache (tests that change the fake /proc).
func resetProcSnapshot() {
	snapMu.Lock()
	snapAt = time.Time{}
	snapMu.Unlock()
}
