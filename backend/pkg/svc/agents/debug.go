package agents

import (
	"bufio"
	"os"
	"regexp"
	"strings"
)

// DebugInfo is the raw view of a session for the debug pane: where its
// event log lives, the last raw log lines, the agent's stderr tail and the
// launch command line (secrets redacted). Argv and Stderr are only known
// while the agent process runs; after an exit the stderr tail is in the
// last "exited" error event of the log.
type DebugInfo struct {
	Session  string   `json:"session"`
	Agent    string   `json:"agent"`
	Cwd      string   `json:"cwd"`
	Status   string   `json:"status"`
	Running  bool     `json:"running"`
	LogPath  string   `json:"logPath"`
	LogTail  []string `json:"logTail"`
	Stderr   string   `json:"stderr"`
	Argv     []string `json:"argv"`
	AgentSID string   `json:"agentSessionId"`
}

// procHolder is implemented by every adapter connection backed by a proc.
type procHolder interface{ procRef() *proc }

func (c *claudeConn) procRef() *proc { return c.p }
func (c *codexConn) procRef() *proc  { return c.p }
func (c *acpConn) procRef() *proc    { return c.p }

// Debug returns the debug view of a session with up to lines raw log lines.
func (m *Manager) Debug(id string, lines int) (DebugInfo, error) {
	s, err := m.get(id)
	if err != nil {
		return DebugInfo{}, err
	}
	if lines <= 0 {
		lines = 50
	}
	m.mu.Lock()
	s.flushLocked()
	info := DebugInfo{Session: id, Agent: s.meta.Agent, Cwd: s.meta.Cwd, Status: s.meta.Status,
		LogPath: m.logPath(id), AgentSID: s.meta.AgentSessionID, LogTail: []string{}, Argv: []string{}}
	conn := s.conn
	m.mu.Unlock()
	if ph, ok := conn.(procHolder); ok && ph.procRef() != nil {
		p := ph.procRef()
		info.Running = true
		info.Stderr = redactText(p.stderr.String())
		info.Argv = RedactArgv(p.cmd.Args)
	}
	info.LogTail = tailLines(info.LogPath, lines)
	return info, nil
}

func tailLines(path string, n int) []string {
	out := []string{}
	f, err := os.Open(path)
	if err != nil {
		return out
	}
	defer f.Close()
	sc := bufio.NewScanner(f)
	sc.Buffer(make([]byte, 0, 256<<10), 64<<20)
	for sc.Scan() {
		out = append(out, redactText(sc.Text()))
		if len(out) > n {
			out = out[1:]
		}
	}
	return out
}

var secretName = regexp.MustCompile(`(?i)(token|secret|passw|api[-_]?key|auth|bearer|credential)`)

// RedactArgv hides values of secret-looking flags and KEY=VALUE pairs.
func RedactArgv(argv []string) []string {
	out := make([]string, len(argv))
	hideNext := false
	for i, a := range argv {
		switch {
		case hideNext:
			out[i] = "<redacted>"
			hideNext = false
		case strings.HasPrefix(a, "-") && secretName.MatchString(a):
			if k, _, ok := strings.Cut(a, "="); ok {
				out[i] = k + "=<redacted>"
			} else {
				out[i] = a
				hideNext = true
			}
		default:
			if k, _, ok := strings.Cut(a, "="); ok && !strings.HasPrefix(a, "-") && secretName.MatchString(k) {
				out[i] = k + "=<redacted>"
			} else {
				out[i] = redactText(a)
			}
		}
	}
	return out
}

var secretValue = regexp.MustCompile(`(?i)((?:token|secret|password|api[-_]?key|authorization)["']?\s*[:=]\s*["']?(?:bearer\s+)?)([^\s"',}]+)`)

// redactText masks "token: xyz"-style values inside free text.
func redactText(s string) string { return secretValue.ReplaceAllString(s, "${1}<redacted>") }
