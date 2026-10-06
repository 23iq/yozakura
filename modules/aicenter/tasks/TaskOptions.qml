pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Layouts
import qs.modules.theme
import qs.modules.components
import qs.modules.services
import qs.config
import qs.modules.aicenter.common
import "../../services/tasks/TaskModel.js" as TaskModel
import "../../services/ai/EffortPrefs.js" as Prefs

// Options of a new task, above the composer in the Code space: agents
// (several = best-of-N), model and effort (one agent), Plan first, Work in
// the current branch, templates (`/`), and the switch to an interactive
// agent chat. The chips wrap in narrow sizes. `submit()` turns the composer text into tasks.create.
RowLayout {
    id: root
    objectName: "taskOptions"

    property string project: ""
    property bool chat: false
    signal chatToggled(bool chat)
    signal templateChosen(string command)
    // An asynchronous create failed: give the text back to the composer.
    signal restore(string text, var attachments)

    readonly property var cfg: Config.ai.tasks
    readonly property var available: (Ai.agents ? Ai.agents.agents : []).filter(a => a.available)
    property var agents: []
    property string model: ""
    property string effort: ""
    property bool planFirst: root.cfg.planFirst
    property bool inPlace: root.cfg.inPlace
    property string error: ""
    readonly property var templates: TasksService.templates[root.project] || []
    readonly property string single: root.agents.length === 1 ? root.agents[0] : ""
    readonly property var catalog: {
        Ai.agents && Ai.agents.modelCatalogs ? Ai.agents.modelCatalogs.catalogs : null;
        return root.single && Ai.agents ? Ai.agents.settingsFor(root.single, root.project) : {
            "models": []
        };
    }
    readonly property var modelEntry: (root.catalog.models || []).find(m => root.model ? m.id === root.model : m.isDefault) || null
    readonly property var efforts: root.modelEntry ? root.modelEntry.efforts || [] : []
    // What the task will run with, before it starts ("Opus 5.5", "medium").
    readonly property string modelLabel: Prefs.agentModelLabel(root.catalog, root.model) || (root.catalog.loading ? "…" : I18n.t("ai.tasks.default_model"))
    readonly property string effortLabel: root.effort || (root.modelEntry ? root.modelEntry.defaultEffort || "" : "") || I18n.t("ai.effort_level.auto")

    // Default: ai.tasks.defaultAgents when set, else the agent and model
    // last picked in the Code space (Ai.engineMemory), else the first agent.
    function resetAgents() {
        const ids = root.available.map(a => a.id);
        const wanted = (root.cfg.defaultAgents || []).filter(id => ids.indexOf(id) >= 0);
        const memory = Ai.engineMemory || null;
        const picked = memory ? String(memory.engine("code") || "").replace(/^agent:/, "") : "";
        root.agents = wanted.length ? wanted : (ids.indexOf(picked) >= 0 ? [picked] : ids.slice(0, 1));
        root.useRemembered();
    }
    function useRemembered() {
        const memory = Ai.engineMemory || null;
        const picked = root.single && memory ? memory.agentModel("code", root.single) : undefined;
        root.model = picked || "";
        const level = root.single && Ai.effort ? Ai.effort.rememberedFor(root.single, root.model) : null;
        root.effort = level || "";
    }
    function toggleAgent(id) {
        const list = root.agents.slice();
        const i = list.indexOf(id);
        if (i >= 0 && list.length > 1)
            list.splice(i, 1);
        else if (i < 0 && list.length < 4)
            list.push(id);
        root.agents = list;
        root.useRemembered();
    }
    function options() {
        return {
            "dir": root.project,
            "agents": root.agents,
            "model": root.model,
            "effort": root.effort,
            "planFirst": root.planFirst,
            "inPlace": root.inPlace,
            "templates": root.templates
        };
    }
    // Returns false (composer keeps the text) when the input is not a task yet.
    function submit(text, attachments) {
        const o = Object.assign(root.options(), {
            "text": text,
            "attachments": attachments
        });
        const err = TaskModel.createError(o);
        root.error = err ? I18n.t("ai.tasks.create_error." + err) : "";
        if (err)
            return false;
        TasksService.create(TaskModel.createParams(o), (task, error) => {
            if (error) {
                root.error = error;
                root.restore(text, attachments);
            }
        });
        return true;
    }

    onAvailableChanged: if (root.agents.length === 0 || root.agents.some(id => !root.available.some(a => a.id === id)))
        root.resetAgents()
    onSingleChanged: if (root.single && Ai.agents)
        Ai.agents.refreshModels(root.single, root.project)
    onProjectChanged: if (root.single && Ai.agents && !Ai.agents.modelCatalogs.has(root.single, root.project))
        Ai.agents.refreshModels(root.single, root.project)
    Component.onCompleted: root.resetAgents()

    spacing: 4

    // Wraps onto a second line in the compact bar.
    Flow {
        objectName: "taskOptionChips"
        Layout.fillWidth: true
        Layout.alignment: Qt.AlignVCenter
        spacing: 4
        Repeater {
            model: root.chat ? [] : root.available
            delegate: Chip {
                id: agentChip
                required property var modelData
                objectName: "taskAgent_" + modelData.id
                label: agentChip.modelData.label
                active: root.agents.indexOf(agentChip.modelData.id) >= 0
                onClicked: root.toggleAgent(agentChip.modelData.id)
            }
        }
        UiText {
            visible: !root.chat && root.agents.length > 1
            text: I18n.t("ai.tasks.best_of").replace("%1", root.agents.length)
            muted: true
            size: -3
        }
        Chip {
            objectName: "taskModel"
            visible: !root.chat && root.single.length > 0 && ((root.catalog.models || []).length > 0 || root.catalog.loading === true)
            label: root.modelLabel
            trailingIcon: Icons.caretDown
            variant: "transparent"
            onClicked: modelMenu.open()
            OptionMenu {
                id: modelMenu
                y: -implicitHeight - 6
                current: root.model
                options: [
                    {
                        "value": "",
                        "label": I18n.t("ai.tasks.default_model")
                    }
                ].concat((root.catalog.models || []).map(m => ({
                            "value": m.id,
                            "label": m.name || m.id,
                            "detail": m.description || ""
                        })))
                onPicked: value => {
                    root.model = value;
                    root.effort = "";
                }
            }
        }
        Chip {
            objectName: "taskEffort"
            visible: !root.chat && root.single.length > 0 && root.efforts.length > 0
            glyph: Icons.brain
            label: root.effortLabel
            trailingIcon: Icons.caretDown
            variant: "transparent"
            onClicked: effortMenu.open()
            OptionMenu {
                id: effortMenu
                y: -implicitHeight - 6
                width: 180
                current: root.effort
                options: [
                    {
                        "value": "",
                        "label": I18n.t("ai.effort_level.auto")
                    }
                ].concat(root.efforts.map(e => ({
                            "value": e,
                            "label": e
                        })))
                onPicked: value => root.effort = value
            }
        }
        Chip {
            objectName: "taskPlanFirst"
            visible: !root.chat
            glyph: Icons.listChecks
            label: I18n.t("ai.tasks.plan_first")
            active: root.planFirst
            onClicked: root.planFirst = !root.planFirst
        }
        Chip {
            objectName: "taskInPlace"
            visible: !root.chat
            glyph: Icons.gitBranch
            label: I18n.t("ai.tasks.in_place")
            active: root.inPlace
            enabled: root.agents.length <= 1
            opacity: enabled ? 1 : 0.5
            onClicked: root.inPlace = !root.inPlace
        }
    }
    UiText {
        Layout.maximumWidth: 260
        visible: root.error.length > 0
        text: root.error
        color: Colors.error
        size: -3
    }
    IconButton {
        objectName: "taskTemplates"
        visible: !root.chat && root.templates.length > 0
        glyph: Icons.lightningBolt
        tooltip: I18n.t("ai.tasks.templates") + " (/)"
        onClicked: templateMenu.open()
        OptionMenu {
            id: templateMenu
            y: -implicitHeight - 6
            x: -width + parent.width
            options: root.templates.map(t => ({
                        "value": t.id,
                        "label": "/" + t.id,
                        "detail": t.description || t.name || "",
                        "mono": true
                    }))
            onPicked: value => root.templateChosen("/" + value + " ")
        }
    }
    IconButton {
        objectName: "taskChatToggle"
        glyph: root.chat ? Icons.kanban : Icons.chatDots
        tooltip: I18n.t(root.chat ? "ai.tasks.to_tasks" : "ai.tasks.to_chat")
        onClicked: root.chatToggled(!root.chat)
    }
}
