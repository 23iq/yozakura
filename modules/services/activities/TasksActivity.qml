pragma Singleton
import QtQuick
import qs.modules.theme
import qs.modules.services
import "ActivityModel.js" as Model
import "../tasks/TaskModel.js" as TaskModel

// Coding tasks of the backend (TasksService, svc/tasks): one activity for
// the summary headline. "◉ Codex is waiting" (pulsing dot) when an agent
// asks for permission or a plan waits, a spinner with the agent (or "3
// tasks running") while tasks run, "Ready for review", usage-limit and
// queued states. Click: opens the AI bar's Code space on that task.
ActivityProvider {
    id: root

    source: "tasks"

    // Read unconditionally: it instantiates the service (and its
    // subscription, which also handles tasks.open) with the shell.
    readonly property var summary: TasksService.activity

    activities: {
        const text = root.active ? TaskModel.activityText(root.summary, k => I18n.t(k)) : null;
        if (!text)
            return [];
        const headline = root.summary.headline;
        return [
            {
                "id": "tasks",
                "category": "task",
                "priority": Model.PRIORITY.timer - 5 + (headline === "waiting" ? 15 : 0),
                "icon": headline === "waiting" ? Icons.hand : (headline === "review" ? Icons.eye : (headline === "running" ? Icons.robot : Icons.hourglass)),
                "indicator": text.pulse ? "dot" : (text.busy ? "ring" : "glyph"),
                "label": text.label,
                "detail": text.detail,
                "progress": -1,
                "color": text.color,
                "startedAt": 0,
                "action": {
                    "kind": "task",
                    "id": root.summary.taskId || ""
                }
            }
        ];
    }

    function activate(activity, button, screenName) {
        const a = activity && activity.action ? activity.action : {};
        if (a.id)
            TasksService.focusTask(a.id, -1);
        else
            TasksService.focusTask((TasksService.tasks[0] || {}).id || "", -1);
    }
}
