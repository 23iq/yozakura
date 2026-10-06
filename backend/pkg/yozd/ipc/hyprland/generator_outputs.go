package hyprland

import (
	"strings"

	"yozakura/backend/pkg/yozd/ipc"
)

// GenerateOutputs renders one `monitor = ...` line per valid monitor. An
// empty list yields "" (no fallback line: the compositor default applies).
func (g *Generator) GenerateOutputs(monitors []ipc.OutputConfig) string {
	var b strings.Builder
	for _, m := range ipc.ValidOutputs(monitors) {
		b.WriteString("monitor = " + hyprMonitorConf(m) + "\n")
	}
	return b.String()
}

// GenerateKeyboard renders the keyboard part of the `input {}` block.
func (g *Generator) GenerateKeyboard(keyboard *ipc.KeyboardSettings) string {
	k := ipc.ValidKeyboard(keyboard)
	if k == nil {
		return ""
	}
	var b strings.Builder
	b.WriteString("input {\n")
	for _, e := range hyprKeyboardEntries(*k) {
		b.WriteString("    " + e.key + " = " + e.value + "\n")
	}
	b.WriteString("}\n")
	return b.String()
}

// GenerateOutputsLua renders one hl.monitor call per valid monitor.
func (g *LuaGenerator) GenerateOutputsLua(monitors []ipc.OutputConfig) string {
	var b strings.Builder
	for _, m := range ipc.ValidOutputs(monitors) {
		b.WriteString(hyprMonitorLua(m) + "\n")
	}
	return b.String()
}

// GenerateKeyboardLua renders the keyboard hl.config call.
func (g *LuaGenerator) GenerateKeyboardLua(keyboard *ipc.KeyboardSettings) string {
	k := ipc.ValidKeyboard(keyboard)
	if k == nil {
		return ""
	}
	return hyprKeyboardLua(*k) + "\n"
}
