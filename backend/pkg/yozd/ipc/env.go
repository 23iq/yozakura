package ipc

import (
	"regexp"
	"sort"
)

// EnvVar is one session environment variable of the generated config.
type EnvVar struct{ Name, Value string }

var (
	envNameRe  = regexp.MustCompile(`^[A-Za-z_][A-Za-z0-9_]*$`)
	envValueRe = regexp.MustCompile(`^[A-Za-z0-9_.,:/@+=-]*$`)
)

// ValidEnv is env sorted by name, without entries every compositor syntax
// could not carry verbatim (names other than identifiers, values with
// spaces, quotes, backslashes or newlines).
func ValidEnv(env map[string]string) []EnvVar {
	var out []EnvVar
	for k, v := range env {
		if envNameRe.MatchString(k) && envValueRe.MatchString(v) {
			out = append(out, EnvVar{k, v})
		}
	}
	sort.Slice(out, func(i, j int) bool { return out[i].Name < out[j].Name })
	return out
}
