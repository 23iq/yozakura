package routines

import "strings"

// CommandConfigKeys are the config keys whose value the shell or the
// backend runs as a command line (or as the program it starts): an AI
// writing one of them can run anything. A "*" segment matches any key.
// modules/services/ai/Permissions.js keeps the same list
// (tests/ai-confirm-tools.test.cjs enforces it).
var CommandConfigKeys = []string{
	"general.terminalCommand",
	"system.idle.general.lock_cmd",
	"system.idle.general.before_sleep_cmd",
	"system.idle.general.after_sleep_cmd",
	"system.idle.listeners",
	"specials.workspaces",
	"ai.agents.*.binary",
	"ai.agents.*.extraArgs",
}

// ConfirmCall reports whether a call of the built-in tool `tool` (bare
// name) with args must always ask the user: a confirm tool, or a call that
// can make the shell run a command line or bind keys. A config_set of a
// command-valued key (CommandConfigKeys, or an enclosing object whose value
// sets one), special_app_add with a command, and special_add /
// special_update with a toggle or send key combo. Every other config_set
// or special edit keeps the normal policy.
func ConfirmCall(tool string, args map[string]any) bool {
	if ConfirmTools[tool] {
		return true
	}
	switch tool {
	case "config_set":
		domain, _ := args["domain"].(string)
		key, _ := args["key"].(string)
		return commandConfigKey(fullConfigKey(domain, key), args["value"])
	case "special_app_add":
		cmd, _ := args["command"].(string)
		return strings.TrimSpace(cmd) != ""
	case "special_add", "special_update":
		_, toggle := args["toggle"]
		_, send := args["send"]
		return toggle || send
	}
	return false
}

// fullConfigKey is the qualified key config_set writes (catalog.NormalizeKey
// plus the optional domain).
func fullConfigKey(domain, key string) string {
	key = strings.TrimSpace(key)
	key = strings.ReplaceAll(key, "[", ".")
	key = strings.ReplaceAll(key, "]", "")
	key = strings.Trim(key, ".")
	switch {
	case domain == "":
		return key
	case key == "":
		return domain
	}
	return domain + "." + key
}

// commandConfigKey reports whether setting key to value writes a command:
// key is (or lies inside) a command key, or encloses one and value carries
// it.
func commandConfigKey(key string, value any) bool {
	if key == "" {
		return false
	}
	ks := strings.Split(key, ".")
	for _, pattern := range CommandConfigKeys {
		ps := strings.Split(pattern, ".")
		n := min(len(ks), len(ps))
		match := true
		for i := 0; i < n && match; i++ {
			match = ps[i] == "*" || ps[i] == ks[i]
		}
		if !match {
			continue
		}
		if len(ks) >= len(ps) || carries(value, ps[len(ks):]) {
			return true
		}
	}
	return false
}

// carries reports whether value (an object being merged into an enclosing
// key) sets the member at path. A value that is not an object, other than
// null (reset to the default), counts: it is not understood.
func carries(value any, path []string) bool {
	if len(path) == 0 {
		return true
	}
	switch v := value.(type) {
	case nil:
		return false
	case map[string]any:
		if path[0] == "*" {
			for _, child := range v {
				if carries(child, path[1:]) {
					return true
				}
			}
			return false
		}
		child, ok := v[path[0]]
		return ok && carries(child, path[1:])
	}
	return true
}
