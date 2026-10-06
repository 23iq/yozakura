package compositor

import (
	"fmt"
	"sort"
	"strings"
)

// writeEnv renders [env] (session environment variables), sorted by name.
func writeEnv(b *strings.Builder, env map[string]string) {
	if len(env) == 0 {
		return
	}
	names := make([]string, 0, len(env))
	for k := range env {
		names = append(names, k)
	}
	sort.Strings(names)
	b.WriteString("\n[env]\n")
	for _, k := range names {
		fmt.Fprintf(b, "%s = %q\n", k, env[k])
	}
}
