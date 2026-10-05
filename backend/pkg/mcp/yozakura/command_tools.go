package yozakura

import (
	"context"
	"encoding/json"
	"fmt"
	"os"
	"strings"

	"yozakura/backend/pkg/brand"
	"yozakura/backend/pkg/commands"
	"yozakura/backend/pkg/mcp"
)

// Command tools expose the shell command registry
// (assets/commands/commands.json): the launcher's ">" commands.

func commandTools(d Deps) []mcp.ToolDef {
	return []mcp.ToolDef{
		define("shell_commands", "List shell commands",
			`List the shell's quick commands (the launcher's ">" commands, also `+"`"+brand.AppID+` cmd`+"`"+`): id, title, description, usage and argument spec (kind none/enum/number/preset, values, min/max). Run one with shell_command.`,
			noArgs, toolOpts{readOnly: true}, d.shellCommands),
		define("shell_command", "Run shell command",
			`Run one quick command by id with an optional argument, exactly like typing "> <id> <arg>" in the launcher: e.g. {"command":"dnd"}, {"command":"glass","arg":"0.6"}, {"command":"preset","arg":"Neon Tokyo"}, {"command":"wallpaper","arg":"random"}. Call shell_commands first for ids and argument ranges.`,
			`{"type":"object","properties":{"command":{"type":"string","description":"Command id from shell_commands."},"arg":{"type":"string","description":"Argument (enum value, number, or preset name)."}},"required":["command"],"additionalProperties":false}`,
			toolOpts{}, d.shellCommand),
	}
}

func (d Deps) commandRegistry() (*commands.Registry, error) {
	return commands.Load(d.ShellSource)
}

func (d Deps) shellCommands(_ context.Context, _ json.RawMessage) (*mcp.CallToolResult, error) {
	reg, err := d.commandRegistry()
	if err != nil {
		return nil, err
	}
	return mcp.JSONResult(map[string]any{"commands": reg.Views()}), nil
}

func (d Deps) shellCommand(ctx context.Context, args json.RawMessage) (*mcp.CallToolResult, error) {
	var a struct{ Command, Arg string }
	if err := decode(args, &a); err != nil {
		return nil, err
	}
	if strings.TrimSpace(a.Command) == "" {
		return nil, fmt.Errorf("command is required")
	}
	reg, err := d.commandRegistry()
	if err != nil {
		return nil, err
	}
	exec := commands.Executor{
		Call: func(method string, params any) error {
			_, err := d.call(method, params)
			return err
		},
		Exec: func(argv []string) (string, error) {
			if d.Run == nil {
				return "", fmt.Errorf("cannot run commands")
			}
			self, err := os.Executable()
			if err != nil {
				self = brand.AppID
			}
			out, err := d.Run.Run(ctx, nil, self, argv...)
			return strings.TrimSpace(string(out)), err
		},
		SetConfig: func(key string, value any) (string, error) {
			_, store, err := d.catalog()
			if err != nil {
				return "", err
			}
			return commands.ConfigSetter(store)(key, value)
		},
	}
	res, err := reg.Run(exec, a.Command, a.Arg)
	if err != nil {
		return nil, err
	}
	return mcp.JSONResult(map[string]any{"command": a.Command, "arg": a.Arg, "result": res}), nil
}
