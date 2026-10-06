package daemon

import (
	"context"
	"encoding/json"
	"path/filepath"

	"yozakura/backend/pkg/ipc"
	"yozakura/backend/pkg/paths"
	mcpsvc "yozakura/backend/pkg/svc/mcp"
	notifysvc "yozakura/backend/pkg/svc/notify"
	"yozakura/backend/pkg/svc/routines"
)

// newRoutines wires the routines service: action steps run as commands,
// tool steps call the built-in MCP tools in-process (also when the user
// turned that server off for AI engines), failures notify.
func newRoutines(srv *ipc.Server, p *paths.Paths, mcp *mcpsvc.Service, notify *notifysvc.Service) *routines.Service {
	svc := routines.NewService(routines.Options{
		Path: filepath.Join(p.ConfigDir, routines.FileName),
		Exec: routines.Executor{
			Exec: routines.ExecArgv,
			Tool: func(ctx context.Context, name string, args map[string]any) (string, bool, error) {
				raw, _ := json.Marshal(args)
				if args == nil {
					raw = []byte(`{}`)
				}
				res, err := mcp.CallBuiltin(ctx, name, raw)
				if err != nil {
					return "", false, err
				}
				return res.Text(), res.IsError, nil
			},
		},
		Notify: func(sp notifysvc.SendParams) {
			sp.AppIcon, sp.ReplaceKey = "dialog-warning", "routine-failed"
			_, _ = notify.Send(sp)
		},
	})
	svc.Register(srv)
	return svc
}

// routineGate makes the agents ask before an AI saves or runs a routine
// with confirm-required steps, and grants the run the user allowed.
type routineGate struct{ svc *routines.Service }

func (g routineGate) NeedsConfirm(tool string, input map[string]any) bool {
	switch tool {
	case "routine_run":
		id, _ := input["id"].(string)
		return len(g.svc.ConfirmFor(id)) > 0
	case "routine_save":
		raw, _ := json.Marshal(input)
		var r routines.Routine
		if json.Unmarshal(raw, &r) != nil {
			return true
		}
		list, _ := g.svc.List()
		lookup := func(ref string) (routines.Routine, bool) {
			if i := routines.Find(list, ref); i >= 0 {
				return list[i], true
			}
			return routines.Routine{}, false
		}
		return len(routines.ConfirmSteps(r, lookup)) > 0
	}
	return false
}

func (g routineGate) Allowed(tool string, input map[string]any) {
	if tool == "routine_run" {
		id, _ := input["id"].(string)
		g.svc.Grant(id)
	}
}
