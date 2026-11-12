package termrun

import (
	"os"
	"strings"
)

// A chsh during the session (the setup wizard's "make fish my default
// shell") changes the passwd login shell, but the session keeps the $SHELL
// it started with, and every terminal starts $SHELL: without this a new
// terminal would open the old shell until the next login. Only a change
// made during the session counts (ChangedShell).

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

// ChangedShell returns now, the passwd shell at this moment, when a chsh
// replaced start, the passwd shell when the daemon started: both known,
// different, now an absolute path to an executable file. "" otherwise, and
// terminals keep the session's $SHELL: a $SHELL that differs from passwd
// from the start (Hyprland `env = SHELL,...`, environment.d, a login file
// export) is the user's choice, not a stale value.
func ChangedShell(start, now string, executable func(string) bool) string {
	if start == "" || now == start || !strings.HasPrefix(now, "/") || executable == nil || !executable(now) {
		return ""
	}
	return now
}

// IsExecutable reports a regular file with an execute bit (symlinks followed).
func IsExecutable(path string) bool {
	st, err := os.Stat(path)
	return err == nil && st.Mode().IsRegular() && st.Mode().Perm()&0o111 != 0
}

// WithShell returns argv run with SHELL set to shell when shell is an
// absolute path (ChangedShell); argv as it is otherwise. The value travels
// as one argument of env, never as code, and only $SHELL changes: a shell
// named in argv itself still runs.
func WithShell(argv []string, shell string) []string {
	if len(argv) == 0 || !strings.HasPrefix(shell, "/") {
		return argv
	}
	return append([]string{"env", "SHELL=" + shell}, argv...)
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
