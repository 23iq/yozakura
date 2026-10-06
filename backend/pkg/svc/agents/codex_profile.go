package agents

import (
	"encoding/json"
	"errors"
)

// Quick requests disable command tools and connectors and execute under the
// protocol's read-only sandbox. This is a restricted profile, not a promise
// that every model-visible utility tool has been removed.
var codexQuickDisabledFeatures = []string{"shell_tool", "apps", "multi_agent", "multi_agent_v2", "code_mode", "js_repl", "codex_hooks", "hooks", "plugin_hooks", "plugins", "shell_snapshot", "image_generation", "imagegenext", "in_app_browser"}

func codexQuickArgs() []string {
	var args []string
	for _, feature := range codexQuickDisabledFeatures {
		args = append(args, "-c", "features."+feature+"=false")
	}
	args = append(args, "-c", `web_search="disabled"`)

	return args
}
func (c *codexConn) openQuickThread(params map[string]any) error {
	return c.rpc.Call("config/read", map[string]any{"includeLayers": false, "cwd": c.opts.Cwd}, func(raw json.RawMessage, e *rpcError) {
		if e != nil {
			c.quickFailed(e)
			return
		}
		var result struct {
			Config map[string]json.RawMessage `json:"config"`
		}
		if json.Unmarshal(raw, &result) != nil || result.Config == nil {
			c.quickFailed(errors.New("codex cannot report effective quick-request configuration"))
			return
		}
		var features map[string]json.RawMessage
		if json.Unmarshal(result.Config["features"], &features) != nil {
			c.quickFailed(errors.New("codex cannot confirm command/connector restrictions"))
			return
		}
		for _, key := range []string{"shell_tool", "apps"} {
			value, ok := features[key]
			var enabled bool
			if !ok || json.Unmarshal(value, &enabled) != nil || enabled {
				c.quickFailed(errors.New("codex did not apply restricted quick-request feature: " + key))
				return
			}
		}
		config := map[string]any{}
		var servers map[string]json.RawMessage
		if data := result.Config["mcp_servers"]; data != nil {
			if err := json.Unmarshal(data, &servers); err != nil {
				c.quickFailed(err)
				return
			}
		}
		for name := range servers {
			config["mcp_servers."+tomlValue(name)+".enabled"] = false
		}
		// Apply restrictions again at thread scope so project and resume settings
		// cannot restore access. Every inherited MCP server is disabled explicitly.
		for _, key := range codexQuickDisabledFeatures {
			config["features."+key] = false
		}
		config["web_search"] = "disabled"
		params["config"] = config
		if err := c.openThread(params, c.opts.ResumeID); err != nil {
			c.quickFailed(err)
		}
	})
}
func (c *codexConn) quickFailed(err error) {
	c.sink.Emit(Event{Kind: KindError, Message: "Codex quick request: " + err.Error()})
	c.failStart()
}
func codexQuickSandbox() map[string]any {
	return map[string]any{"type": "readOnly", "access": map[string]any{"type": "restricted", "includePlatformDefaults": true, "readableRoots": []string{}}}
}
