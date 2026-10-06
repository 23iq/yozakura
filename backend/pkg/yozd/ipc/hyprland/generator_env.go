package hyprland

import (
	"fmt"
	"strings"

	"yozakura/backend/pkg/yozd/ipc"
)

// GenerateEnv sets session environment variables (`env = NAME,value`).
func (g *Generator) GenerateEnv(env map[string]string) string {
	var b strings.Builder
	for _, e := range ipc.ValidEnv(env) {
		b.WriteString("env = " + e.Name + "," + e.Value + "\n")
	}
	return b.String()
}

// GenerateEnvLua is GenerateEnv for hyprland.lua (hl.env).
func (g *LuaGenerator) GenerateEnvLua(env map[string]string) string {
	var b strings.Builder
	for _, e := range ipc.ValidEnv(env) {
		fmt.Fprintf(&b, "hl.env(%q, %q)\n", e.Name, e.Value)
	}
	return b.String()
}
