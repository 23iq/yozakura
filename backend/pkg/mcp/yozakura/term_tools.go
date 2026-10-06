package yozakura

import (
	"context"
	"encoding/json"
	"fmt"
	"regexp"
	"strings"

	"yozakura/backend/pkg/mcp"
)

// Terminal prompt tools drive the daemon's "term" service: Starship or
// oh-my-posh prompt presets drawn in the shell palette for fish.

var termPresetID = regexp.MustCompile(`^[a-z0-9-]+$`)

func termTools(d Deps) []mcp.ToolDef {
	return []mcp.ToolDef{
		define("term_presets", "List terminal prompt presets",
			`List the fish prompt presets (id, name, number of lines, whether they need a Nerd Font) and the state of the terminal setup: whether the prompt is enabled, which engine and preset are set, whether starship / oh-my-posh and fish are installed, whether fish is the login shell, and whether the user's own config.fish already sets a prompt. Call it before term_set.`,
			noArgs, toolOpts{readOnly: true}, d.termPresets),
		define("term_set", "Set the terminal prompt",
			`Turn the fish prompt on with a preset (see term_presets for ids), optionally choosing the engine ("starship" or "ohmyposh"), or turn it off with enabled false. It writes the terminal config, the engine config and a fish conf.d file (config.fish is never touched); colors follow the theme from then on. The result lists what is still missing: install the engine or fish with extras_install (ids starship, oh-my-posh, fish) and tell the user if their config.fish sets another prompt.`,
			`{"type":"object","properties":{"preset":{"type":"string","description":"Preset id from term_presets."},"engine":{"type":"string","enum":["starship","ohmyposh"]},"enabled":{"type":"boolean","default":true,"description":"false turns the prompt off and removes the fish file."}},"additionalProperties":false}`,
			toolOpts{}, d.termSet),
	}
}

func (d Deps) termPresets(_ context.Context, _ json.RawMessage) (*mcp.CallToolResult, error) {
	raw, err := d.call("term.presets", nil)
	if err != nil {
		return nil, err
	}
	var presets []map[string]any
	if err := json.Unmarshal(raw, &presets); err != nil {
		return nil, fmt.Errorf("term.presets: %v", err)
	}
	raw, err = d.call("term.status", nil)
	if err != nil {
		return nil, err
	}
	var st map[string]any
	if err := json.Unmarshal(raw, &st); err != nil {
		return nil, fmt.Errorf("term.status: %v", err)
	}
	out := map[string]any{"presets": presets, "status": st}
	if _, store, err := d.catalog(); err == nil {
		for _, k := range []string{"prompt", "engine"} {
			if v, _, err := store.Get("terminal." + k); err == nil {
				out[k] = v
			}
		}
	}
	return mcp.JSONResult(out), nil
}

func (d Deps) termSet(_ context.Context, args json.RawMessage) (*mcp.CallToolResult, error) {
	var a struct {
		Preset  string
		Engine  string
		Enabled *bool
	}
	if err := decode(args, &a); err != nil {
		return nil, err
	}
	enabled := a.Enabled == nil || *a.Enabled
	if enabled && a.Preset == "" {
		return nil, fmt.Errorf("preset is required (see term_presets)")
	}
	if a.Preset != "" && !termPresetID.MatchString(a.Preset) {
		return nil, fmt.Errorf("invalid preset id %q", a.Preset)
	}
	if a.Engine != "" && a.Engine != "starship" && a.Engine != "ohmyposh" {
		return nil, fmt.Errorf("unknown engine %q (starship or ohmyposh)", a.Engine)
	}
	if enabled {
		if err := d.termCheckPreset(a.Preset); err != nil {
			return nil, err
		}
	}
	_, store, err := d.catalog()
	if err != nil {
		return nil, err
	}
	set := func(key string, v any) error {
		_, err := store.Set("terminal."+key, v, false)
		return err
	}
	if a.Engine != "" {
		if err := set("engine", a.Engine); err != nil {
			return nil, err
		}
	}
	if a.Preset != "" {
		if err := set("prompt", a.Preset); err != nil {
			return nil, err
		}
	}
	if err := set("enabled", enabled); err != nil {
		return nil, err
	}
	raw, err := d.call("term.apply", nil)
	if err != nil {
		return nil, fmt.Errorf("saved, but writing the prompt failed: %v", err)
	}
	var st map[string]any
	if err := json.Unmarshal(raw, &st); err != nil {
		return nil, fmt.Errorf("term.apply: %v", err)
	}
	return mcp.JSONResult(map[string]any{"ok": true, "enabled": enabled, "status": st, "todo": termTodo(st, enabled)}), nil
}

func (d Deps) termCheckPreset(id string) error {
	raw, err := d.call("term.presets", nil)
	if err != nil {
		return err
	}
	var presets []struct{ ID string }
	if err := json.Unmarshal(raw, &presets); err != nil {
		return fmt.Errorf("term.presets: %v", err)
	}
	ids := make([]string, 0, len(presets))
	for _, p := range presets {
		if p.ID == id {
			return nil
		}
		ids = append(ids, p.ID)
	}
	return fmt.Errorf("unknown preset %q (presets: %s)", id, strings.Join(ids, ", "))
}

// termTodo lists what the user still needs for the prompt to show.
func termTodo(st map[string]any, enabled bool) []string {
	todo := []string{}
	if !enabled {
		return todo
	}
	engine, _ := st["engine"].(string)
	installed, _ := st["engineInstalled"].(map[string]any)
	id, key := "starship", "starship"
	if engine == "ohmyposh" {
		id, key = "oh-my-posh", "ohmyposh"
	}
	if ok, _ := installed[key].(bool); !ok {
		todo = append(todo, "install "+id+" (extras_install ids [\""+id+"\"])")
	}
	if ok, _ := st["fishInstalled"].(bool); !ok {
		todo = append(todo, "install fish (extras_install ids [\"fish\"])")
	} else if ok, _ := st["fishIsLoginShell"].(bool); !ok {
		todo = append(todo, "fish is not the login shell: the prompt shows only in fish (ask before changing the login shell)")
	}
	if ok, _ := st["foreignPromptInit"].(bool); ok {
		todo = append(todo, "config.fish also sets a prompt; ours loads first and the one in config.fish wins")
	}
	return todo
}
