package yozakura

import (
	"context"
	"encoding/json"
	"fmt"
	"strings"
	"yozakura/backend/pkg/brand"

	"yozakura/backend/pkg/mcp"
)

// ServerInstructions are sent with initialize: a short orientation for
// whatever model connects.
const ServerInstructions = `Yozakura is the user's Wayland desktop shell (bar, notch, dock, launcher, sidebar).
These tools read and change it. Prefer reading state first (config_get, windows_list, workspaces_list,
media_status) and make the smallest change that fulfils the request. Config changes apply live and persist.
Find keys with config_search or config_schema and check them with config_describe before config_set;
never guess key names. Save a preset (preset_save) before sweeping changes so the user can go back.
Beyond the look of the shell you can: start timers, reminders, the stopwatch and focus mode; read and write the
user's notes; find, launch and close apps; report battery/CPU/disk/network/Bluetooth; connect Bluetooth devices,
saved Wi-Fi networks and switch the audio output; set brightness, night light and caffeine; look at the screen
(screen_look, vision models). Keybinds: find what to bind with binds_search, check a combo with binds_check, propose
free combos with binds_suggest, then binds_set after the user agrees. Routines bundle several steps into one
command (routine_save; "save this as a routine"), run by a keybind (action utilities.routine), the launcher or
routine_run. Results with "undo" can be reverted; mention it. Ask before closing apps or deleting anything.`

type toolOpts struct {
	readOnly    bool
	destructive bool
	idempotent  bool
	openWorld   bool
}

func define(name, title, desc, schema string, o toolOpts, h mcp.Handler) mcp.ToolDef {
	if !json.Valid([]byte(schema)) {
		panic("invalid schema for tool " + name)
	}
	ann := &mcp.ToolAnnotations{Title: title, ReadOnlyHint: mcp.Bool(o.readOnly)}
	if !o.readOnly {
		ann.DestructiveHint = mcp.Bool(o.destructive)
		ann.IdempotentHint = mcp.Bool(o.idempotent)
	}
	ann.OpenWorldHint = mcp.Bool(o.openWorld)
	return mcp.ToolDef{
		Tool:    mcp.Tool{Name: name, Title: title, Description: desc, InputSchema: json.RawMessage(schema), Annotations: ann},
		Handler: h,
	}
}

func decode(args json.RawMessage, v any) error {
	if len(args) == 0 {
		return nil
	}
	if err := json.Unmarshal(args, v); err != nil {
		return fmt.Errorf("invalid arguments: %v", err)
	}
	return nil
}

const noArgs = `{"type":"object","properties":{},"additionalProperties":false}`

// Tools returns every Yozakura tool bound to deps.
func Tools(d Deps) []mcp.ToolDef {
	var out []mcp.ToolDef
	out = append(out, configTools(d)...)
	out = append(out, presetTools(d)...)
	out = append(out, desktopTools(d)...)
	out = append(out, systemTools(d)...)
	out = append(out, commandTools(d)...)
	out = append(out, specialTools(d)...)
	out = append(out, timerTools(d)...)
	out = append(out, usageTools(d)...)
	out = append(out, taskTools(d)...)
	out = append(out, bindTools(d)...)
	out = append(out, routineTools(d)...)
	out = append(out, noteTools(d)...)
	out = append(out, appTools(d)...)
	out = append(out, sysinfoTools(d)...)
	out = append(out, connectionTools(d)...)
	out = append(out, displayTools(d)...)
	out = append(out, focusTools(d)...)
	out = append(out, visionTools(d)...)
	return out
}

// ReadOnlyToolNames lists the tools with readOnlyHint (for permission
// policies that auto-approve reads).
func ReadOnlyToolNames() []string {
	var names []string
	for _, t := range Tools(Deps{}) {
		if t.Tool.ReadOnly() {
			names = append(names, t.Tool.Name)
		}
	}
	return names
}

// NewServer builds the stdio MCP server for `yozakura mcp`.
func NewServer(d Deps, version string) *mcp.Server {
	return mcp.NewServer(mcp.Implementation{Name: brand.AppID, Version: version}, ServerInstructions, Tools(d))
}

func trimOut(b []byte) string { return strings.TrimSpace(string(b)) }

// runText runs a command and returns trimmed stdout.
func (d Deps) runText(ctx context.Context, stdin []byte, name string, args ...string) (string, error) {
	if d.Run == nil {
		return "", fmt.Errorf("no command runner")
	}
	out, err := d.Run.Run(ctx, stdin, name, args...)
	return trimOut(out), err
}
