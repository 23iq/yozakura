package extras

import (
	"regexp"
	"strconv"
	"strings"
)

// Job states reported in Progress.State.
const (
	JobQueued    = "queued"
	JobRunning   = "running"
	JobDone      = "done"
	JobFailed    = "failed"
	JobCancelled = "cancelled"
)

// Failure reasons reported in Progress.Reason.
const (
	ReasonAuthCancelled = "auth_cancelled"
	ReasonNeedsSync     = "needs_sync"
	ReasonNetwork       = "network"
	ReasonDBLocked      = "db_locked"
	ReasonDiskFull      = "disk_full"
	ReasonDependency    = "dependency_failed"
	ReasonError         = "error"
)

// Progress is the state of one job, emitted on every change.
type Progress struct {
	Job     string   `json:"job"`
	Kind    JobKind  `json:"kind"`
	Entries []string `json:"entries"`
	State   string   `json:"state"`
	Percent int      `json:"percent"` // -1 unknown
	Phase   string   `json:"phase"`
	Reason  string   `json:"reason,omitempty"`
	Log     string   `json:"log,omitempty"`
}

const maxPhase = 120

var (
	// pacman/paru: "( 3/12) installing firefox"
	rePacmanStep = regexp.MustCompile(`^\(\s*(\d+)/(\d+)\)\s+(.+?)\s*(?:\[[-#\s]*\]\s*\d+%)?$`)
	// dnf: "  Installing       : firefox-1.0.x86_64      3/12"
	reDnfStep = regexp.MustCompile(`^\s*(Installing|Upgrading|Verifying|Running scriptlet|Downloading)\s*:\s*(\S+).*?\s(\d+)/(\d+)\s*$`)
	// flatpak: "Installing 2/3… 47%" (also "..." and without percent)
	reFlatpakStep = regexp.MustCompile(`^(Installing|Updating|Downloading)\s+(\d+)/(\d+)\S*\s*(?:(\d{1,3})%)?`)
	// npm: "added 12 packages in 3s"
	reNpmAdded = regexp.MustCompile(`^(added|changed) \d+ packages?`)
	// pacman without a tty (noprogressbar): "installing firefox..."
	rePacmanPkg = regexp.MustCompile(`^(installing|upgrading|reinstalling|downgrading) (\S+?)\.\.\.$`)
	// " firefox-131.0-1-x86_64 downloading..."
	rePacmanDl = regexp.MustCompile(`^(\S+) downloading\.\.\.$`)
	// "checking package integrity...", "resolving dependencies..."
	rePacmanPhase = regexp.MustCompile(`^[a-z][a-z ]+\.\.\.$`)
	// ollama: "pulling 8eeb52dfb3bb:  45% ▕████    ▏ 2.1 GB/4.7 GB  12 MB/s"
	reOllamaPull = regexp.MustCompile(`^pulling ([0-9a-f]+):\s+(\d{1,3})%`)
	reANSI       = regexp.MustCompile(`\x1b\[[0-9;?]*[A-Za-z]`)
	rePercent    = regexp.MustCompile(`(\d{1,3})%\s*$`)
)

// privileged reports whether jobs of kind run through pkexec or a
// polkit-aware helper, so "Request dismissed" / "Not authorized" lines mean
// the user declined authentication.
func privileged(k JobKind) bool {
	switch k {
	case KindSystem, KindAUR, KindMultilib, KindUpgrade, KindLogin:
		return true
	}
	return false
}

