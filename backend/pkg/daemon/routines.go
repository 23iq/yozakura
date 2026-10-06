package daemon

import (
	"context"
	"encoding/json"
	"path/filepath"

	"yozakura/backend/pkg/brand"
	"yozakura/backend/pkg/ipc"
	"yozakura/backend/pkg/paths"
	mcpsvc "yozakura/backend/pkg/svc/mcp"
	notifysvc "yozakura/backend/pkg/svc/notify"
	"yozakura/backend/pkg/svc/routines"
)

// newRoutines wires the routines service: action steps run as commands,
// tool steps call the built-in MCP tools in-process, failures notify.
func newRoutines(srv *ipc.Server, p *paths.Paths, mcp *mcpsvc.Service, notify *notifysvc.Service) {
	svc := routines.NewService(routines.Options{
		Path: filepath.Join(p.ConfigDir, routines.FileName),
		Exec: routines.Executor{
			Exec: routines.ExecArgv,
			Tool: func(ctx context.Context, name string, args map[string]any) (string, bool, error) {
				raw, _ := json.Marshal(args)
				if args == nil {
					raw = []byte(`{}`)
				}
				res, err := mcp.CallTool(ctx, brand.AppID, name, raw)
				if err != nil {
					return "", false, err
				}
				return res.Text(), res.IsError, nil
			},
		},
		Notify: func(summary, body string) {
			_, _ = notify.Send(notifysvc.SendParams{Summary: summary, Body: body, AppIcon: "dialog-warning", ReplaceKey: "routine-failed"})
		},
	})
	svc.Register(srv)
}
