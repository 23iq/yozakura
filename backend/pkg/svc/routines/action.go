package routines

import (
	"fmt"
	"strings"

	"yozakura/backend/pkg/brand"
	"yozakura/backend/pkg/svc/compositor"
)

// RoutineAction is the bind action that runs a routine (args.routine).
const RoutineAction = "utilities.routine"

// ActionArgv turns a bind action into the command that performs it now:
// "exec" actions run their command line through sh (exactly what the
// compositor bind would run), window/workspace dispatchers go through the
// compositor daemon so they work on every compositor it supports.
// Pointer-drag and layout-specific dispatchers only make sense on a key and
// are refused.
func ActionArgv(id string, args map[string]any) ([]string, error) {
	spec, ok := compositor.GetActionById(id)
	if !ok {
		return nil, fmt.Errorf("unknown action %q", id)
	}
	if args == nil {
		args = map[string]any{}
	}
	for _, a := range spec.Args {
		if _, set := args[a.Key]; !set && a.DefaultValue != "" {
			args[a.Key] = a.DefaultValue
		}
	}
	res := compositor.ResolveAction(compositor.Action{ID: spec.ID, Args: args})
	if res == nil {
		return nil, fmt.Errorf("action %q cannot be resolved", id)
	}
	arg := strings.TrimSpace(res.Argument)
	d := brand.Daemon
	switch res.Dispatcher {
	case "exec":
		if arg == "" {
			return nil, fmt.Errorf("action %q has nothing to run (missing argument?)", id)
		}
		return []string{"sh", "-c", arg}, nil
	case "killactive":
		return []string{d, "window", "close"}, nil
	case "movefocus":
		return []string{d, "window", "focus-dir", arg}, nil
	case "movewindow":
		if arg == "" {
			break // pointer drag
		}
		return []string{d, "window", "move", arg}, nil
	case "togglefloating":
		return []string{d, "window", "toggle-floating"}, nil
	case "workspace":
		return []string{d, "workspace", "switch", arg}, nil
	case "movetoworkspace":
		return []string{d, "workspace", "move-to", arg}, nil
	case "movetoworkspacesilent":
		return []string{d, "window", "move-to-workspace-silent", arg}, nil
	case "togglespecialworkspace":
		if arg == "" {
			return []string{d, "workspace", "toggle-special"}, nil
		}
		return []string{d, "workspace", "toggle-special", arg}, nil
	}
	return nil, fmt.Errorf("action %q (%s) only works from a keybind; use a tool step instead", id, spec.Label)
}

// ActionLabel is the catalog label of an action id (the id when unknown).
func ActionLabel(id string) string {
	if spec, ok := compositor.GetActionById(id); ok {
		return spec.Label
	}
	return id
}
