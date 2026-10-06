// Package envclean removes duplicate and empty entries from colon-separated
// path variables (XDG_DATA_DIRS, PATH, ...). A compositor config that
// prepends to such a variable on every reload can grow it to thousands of
// entries, which makes consumers like Quickshell's DesktopEntries rescan the
// same directories over and over.
package envclean

import (
	"fmt"
	"log"
	"os"
	"strings"
)

// Vars lists the colon-separated path variables that are normalised.
var Vars = []string{
	"XDG_DATA_DIRS",
	"XDG_CONFIG_DIRS",
	"PATH",
	"QML_IMPORT_PATH",
	"QML2_IMPORT_PATH",
}

// Dedupe drops empty entries and duplicates from a colon-separated list,
// keeping the first occurrence of each. "dir" and "dir/" count as the same
// entry; the first spelling is kept as written. It returns the cleaned value
// and the number of entries in the input (empty ones included).
func Dedupe(value string) (string, int) {
	parts := strings.Split(value, ":")
	seen := make(map[string]struct{}, len(parts))
	kept := make([]string, 0, len(parts))
	for _, p := range parts {
		if p == "" {
			continue
		}
		key := strings.TrimRight(p, "/")
		if key == "" {
			key = "/"
		}
		if _, dup := seen[key]; dup {
			continue
		}
		seen[key] = struct{}{}
		kept = append(kept, p)
	}
	return strings.Join(kept, ":"), len(parts)
}

// Clean returns a copy of env (KEY=VALUE entries) with every variable in
// Vars normalised. Other entries are untouched. logf, when non-nil, gets one
// line per variable that changed.
func Clean(env []string, logf func(format string, args ...any)) []string {
	out := make([]string, len(env))
	for i, kv := range env {
		out[i] = kv
		k, v, ok := strings.Cut(kv, "=")
		if !ok || !isPathVar(k) {
			continue
		}
		cleaned, n := Dedupe(v)
		if cleaned == v {
			continue
		}
		out[i] = k + "=" + cleaned
		if logf != nil {
			logf("env: %s had %d entries, kept %d", k, n, count(cleaned))
		}
	}
	return out
}

// CleanProcess normalises the current process environment in place so every
// later exec inherits the clean values. It is silent: it returns one message
// per variable that changed and the caller decides whether to log them
// (one-shot CLI subcommands must not print anything).
func CleanProcess() []string {
	var msgs []string
	for _, k := range Vars {
		v, ok := os.LookupEnv(k)
		if !ok {
			continue
		}
		cleaned, n := Dedupe(v)
		if cleaned == v {
			continue
		}
		if err := os.Setenv(k, cleaned); err != nil {
			continue
		}
		msgs = append(msgs, fmt.Sprintf("env: %s had %d entries, kept %d", k, n, count(cleaned)))
	}
	return msgs
}

// ChildEnv returns the current environment, cleaned, for a supervised child.
func ChildEnv() []string {
	return Clean(os.Environ(), func(f string, a ...any) { log.Printf(f, a...) })
}

func isPathVar(k string) bool {
	for _, v := range Vars {
		if v == k {
			return true
		}
	}
	return false
}

func count(v string) int {
	if v == "" {
		return 0
	}
	return strings.Count(v, ":") + 1
}
