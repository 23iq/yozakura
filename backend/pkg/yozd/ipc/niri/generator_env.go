package niri

import (
	"strings"

	"yozakura/backend/pkg/yozd/ipc"
)

// GenerateEnv sets session environment variables (`environment { }`).
func (g *Generator) GenerateEnv(env map[string]string) string {
	vars := ipc.ValidEnv(env)
	if len(vars) == 0 {
		return ""
	}
	var b strings.Builder
	b.WriteString("environment {\n")
	for _, e := range vars {
		b.WriteString("    " + e.Name + " " + kdlQuote(e.Value) + "\n")
	}
	b.WriteString("}\n")
	return b.String()
}
