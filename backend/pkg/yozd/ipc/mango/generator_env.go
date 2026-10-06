package mango

import (
	"strings"

	"yozakura/backend/pkg/yozd/ipc"
)

// GenerateEnv sets session environment variables (`env=NAME,value`).
func (g *Generator) GenerateEnv(env map[string]string) string {
	var b strings.Builder
	for _, e := range ipc.ValidEnv(env) {
		b.WriteString("env=" + e.Name + "," + e.Value + "\n")
	}
	return b.String()
}
