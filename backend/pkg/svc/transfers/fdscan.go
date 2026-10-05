package transfers

import (
	"bufio"
	"os"
	"strconv"
	"strings"
	"syscall"
	"time"
)

// Shared helpers for /proc based sources (browserDownloads, terminal,
// fileOps, packages): open-file scanning and transfer-rate smoothing.

// FD is one open file descriptor of a process.
type FD struct {
	Num    int
	Target string // resolved path, " (deleted)" stripped
	Flags  int    // open(2) flags from fdinfo
	Pos    int64  // file offset from fdinfo
}

// Writable reports whether the descriptor was opened for writing.
func (f FD) Writable() bool {
	acc := f.Flags & syscall.O_ACCMODE
	return acc == syscall.O_WRONLY || acc == syscall.O_RDWR
}

// ReadOnly reports whether the descriptor was opened read-only.
func (f FD) ReadOnly() bool { return f.Flags&syscall.O_ACCMODE == syscall.O_RDONLY }

// IsFileTarget reports whether an fd link target is a regular path worth
// tracking: not a pipe/socket/anon inode, not under /dev, /proc or /sys.
func IsFileTarget(target string) bool {
	if !strings.HasPrefix(target, "/") {
		return false
	}
	for _, p := range []string{"/dev/", "/proc/", "/sys/", "/run/user/", "/memfd:"} {
		if strings.HasPrefix(target, p) {
			return false
		}
	}
	return true
}

// ListFDs lists a process's file descriptors that point to regular paths.
// withInfo also reads fdinfo (flags, pos); that is one extra read per fd.
func ListFDs(pid int, withInfo bool) []FD {
	dir := ProcPath(strconv.Itoa(pid), "fd")
	entries, err := os.ReadDir(dir)
	if err != nil {
		return nil
	}
	var out []FD
	for _, e := range entries {
		n, err := strconv.Atoi(e.Name())
		if err != nil {
			continue
		}
		target, err := os.Readlink(dir + "/" + e.Name())
		if err != nil {
			continue
		}
		target = strings.TrimSuffix(target, " (deleted)")
		if !IsFileTarget(target) {
			continue
		}
		fd := FD{Num: n, Target: target}
		if withInfo {
			fd.Pos, fd.Flags = readFDInfo(pid, n)
		}
		out = append(out, fd)
	}
	return out
}

// readFDInfo parses /proc/<pid>/fdinfo/<fd>: "pos:\t123" and "flags:\t0100001"
// (octal).
func readFDInfo(pid, fd int) (pos int64, flags int) {
	f, err := os.Open(ProcPath(strconv.Itoa(pid), "fdinfo", strconv.Itoa(fd)))
	if err != nil {
		return 0, 0
	}
	defer f.Close()
	sc := bufio.NewScanner(f)
	for sc.Scan() {
		k, v, ok := strings.Cut(sc.Text(), ":")
		if !ok {
			continue
		}
		v = strings.TrimSpace(v)
		switch k {
		case "pos":
			pos, _ = strconv.ParseInt(v, 10, 64)
		case "flags":
			x, _ := strconv.ParseInt(v, 8, 64)
			flags = int(x)
		}
	}
	return pos, flags
}

// OwnedByMe reports whether /proc/<pid> belongs to the current user.
func OwnedByMe(pid int) bool {
	st, err := os.Stat(ProcPath(strconv.Itoa(pid)))
	if err != nil {
		return false
	}
	sys, ok := st.Sys().(*syscall.Stat_t)
	return ok && int(sys.Uid) == os.Getuid()
}

// FileOwners maps each of paths to the comm of a process holding it open.
// It walks every process's fd table, so call it only when paths is
// non-empty (a handful of times per download).
func FileOwners(paths []string) map[string]string {
	out := map[string]string{}
	if len(paths) == 0 {
		return out
	}
	want := map[string]bool{}
	for _, p := range paths {
		want[p] = true
	}
	for _, p := range ListProcs(nil) {
		for _, fd := range ListFDs(p.PID, false) {
			if want[fd.Target] && out[fd.Target] == "" {
				out[fd.Target] = p.Comm
			}
		}
		if len(out) == len(want) {
			break
		}
	}
	return out
}

// FileSize returns the size of path, or -1.
func FileSize(path string) int64 {
	st, err := os.Stat(path)
	if err != nil || !st.Mode().IsRegular() {
		return -1
	}
	return st.Size()
}

// rateWindow is the smoothing time constant of RateMeter.
const rateWindow = 3 * time.Second

// RateMeter turns successive byte counters into a smoothed rate (EMA with a
// ~3s time constant) and remembers when the counter last moved.
type RateMeter struct {
	last    int64
	at      time.Time
	rate    float64
	set     bool
	moved   time.Time
	started time.Time
}

// Observe records value at now and returns the smoothed bytes/s (-1 until
// two samples exist).
func (m *RateMeter) Observe(value int64, now time.Time) float64 {
	if !m.set {
		m.set = true
		m.last, m.at, m.moved, m.started = value, now, now, now
		m.rate = -1
		return -1
	}
	dt := now.Sub(m.at).Seconds()
	if dt <= 0 {
		return m.rate
	}
	if value != m.last {
		m.moved = now
	}
	inst := float64(value-m.last) / dt
	if inst < 0 {
		inst = 0 // counter reset (truncated file)
	}
	if m.rate < 0 {
		m.rate = inst
	} else {
		alpha := dt / (rateWindow.Seconds() + dt)
		m.rate += alpha * (inst - m.rate)
	}
	m.last, m.at = value, now
	return m.rate
}

// Rate is the last smoothed rate (-1 unknown).
func (m *RateMeter) Rate() float64 {
	if !m.set {
		return -1
	}
	return m.rate
}

// Stalled reports whether the counter has not moved for d.
func (m *RateMeter) Stalled(now time.Time, d time.Duration) bool {
	return m.set && now.Sub(m.moved) > d
}

// Started is when the meter saw its first sample.
func (m *RateMeter) Started() time.Time { return m.started }
