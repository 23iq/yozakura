package daemon

import (
	"path/filepath"

	"yozakura/backend/pkg/ipc"
	"yozakura/backend/pkg/paths"
	"yozakura/backend/pkg/svc"
	"yozakura/backend/pkg/svc/agents"
	notifysvc "yozakura/backend/pkg/svc/notify"
	"yozakura/backend/pkg/svc/tasks"
)

// newTasks builds the tasks service on top of the agents manager and
// registers it; its queue starts from Run (d.tasks.Start).
func newTasks(srv *ipc.Server, p *paths.Paths, am *agents.Manager, n *notifysvc.Service, ui *svc.UIService) *tasks.Manager {
	m := tasks.New(tasks.Options{
		Dir:          filepath.Join(p.DataDir, "tasks"),
		WorktreeRoot: filepath.Join(p.DataDir, "worktrees"),
		Templates: tasks.TemplateDirs{
			Bundled: filepath.Join(paths.FindShellSource(), "assets", "ai", "task-templates"),
			Global:  filepath.Join(p.ConfigDir, "task-templates"),
		},
		Agents: am,
		Notify: func(sp notifysvc.SendParams) { _, _ = n.Send(sp) },
		OpenUI: func() { ui.Run("ai-code") },
	})
	tasks.NewService(m).Register(srv)
	return m
}
