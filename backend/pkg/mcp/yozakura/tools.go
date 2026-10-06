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
never guess key names. Save a preset (preset_save) before sweeping changes so the user can go back.`

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
	out = append(out, usageTools(d)...)
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
