package server

import (
	"strings"
)

// Hyprland reload planning.
//
// A full `hyprctl reload` re-parses every config file and re-applies every
// monitor rule; when the shell rewrote the generated config on every slider
// step, Hyprland reloaded several times a second and the output churn
// crashed Qt Wayland clients. The generated config is therefore diffed per
// section against what was applied last: appearance and keyboard values are
// pushed live (hyprlang `keyword` or Lua `eval`) and the file is written
// without a reload; anything a runtime command cannot express (binds, rules,
// monitors, env, startup, animations, a removed key) still reloads.

// Section names of the generated Hyprland config, in file order.
const (
	secEnv        = "env"
	secOutputs    = "outputs"
	secKeyboard   = "keyboard"
	secStartup    = "startup"
	secAppearance = "appearance"
	secAnimations = "animations"
	secBinds      = "binds"
	secRules      = "rules"
	secLayers     = "layers"
)

var sectionOrder = []string{
	secEnv, secOutputs, secKeyboard, secStartup, secAppearance,
	secAnimations, secBinds, secRules, secLayers,
}

// liveSections can be applied to a running Hyprland without a reload. The
// animation block is left out on purpose: the shell's motion profile is
// applied after it (entry overlay), and pushing yozd's default curves live
// would override it until the next reload.
var liveSections = map[string]bool{secAppearance: true, secKeyboard: true}

// section is one part of the generated config in both languages.
type section struct {
	conf string // hyprlang text
	lua  string // Lua text ("" when no Lua file is generated)
}

type configSections map[string]section

// applyPlan says how a regenerated config reaches Hyprland.
type applyPlan struct {
	Write   bool     // write the generated file(s)
	Reload  bool     // run a full config reload
	Live    []string // sections to apply at runtime (only when !Reload)
	Changed []string // changed sections, in file order
}

// planApply decides between nothing, a live update and a full reload.
// prev is nil when the previously applied sections are unknown (first
// apply since start, or the files on disk were changed by someone else);
// diskSame reports that the files already hold exactly the new content.
func planApply(prev, next configSections, diskSame bool) applyPlan {
	if diskSame {
		return applyPlan{}
	}
	if prev == nil {
		return applyPlan{Write: true, Reload: true, Changed: append([]string(nil), sectionOrder...)}
	}
	plan := applyPlan{Write: true}
	for _, name := range sectionOrder {
		if prev[name] != next[name] {
			plan.Changed = append(plan.Changed, name)
		}
	}
	for _, name := range plan.Changed {
		if !liveSections[name] || removesKeys(prev[name].conf, next[name].conf) {
			plan.Reload = true
			return plan
		}
	}
	plan.Live = append([]string(nil), plan.Changed...)
	return plan
}

// hyprlangEntry is one flattened `category:sub:key = value` assignment.
type hyprlangEntry struct{ key, value string }

// flattenHyprlang turns nested hyprlang categories into keyword paths
// (`general { col.active_border = x }` -> `general:col.active_border`).
func flattenHyprlang(text string) []hyprlangEntry {
	var stack []string
	var out []hyprlangEntry
	for _, raw := range strings.Split(text, "\n") {
		line := strings.TrimSpace(raw)
		switch {
		case line == "" || strings.HasPrefix(line, "#"):
		case strings.HasSuffix(line, "{"):
			stack = append(stack, strings.TrimSpace(strings.TrimSuffix(line, "{")))
		case line == "}":
			if len(stack) > 0 {
				stack = stack[:len(stack)-1]
			}
		default:
			i := strings.Index(line, "=")
			if i < 0 {
				continue
			}
			key := strings.TrimSpace(line[:i])
			path := append(append([]string(nil), stack...), key)
			out = append(out, hyprlangEntry{strings.Join(path, ":"), strings.TrimSpace(line[i+1:])})
		}
	}
	return out
}

// removesKeys reports whether next drops a key prev set: a runtime
// command cannot unset an option, only a reload restores its default.
func removesKeys(prev, next string) bool {
	have := map[string]bool{}
	for _, e := range flattenHyprlang(next) {
		have[e.key] = true
	}
	for _, e := range flattenHyprlang(prev) {
		if !have[e.key] {
			return true
		}
	}
	return false
}

// keywordCommands returns the `keyword` commands that move a running
// hyprlang Hyprland from prev to next, or ok=false when a value cannot go
// through a batch request (batch commands are separated by ';') or a changed key
// is in overridden (the user sets it again after the generated file: a
// keyword would beat their value until the next reload).
func keywordCommands(prev, next string, overridden map[string]bool) (cmds []string, ok bool) {
	old := map[string]string{}
	for _, e := range flattenHyprlang(prev) {
		old[e.key] = e.value
	}
	for _, e := range flattenHyprlang(next) {
		if v, seen := old[e.key]; seen && v == e.value {
			continue
		}
		if strings.Contains(e.value, ";") || overridden[e.key] {
			return nil, false
		}
		cmds = append(cmds, "keyword "+e.key+" "+e.value)
	}
	return cmds, true
}

// luaEvalCommand returns the `eval` command that runs a generated Lua
// chunk on one line, or ok=false when it cannot go through a batch
// request. Generated string literals never span lines, so joining the
// trimmed lines with spaces keeps their content.
func luaEvalCommand(chunk string) (cmd string, ok bool) {
	var parts []string
	for _, line := range strings.Split(chunk, "\n") {
		if t := strings.TrimSpace(line); t != "" && !strings.HasPrefix(t, "--") {
			parts = append(parts, t)
		}
	}
	if len(parts) == 0 {
		return "", true
	}
	joined := strings.Join(parts, " ")
	if strings.Contains(joined, ";") {
		return "", false
	}
	return "eval " + joined, true
}

// liveCommands builds the runtime commands for the live sections of plan.
// ok=false means a section cannot be applied live and Hyprland must reload.
func liveCommands(prev, next configSections, live []string, lua bool, overridden map[string]bool) (cmds []string, ok bool) {
	for _, name := range live {
		if lua {
			cmd, good := luaEvalCommand(next[name].lua)
			if !good {
				return nil, false
			}
			if cmd != "" {
				cmds = append(cmds, cmd)
			}
			continue
		}
		kw, good := keywordCommands(prev[name].conf, next[name].conf, overridden)
		if !good {
			return nil, false
		}
		cmds = append(cmds, kw...)
	}
	return cmds, true
}
