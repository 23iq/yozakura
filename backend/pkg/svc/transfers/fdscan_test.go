package transfers

import (
	"math"
	"path/filepath"
	"testing"
	"time"
)

func TestListFDsFiltersAndParsesFdinfo(t *testing.T) {
	fp := newFakeProc(t)
	dir := t.TempDir()
	out := filepath.Join(dir, "out.bin")
	writeSize(t, out, 10)
	fp.add(42, "curl", []string{"curl", "-O", "x"}, map[int]fakeFD{
		0: {target: "/dev/pts/3", flags: flagsRW},
		1: {target: "pipe:[1234]", flags: flagsWrite},
		2: {target: "socket:[99]", flags: flagsRW},
		3: {target: out, flags: flagsWrite, pos: 10},
		4: {target: "/proc/42/status", flags: flagsRead},
	})
	fds := ListFDs(42, true)
	if len(fds) != 1 || fds[0].Target != out || fds[0].Pos != 10 || !fds[0].Writable() || fds[0].ReadOnly() {
		t.Fatalf("unexpected fds %+v", fds)
	}
	if !OwnedByMe(42) {
		t.Fatal("fake proc dir should be owned by the test user")
	}
	if got := FileOwners([]string{out}); got[out] != "curl" {
		t.Fatalf("FileOwners = %v", got)
	}
}

func TestIsFileTarget(t *testing.T) {
	for target, want := range map[string]bool{
		"/home/u/a.iso":     true,
		"/dev/null":         false,
		"anon_inode:[x]":    false,
		"/proc/1/mem":       false,
		"/sys/kernel/x":     false,
		"/run/user/1000/ws": false,
	} {
		if IsFileTarget(target) != want {
			t.Errorf("IsFileTarget(%q) != %v", target, want)
		}
	}
}

func TestRateMeterSmoothsAndDetectsStalls(t *testing.T) {
	var m RateMeter
	t0 := time.Unix(100, 0)
	if r := m.Observe(0, t0); r != -1 {
		t.Fatalf("first sample rate %v", r)
	}
	r := m.Observe(10<<20, t0.Add(time.Second))
	if math.Abs(r-float64(10<<20)) > 1 {
		t.Fatalf("second sample should be the instant rate, got %v", r)
	}
	// rate halves: the EMA moves towards it, not jumps
	r = m.Observe(15<<20, t0.Add(2*time.Second))
	if r <= float64(5<<20) || r >= float64(10<<20) {
		t.Fatalf("EMA out of range: %v", r)
	}
	if m.Stalled(t0.Add(3*time.Second), 5*time.Second) {
		t.Fatal("not stalled yet")
	}
	m.Observe(15<<20, t0.Add(9*time.Second))
	if !m.Stalled(t0.Add(9*time.Second), 5*time.Second) {
		t.Fatal("should be stalled after 7s without growth")
	}
	if m.Started() != t0 {
		t.Fatal("Started")
	}
}
