package agents

import "encoding/json"

// OpenCode runs through the generic ACP adapter (`opencode acp`). OpenCode
// allows every tool by default, so permission prompts are switched on via
// OPENCODE_CONFIG_CONTENT (merged over the user's config); the Yozakura
// policy then auto-approves reads and asks for the rest (YOLO approves all).
func init() {
	Register(acpAdapter{spec: acpSpec{
		id:     "opencode",
		label:  "OpenCode",
		binary: "opencode",
		notes:  "Uses your OpenCode providers via `opencode acp`. Edits, shell and web fetches ask for permission; resume via session/load.",
		args:   func(StartOptions) []string { return []string{"acp"} },
		env: func(o StartOptions) []string {
			perm := map[string]any{"edit": "ask", "bash": "ask", "webfetch": "ask"}
			cfg := map[string]any{"permission": perm}
			data, _ := json.Marshal(cfg)
			return []string{"OPENCODE_CONFIG_CONTENT=" + string(data)}
		},
	}})
}