// ParseLine extracts progress from one output line of a job of the given
// kind. pct is 0-100 or -1 when unknown; ok is false for lines carrying no
// progress information.
func ParseLine(kind JobKind, line string) (pct int, phase string, ok bool) {
	if kind == KindOllama {
		line = reANSI.ReplaceAllString(line, "")
	}
	line = strings.TrimSpace(line)
	if line == "" {
		return -1, "", false
	}
	switch kind {
	case KindSystem, KindAUR, KindMultilib, KindUpgrade:
		if m := rePacmanStep.FindStringSubmatch(line); m != nil {
			return stepPct(m[1], m[2], ""), clip(m[3]), true
		}
		if m := reDnfStep.FindStringSubmatch(line); m != nil {
			return stepPct(m[3], m[4], ""), clip(strings.ToLower(m[1]) + " " + m[2]), true
		}
		if m := rePacmanPkg.FindStringSubmatch(line); m != nil {
			return -1, m[1] + " " + m[2], true
		}
		if m := rePacmanDl.FindStringSubmatch(line); m != nil {
			return -1, clip("downloading " + m[1]), true
		}
		if rePacmanPhase.MatchString(line) {
			return -1, clip(strings.TrimSuffix(line, "...")), true
		}
		if strings.HasPrefix(line, ":: ") {
			return -1, clip(strings.TrimPrefix(line, ":: ")), true
		}
		if m := rePercent.FindStringSubmatch(line); m != nil {
			return pctOf(m[1]), clip(strings.TrimSpace(strings.TrimSuffix(line, m[0]))), true
		}
		return -1, "", false
	case KindFlatpak:
		if m := reFlatpakStep.FindStringSubmatch(line); m != nil {
			return stepPct(m[2], m[3], m[4]), clip(m[1] + " " + m[2] + "/" + m[3]), true
		}
		return -1, "", false
	case KindOllama:
		if m := reOllamaPull.FindStringSubmatch(line); m != nil {
			return pctOf(m[2]), clip("pulling " + m[1]), true
		}
		if strings.HasPrefix(line, "pulling manifest") || strings.HasPrefix(line, "verifying") ||
			strings.HasPrefix(line, "writing manifest") || strings.HasPrefix(line, "success") {
			return -1, clip(line), true
		}
		return -1, "", false
	case KindNpm:
		if reNpmAdded.MatchString(line) {
			return 100, clip(line), true
		}
		return -1, "", false
	}
	// script / shell: the line itself is the phase.
	return -1, clip(line), true
}

// stepPct is the overall percent of step n of total, with sub (0-100) the
// progress inside step n when known.
func stepPct(n, total, sub string) int {
	a, _ := strconv.Atoi(n)
	b, _ := strconv.Atoi(total)
	if b <= 0 || a <= 0 {
		return -1
	}
	s := 0
	if sub != "" {
		s = pctOf(sub)
	}
	p := ((a-1)*100 + s) / b
	if sub == "" {
		p = a * 100 / b
	}
	return min(p, 100)
}

func pctOf(s string) int {
	v, _ := strconv.Atoi(s)
	return min(max(v, 0), 100)
}

func clip(s string) string {
	s = strings.TrimSpace(s)
	if r := []rune(s); len(r) > maxPhase {
		return string(r[:maxPhase]) + "…"
	}
	return s
}

// pkgPercent derives a job percent from a piped pacman phase
// ("installing <pkg>") and the job's package list: the share of the job's
// packages before <pkg>. -1 when the package is not one of them.
func pkgPercent(phase string, pkgs []string) int {
	_, name, ok := strings.Cut(phase, " ")
	if !ok || len(pkgs) == 0 {
		return -1
	}
	for i, p := range pkgs {
		if p == name {
			return i * 100 / len(pkgs)
		}
	}
	return -1
}

// lineReason maps an output line to a failure reason ("" when it tells
// nothing).
func lineReason(line string) string {
	l := strings.ToLower(line)
	switch {
	case strings.Contains(l, "request dismissed"), strings.Contains(l, "not authorized"):
		return ReasonAuthCancelled
	case strings.Contains(l, "target not found"):
		return ReasonNeedsSync
	case strings.Contains(l, "could not resolve host"), strings.Contains(l, "failed to connect"),
		strings.Contains(l, "failed retrieving file"), strings.Contains(l, "network is unreachable"),
		strings.Contains(l, "temporary failure in name resolution"):
		return ReasonNetwork
	case strings.Contains(l, "unable to lock database"):
		return ReasonDBLocked
	case strings.Contains(l, "no space left on device"):
		return ReasonDiskFull
	}
	return ""
}

// exitReason maps a failed command to a reason: a reason seen in its output
// wins (pkexec dismissal lines printed under paru/yay included); otherwise
// pkexec exits 126 when the dialog is dismissed and 127 when not authorized.
func exitReason(argv []string, code int, seen string) string {
	if seen != "" {
		return seen
	}
	if len(argv) > 0 && argv[0] == "pkexec" && (code == 126 || code == 127) {
		return ReasonAuthCancelled
	}
	return ReasonError
}
