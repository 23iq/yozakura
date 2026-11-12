package termrun

import (
	"os"
	"os/user"
	"strings"
)

// A chsh during the session (the setup wizard's "make fish my default
// shell") changes the passwd login shell, but the session keeps the $SHELL
// it started with, and every terminal starts $SHELL: without this a new
// terminal would open the old shell until the next login.

// PasswdShell returns the shell field of name's entry in passwd data ("").
func PasswdShell(passwd []byte, name string) string {
	if name == "" {
		return ""
	}
	for _, line := range strings.Split(string(passwd), "\n") {
		f := strings.Split(line, ":")
		if len(f) >= 7 && f[0] == name {
			return strings.TrimSpace(f[6])
		}
	}
	return ""
}

// LoginShell is the current user's shell in /etc/passwd ("" when unknown).
func LoginShell() string {
	u, err := user.Current()
	if err != nil {
		return ""
	}
	data, err := os.ReadFile("/etc/passwd")
	if err != nil {
		return ""
	}
	return PasswdShell(data, u.Username)
}

// WithLoginShell returns argv run with SHELL set to login when login is an
// absolute path other than current (the session's $SHELL); argv as it is
// otherwise. The value travels as one argument of env, never as code, and
// only $SHELL changes: a shell named in argv itself still runs.
func WithLoginShell(argv []string, login, current string) []string {
	if len(argv) == 0 || !strings.HasPrefix(login, "/") || login == current {
		return argv
	}
	return append([]string{"env", "SHELL=" + login}, argv...)
}

// IsTerminalEntry reports a desktop entry whose [Desktop Entry] group lists
// the TerminalEmulator category.
func IsTerminalEntry(content string) bool {
	group := ""
	for _, line := range strings.Split(content, "\n") {
		t := strings.TrimSpace(line)
		if strings.HasPrefix(t, "[") && strings.HasSuffix(t, "]") {
			group = t
			continue
		}
		if group != "[Desktop Entry]" || !strings.HasPrefix(t, "Categories") {
			continue
		}
		k, v, ok := strings.Cut(t, "=")
		if !ok || strings.TrimSpace(k) != "Categories" {
			continue
		}
		for _, c := range strings.Split(v, ";") {
			if strings.TrimSpace(c) == "TerminalEmulator" {
				return true
			}
		}
	}
	return false
}
