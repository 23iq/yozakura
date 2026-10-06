pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Layouts
import qs.modules.services
import qs.config
import qs.modules.aicenter.common
import "../../services/tasks/TaskModel.js" as TaskModel

// Code space without an interactive session: the task board of the
// project and the open task. Compact: sectioned list, the task replaces
// it (back = Esc). Wide: board columns, or list + task side by side once a
// task is open (ai.tasks.boardLayout: auto | columns | list).
// Keys (when no text field has focus): N new task, J/K or arrows move,
// Enter opens, A accept, R request changes, D discard, Esc back.
FocusScope {
    id: root
    objectName: "taskWorkspace"

    property string project: ""
    property bool wide: false
    property var collapsed: ({})
    property string cursorId: ""
    property real now: Date.now()
    signal newTaskRequested
    signal templateChosen(string command)
    signal escapeRequested

    readonly property var cfg: Config.ai.tasks
    readonly property var board: TaskModel.board(TasksService.tasks, {
        "dir": root.project,
        "collapsed": root.collapsed,
        "doneLimit": root.cfg.doneLimit
    })
    readonly property var ids: TaskModel.order(root.board)
    readonly property var selected: TasksService.selected && TaskModel.inProject(TasksService.selected, root.project) ? TasksService.selected : null
    readonly property bool roomy: root.wide && root.width >= 880
    readonly property bool sideBySide: root.roomy && root.selected !== null
    readonly property bool columns: root.roomy && !root.sideBySide && root.cfg.boardLayout !== "list"
    readonly property var templates: TasksService.templates[root.project] || []
    readonly property bool anyRunning: TasksService.tasks.some(t => TaskModel.statusInfo(t.status).busy)

    function open(id) {
        root.cursorId = id;
        TasksService.select(id, -1);
        root.forceActiveFocus();
    }
    function close() {
        TasksService.select("", -1);
        root.forceActiveFocus();
    }
    function toggle(section) {
        const next = Object.assign({}, root.collapsed);
        const s = root.board.sections.find(x => x.id === section);
        next[section] = !(s && s.collapsed);
        root.collapsed = next;
    }
    function move(delta) {
        const id = TaskModel.step(root.ids, root.selected ? root.selected.id : root.cursorId, delta);
        if (!id)
            return;
        root.cursorId = id;
        if (root.selected)
            TasksService.select(id, -1);
    }
    function target() {
        if (!root.selected && root.cursorId)
            TasksService.select(root.cursorId, -1);
        return detailLoader.item;
    }

    Timer {
        interval: 1000
        repeat: true
        running: root.visible && root.anyRunning
        onTriggered: root.now = Date.now()
    }

    Keys.onPressed: event => {
        if (event.modifiers & (Qt.ControlModifier | Qt.AltModifier | Qt.MetaModifier))
            return;
        let handled = true;
        switch (event.key) {
        case Qt.Key_N:
            root.newTaskRequested();
            break;
        case Qt.Key_J:
        case Qt.Key_Down:
            root.move(1);
            break;
        case Qt.Key_K:
        case Qt.Key_Up:
            root.move(-1);
            break;
        case Qt.Key_Return:
        case Qt.Key_Enter:
            if (root.cursorId)
                root.open(root.cursorId);
            break;
        case Qt.Key_Escape:
            if (root.selected)
                root.close();
            else
                root.escapeRequested();
            break;
        case Qt.Key_A:
            Qt.callLater(() => root.target() && root.target().accept());
            break;
        case Qt.Key_R:
            Qt.callLater(() => root.target() && root.target().requestChanges());
            break;
        case Qt.Key_D:
            Qt.callLater(() => root.target() && root.target().discard());
            break;
        default:
            handled = false;
        }
        event.accepted = handled;
    }

    TapHandler {
        onTapped: root.forceActiveFocus()
    }

    RowLayout {
        anchors.fill: parent
        spacing: BarLook.gap

        TaskBoard {
            Layout.fillHeight: true
            Layout.fillWidth: !root.sideBySide
            Layout.preferredWidth: root.sideBySide ? Math.min(360, root.width * 0.34) : -1
            visible: root.board.total > 0 && (root.sideBySide || root.selected === null)
            board: root.board
            columns: root.columns
            selectedId: root.selected ? root.selected.id : ""
            cursorId: root.cursorId
            now: root.now
            onOpened: id => root.open(id)
            onToggled: section => root.toggle(section)
        }

        BoardEmpty {
            Layout.fillWidth: true
            Layout.fillHeight: true
            visible: root.board.total === 0 && root.selected === null
            templates: root.templates
            onTemplateChosen: command => root.templateChosen(command)
        }

        Loader {
            id: detailLoader
            Layout.fillWidth: true
            Layout.fillHeight: true
            visible: root.selected !== null
            active: root.selected !== null
            sourceComponent: TaskDetail {
                task: root.selected
                showBack: !root.sideBySide
                now: root.now
                onCloseRequested: root.close()
            }
        }
    }
}
