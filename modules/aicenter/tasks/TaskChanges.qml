import QtQuick
import qs.modules.services
import qs.modules.aicenter.agent

// The diff of one run against its base (tasks.diff), file by file in the
// ChangesPane. Reloads when the run changes (fix attempts, follow-ups).
ChangesPane {
    id: root
    objectName: "taskChanges"

    property string taskId: ""
    property int run: 0
    property real revision: 0           // task.updatedAt
    property string error: ""

    function reload() {
        if (!root.taskId || !root.visible)
            return;
        const key = root.taskId + ":" + root.run;
        TasksService.diff(root.taskId, root.run, (diff, error) => {
            if (key !== root.taskId + ":" + root.run)
                return;
            root.error = error;
            root.diffs = diff ? [
                {
                    "diff": diff
                }
            ] : [];
        });
    }

    closable: false
    onTaskIdChanged: reload()
    onRunChanged: reload()
    onRevisionChanged: reload()
    onVisibleChanged: reload()
    Component.onCompleted: reload()
}
