pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import qs.modules.theme
import qs.modules.components
import qs.modules.services
import qs.config
import qs.modules.aicenter.common
import "PickerModel.js" as PickerModel
import "AgentPickerRows.js" as AgentRows
import "../../services/ai/Providers.js" as Providers
import "../../services/ai/ProviderPresets.js" as Presets

// Model/agent picker (Ctrl+K): search, recent engines, models grouped by
// provider with capability badges, providers without a connection
// (Connect -> connectRequested) and a refresh button. CLI agents expand
// into their own models (agents.models, listed for Ai.agentCwd); picking
// one sets engine + model at once (Ai.pickAgentModel). Keyboard: type to
// filter, Up/Down to move, Enter to pick (or expand an agent), Right/Left
// to expand/collapse, Esc to close. Opening it re-probes Ollama (throttled).
Popup {
    id: root
    objectName: "workspaceEnginePicker"

    property string filterKind: "all"   // chat (api+local) | agent | all
    signal picked(string id)
    signal connectRequested(string provider)

    readonly property var picker: Config.ai.picker || ({})
    readonly property var catalogModels: Ai.models || []

    // Presets with no listed model, no key/URL and no running local server
    // (hidden providers are left out; ProviderConnect.unconnected()).
    readonly property var unconnected: Ai.providers ? Ai.providers.unconnected : []
    readonly property var labels: {
        const out = {};
        for (const p of Presets.PRESETS)
            out[p.id] = p.label;
        return out;
    }
    // {agentId: true}: agents whose models are listed (the current one on open).
    property var expanded: ({})
    readonly property string agentCwd: Ai.agentCwd || ""
    readonly property var agentCatalogs: {
        const holder = Ai.agents ? Ai.agents.modelCatalogs : null;
        if (!holder)
            return ({});
        holder.catalogs; // dependency: re-read when a catalog arrives
        const out = {};
        for (const m of catalogModels)
            if (AgentRows.expandable(m) && holder.has(m.agent, agentCwd))
                out[m.agent] = Ai.agents.settingsFor(m.agent, agentCwd);
        return out;
    }
    readonly property var rows: PickerModel.build(catalogModels, {
        query: search.text,
        kind: filterKind,
        recent: Ai.recentModelIds || [],
        defaultId: Ai.defaultModelId,
        groupByProvider: picker.groupByProvider !== false,
        showRecent: picker.showRecent !== false,
        showUnconnected: picker.showUnconnected !== false,
        unconnected: unconnected,
        order: Presets.sorted().map(p => p.id),
        labels: labels,
        agentCatalogs: agentCatalogs,
        expanded: expanded,
        currentId: Ai.currentModel ? Ai.currentModel.id : "",
        currentAgentModel: Ai.agentSettings ? Ai.agentSettings.model || "" : ""
    })
    property int selectedIndex: 0

    function groupLabel(group) {
        if (group === "recent")
            return I18n.t("ai.picker_recent");
        if (group === "agent")
            return I18n.t("ai.cli_agents");
        if (group === "unconnected")
            return I18n.t("ai.picker_not_connected");
        return labels[group] || Providers.provider(group).label || group;
    }

    function activate(index) {
        const row = rows[index];
        if (!row)
            return false;
        if (row.type === "provider") {
            connectRequested(row.provider.id);
            close();
            return true;
        }
        if (row.type === "model" && row.expandable && search.text.trim().length === 0)
            return setExpanded(row.entry.agent, !row.expanded);
        if ((row.type !== "model" && row.type !== "agentModel") || row.entry.available === false)
            return false;
        if (Ai.busy) {
            close();
            return Ai.refuseBusy();
        }
        if (row.type === "agentModel")
            Ai.pickAgentModel(row.entry.agent, AgentRows.nativeId(row.model));
        else
            picked(row.entry.id);
        close();
        return true;
    }

    function pickManual(agent, model) {
        if (Ai.busy) {
            close();
            return Ai.refuseBusy();
        }
        Ai.pickAgentModel(agent, model);
        close();
        return true;
    }

    function setExpanded(agent, open) {
        const next = Object.assign({}, expanded);
        if (open)
            next[agent] = true;
        else
            delete next[agent];
        expanded = next;
        if (open)
            loadAgentModels(agent, false);
        return true;
    }

    // Loads an agent's model list for the space's folder (once; `force` re-asks).
    function loadAgentModels(agent, force) {
        if (Ai.agents && agent && (force || !Ai.agents.modelCatalogs.has(agent, agentCwd)))
            Ai.agents.refreshModels(agent, agentCwd);
    }

    function expandSelected(open) {
        const row = rows[selectedIndex];
        if (!row || !row.entry || !AgentRows.expandable(row.entry))
            return false;
        setExpanded(row.entry.agent, open);
        if (!open && row.type !== "model")
            selectedIndex = Math.max(0, rows.findIndex(r => r.type === "model" && r.entry.id === row.entry.id));
        return true;
    }

    function move(dir) {
        selectedIndex = PickerModel.step(rows, selectedIndex, dir);
        list.positionViewAtIndex(selectedIndex, ListView.Contain);
    }

    function refresh() {
        if (Ai.catalog)
            Ai.catalog.refresh();
        if (Ai.agents) {
            Ai.agents.refresh();
            for (const agent of Object.keys(expanded))
                loadAgentModels(agent, true);
        }
    }

    // Kept inside the bar at any size (the panel centres it, `y` below the header).
    width: Math.min(parent ? parent.width - 24 : 460, 460)
    height: Math.min(520, parent ? parent.height - y - 12 : 520, list.contentHeight + top.implicitHeight + footer.implicitHeight + 40)
    padding: 8
    modal: true
    focus: true
    closePolicy: Popup.CloseOnEscape | Popup.CloseOnPressOutside

    onOpened: {
        search.text = "";
        const cur = Ai.currentModel;
        expanded = cur && AgentRows.expandable(cur) ? {
            [cur.agent]: true
        } : {};
        // Every installed agent's models, so a search finds them ("haiku").
        for (const m of catalogModels)
            if (AgentRows.expandable(m))
                loadAgentModels(m.agent, false);
        selectedIndex = Math.max(0, PickerModel.initialIndex(rows, Ai.currentModel ? Ai.currentModel.id : ""));
        list.positionViewAtIndex(selectedIndex, ListView.Contain);
        search.forceActiveFocus();
        if (Ai.catalog) {
            if (Ai.catalog.apiModels.length === 0)
                Ai.catalog.refresh();
            else
                Ai.catalog.probeLocal(false);
        }
    }

    background: StyledRect {
        variant: "popup"
        radius: Styling.radius(0)
        enableShadow: true
    }

    contentItem: ColumnLayout {
        spacing: 6

        RowLayout {
            id: top
            Layout.fillWidth: true
            spacing: 6
            TextField {
                id: search
                objectName: "pickerSearch"
                Layout.fillWidth: true
                placeholderText: I18n.t("ai.search_models")
                placeholderTextColor: Colors.outline
                color: Colors.overBackground
                font.family: Config.theme.font
                font.pixelSize: Styling.fontSize(0)
                leftPadding: 32
                background: StyledRect {
                    variant: "common"
                    radius: Styling.radius(-4)
                    Text {
                        x: 10
                        anchors.verticalCenter: parent.verticalCenter
                        text: Icons.magnifyingGlass
                        font.family: Icons.font
                        font.pixelSize: 13
                        color: Colors.outline
                    }
                }
                onTextChanged: root.selectedIndex = Math.max(0, PickerModel.initialIndex(root.rows, ""))
                Keys.onPressed: event => {
                    if (event.key === Qt.Key_Down) {
                        root.move(1);
                        event.accepted = true;
                    } else if (event.key === Qt.Key_Up) {
                        root.move(-1);
                        event.accepted = true;
                    } else if ((event.key === Qt.Key_Right || event.key === Qt.Key_Left) && search.text.length === 0) {
                        event.accepted = root.expandSelected(event.key === Qt.Key_Right);
                    } else if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter) {
                        root.activate(root.selectedIndex);
                        event.accepted = true;
                    }
                }
            }
            Spinner {
                running: Ai.catalog !== null && Ai.catalog.fetching
                Layout.preferredWidth: 30
                horizontalAlignment: Text.AlignHCenter
            }
            IconButton {
                objectName: "pickerRefresh"
                visible: !(Ai.catalog !== null && Ai.catalog.fetching)
                glyph: Icons.arrowsClockwise
                tooltip: I18n.t("ai.refresh_models")
                onClicked: root.refresh()
            }
        }

        ListView {
            id: list
            objectName: "pickerList"
            Layout.fillWidth: true
            Layout.fillHeight: true
            Layout.minimumHeight: 60
            clip: true
            model: root.rows
            spacing: 2
            boundsBehavior: Flickable.StopAtBounds
            delegate: Loader {
                id: rowLoader
                required property var modelData
                required property int index
                width: list.width
                sourceComponent: ({
                        header: headerC,
                        provider: providerC,
                        agentModel: agentModelC,
                        agentStatus: agentNoteC,
                        agentManual: agentNoteC
                    })[modelData.type] || modelC

                Component {
                    id: headerC
                    Text {
                        text: root.groupLabel(rowLoader.modelData.group)
                        font.family: Config.theme.font
                        font.pixelSize: Styling.fontSize(-4)
                        font.weight: Font.DemiBold
                        font.capitalization: Font.AllUppercase
                        font.letterSpacing: 0.6
                        color: Colors.outline
                        topPadding: rowLoader.index === 0 ? 2 : 10
                        bottomPadding: 2
                        leftPadding: 8
                    }
                }
                Component {
                    id: modelC
                    ModelPickerRow {
                        objectName: "pickerRow_" + rowLoader.modelData.key
                        entry: rowLoader.modelData.entry
                        selected: rowLoader.index === root.selectedIndex
                        current: !!Ai.currentModel && Ai.currentModel.id === rowLoader.modelData.entry.id
                        isDefault: rowLoader.modelData.entry.id === Ai.defaultModelId
                        showBadges: root.picker.showCapabilities !== false
                        expandable: rowLoader.modelData.expandable === true
                        expanded: rowLoader.modelData.expanded === true
                        onActivated: {
                            root.selectedIndex = rowLoader.index;
                            root.activate(rowLoader.index);
                        }
                    }
                }
                Component {
                    id: agentModelC
                    AgentModelRow {
                        objectName: "pickerRow_" + rowLoader.modelData.key
                        model: rowLoader.modelData.model
                        selected: rowLoader.index === root.selectedIndex
                        current: rowLoader.modelData.current === true
                        onActivated: {
                            root.selectedIndex = rowLoader.index;
                            root.activate(rowLoader.index);
                        }
                    }
                }
                Component {
                    id: agentNoteC
                    AgentModelNote {
                        objectName: "pickerRow_" + rowLoader.modelData.key
                        status: rowLoader.modelData.status || ""
                        error: rowLoader.modelData.error || ""
                        manual: rowLoader.modelData.type === "agentManual"
                        onRetryRequested: root.loadAgentModels(rowLoader.modelData.entry.agent, true)
                        onManualPicked: model => root.pickManual(rowLoader.modelData.entry.agent, model)
                    }
                }
                Component {
                    id: providerC
                    ProviderConnectRow {
                        provider: rowLoader.modelData.provider
                        selected: rowLoader.index === root.selectedIndex
                        onConnectRequested: {
                            root.selectedIndex = rowLoader.index;
                            root.activate(rowLoader.index);
                        }
                    }
                }
            }
        }

        Text {
            visible: !root.rows.some(r => r.type === "model")
            Layout.alignment: Qt.AlignHCenter
            Layout.bottomMargin: 6
            text: Ai.catalog && Ai.catalog.fetching ? I18n.t("ai.loading_models") : I18n.t("ai.no_models")
            wrapMode: Text.Wrap
            horizontalAlignment: Text.AlignHCenter
            Layout.maximumWidth: root.width - 30
            font.family: Config.theme.font
            font.pixelSize: Styling.fontSize(-2)
            color: Colors.outline
        }

        RowLayout {
            id: footer
            Layout.fillWidth: true
            visible: root.filterKind !== "agent"
            Chip {
                objectName: "pickerConnect"
                glyph: Icons.plus
                label: I18n.t("ai.connect_provider")
                onClicked: {
                    root.connectRequested("");
                    root.close();
                }
            }
            Item {
                Layout.fillWidth: true
            }
            Text {
                visible: root.width >= 400
                text: I18n.t("ai.picker_hint")
                font.family: Config.theme.font
                font.pixelSize: Styling.fontSize(-5)
                color: Colors.outline
            }
        }
    }
}
