pragma ComponentBehavior: Bound
import QtQuick
import qs.modules.theme
import qs.modules.components
import qs.modules.globals
import qs.modules.services
import qs.modules.components.kit
import qs.config
import "Providers.js" as Providers
import "../../components/preview/Preview.js" as Preview
import "ResultStyles.js" as ResultStyles

// The launcher's search tab: the search field, the provider results
// (LauncherResults) and keyboard handling. Enter runs the selected result,
// Shift+Enter (or right click) expands its options, Tab completes a command
// or sends the query to the AI quick ask, Esc closes.
// Preview (`preview`, LauncherView passes it): the query is the sample
// "launcher.query", the selection "launcher.selected" (default the first
// row); the result style and the detail pane follow overrides of
// layout.launcher.resultStyle / .preview; nothing is written to
// GlobalStates and nothing runs (LauncherResults).
Item {
    id: view

    property var preview: null
    readonly property bool previewing: Preview.on(view.preview)
    readonly property string searchText: view.previewing ? Preview.sample(view.preview, "launcher.query", "") : GlobalStates.launcherSearchText
    property int selectedIndex: view.previewing ? Preview.sample(view.preview, "launcher.selected", 0) : GlobalStates.launcherSelectedIndex
    property int expandedIndex: -1
    property int optionIndex: 0
    property var expandedOptions: []
    readonly property var items: results.items
    readonly property alias resultsHost: results
    readonly property var current: selectedIndex >= 0 && selectedIndex < items.length ? items[selectedIndex] : null

    // Result look (layout.launcher.resultStyle): list, cards or the app grid
    // (other providers' results fall back to list; options need the list).
    readonly property string styleName: ResultStyles.effective(Preview.pick(view.preview, "layout.launcher.resultStyle", Config.layout.launcher.resultStyle), items)
    readonly property bool gridActive: styleName === "grid" && expandedIndex < 0
    readonly property bool detailOn: Preview.pick(view.preview, "layout.launcher.preview", Config.layout.launcher.preview) === true
    readonly property bool previewOpen: view.detailOn && expandedIndex < 0 && detail.available
    readonly property int resultsWidth: previewOpen ? Metrics.launcherLeftPanelW : width

    function gridKey(dir) {
        select(grid.nextIndex(dir));
    }

    // Glyph of the provider whose prefix is typed, else the search glyph.
    readonly property string modeIcon: {
        if (results.mode !== "prefix" || !results._route.providers.length)
            return "";
        const p = Providers.byId(results._route.providers[0].id);
        return p ? (Icons[p.icon] || "") : "";
    }

    function focusSearchInput() {
        if (!view.previewing)
            input.focusInput();
    }

    function close() {
        Visibilities.setActiveModule("");
    }

    function select(i) {
        const n = items.length;
        if (n === 0)
            i = -1;
        else
            i = Math.max(-1, Math.min(i, n - 1));
        view.selectedIndex = i;
        if (!view.previewing)
            GlobalStates.launcherSelectedIndex = i;
    }

    function collapse() {
        view.expandedIndex = -1;
        view.optionIndex = 0;
        view.expandedOptions = [];
    }

    function expand(i) {
        const opts = i >= 0 && i < items.length ? results.options(items[i]) : [];
        if (opts.length === 0) {
            collapse();
            return;
        }
        view.expandedOptions = opts;
        view.optionIndex = 0;
        view.expandedIndex = i;
    }

    function run(i, option) {
        const item = i >= 0 && i < items.length ? items[i] : null;
        if (!item || item.inert)
            return;
        if (results.activate(item, option || ""))
            view.close();
    }

    function runSelected() {
        if (expandedIndex >= 0) {
            const o = expandedOptions[optionIndex];
            run(expandedIndex, o ? o.id : "");
            collapse();
            return;
        }
        run(selectedIndex >= 0 ? selectedIndex : 0, "");
    }

    function tab() {
        const done = results.completion(current);
        if (done !== "") {
            GlobalStates.launcherSearchText = done;
            return;
        }
        const aiRoute = results.mode === "prefix" && results._route.providers[0].id === "ai";
        if ((results.mode === "mixed" || aiRoute) && Config.prefix.launcher.aiOnTab && results.askAi())
            view.close();
    }

    onSearchTextChanged: {
        list.enableScrollAnimation = false;
        collapse();
        results.search(searchText);
        list.contentY = 0;
        // (the view may be gone by then: a settings preview torn down)
        Qt.callLater(() => {
            if (list)
                list.enableScrollAnimation = true;
        });
    }

    // Async results (files, rates) keep the selection valid.
    onItemsChanged: {
        if (view.previewing)
            return;
        if (selectedIndex >= items.length)
            select(items.length - 1);
        else if (selectedIndex < 0 && searchText.length > 0 && items.length > 0)
            select(0);
        else if (searchText.length === 0 && selectedIndex >= 0 && GlobalStates.launcherSelectedIndex < 0)
            select(-1);
    }

    LauncherResults {
        id: results
        preview: view.preview
        onCloseRequested: view.close()
        onSearchRequested: t => GlobalStates.launcherSearchText = t
        Component.onCompleted: results.search(view.searchText)
    }

    SearchField {
        id: input
        objectName: "launcherSearchInput"
        width: parent.width
        anchors.top: parent.top
        text: view.searchText
        placeholderText: I18n.t("launcher.search")
        glyph: view.modeIcon !== "" ? view.modeIcon : Icons.magnifyingGlass
        hints: Providers.hintPrefixes(Config.prefix, Config.prefix.launcher.disabled)
        handleTabNavigation: true
        // Home / End select the first / last result
        handleHomeEnd: true
        disableCursorNavigation: view.gridActive

        onSearchTextChanged: text => {
            if (view.previewing)
                return;
            if (GlobalStates.launcherSearchText !== text)
                GlobalStates.launcherSearchText = text;
            view.select(text.length > 0 ? 0 : -1);
        }
        onAccepted: view.runSelected()
        onShiftAccepted: {
            if (view.expandedIndex >= 0 && view.expandedIndex === view.selectedIndex)
                view.collapse();
            else
                view.expand(view.selectedIndex);
        }
        onTabPressed: view.tab()
        clearOnEscape: false
        onEscapePressed: {
            if (view.expandedIndex >= 0) {
                view.collapse();
            } else {
                view.close();
                GlobalStates.clearLauncherStateAfter(Motion.exit.duration + Motion.morph.duration);
            }
        }
        onLeftPressed: {
            if (view.gridActive)
                view.gridKey("left");
        }
        onRightPressed: {
            if (view.gridActive)
                view.gridKey("right");
        }
        onDownPressed: {
            if (view.gridActive)
                view.gridKey("down");
            else if (view.expandedIndex >= 0)
                view.optionIndex = Math.min(view.optionIndex + 1, view.expandedOptions.length - 1);
            else
                view.select(view.selectedIndex + 1);
        }
        onUpPressed: {
            if (view.gridActive)
                view.gridKey("up");
            else if (view.expandedIndex >= 0)
                view.optionIndex = Math.max(view.optionIndex - 1, 0);
            else if (view.selectedIndex > 0)
                view.select(view.selectedIndex - 1);
            else if (view.searchText.length === 0)
                view.select(-1);
        }
        onPageDownPressed: {
            const page = Math.max(1, Math.floor(list.height / list.rowHeight));
            view.select(view.selectedIndex < 0 ? page - 1 : view.selectedIndex + page);
        }
        onPageUpPressed: {
            const page = Math.max(1, Math.floor(list.height / list.rowHeight));
            view.select(Math.max(0, view.selectedIndex - page));
        }
        onHomePressed: view.select(0)
        onEndPressed: view.select(view.items.length - 1)
    }

    Divider {
        id: rule
        anchors.top: input.bottom
        width: parent.width
    }

    // The results in the language's group box (none in ink, a frosted card
    // in glass, a tile in tiles).
    Group {
        id: resultsBox
        anchors.top: rule.bottom
        anchors.topMargin: Look.groupBoxed ? Space.m : Space.xs
        width: view.resultsWidth

        Item {
            width: parent.width
            height: view.height - resultsBox.y - resultsBox.padding * 2

            ResultList {
                id: list
                objectName: "launcherResults"
                anchors.fill: parent
                visible: !view.gridActive
                style: view.styleName === "cards" ? "cards" : "list"
                narrow: view.previewOpen
                items: view.items
                selectedIndex: view.selectedIndex
                expandedIndex: view.expandedIndex
                expandedOptions: view.expandedOptions
                optionIndex: view.optionIndex
                emptyText: view.searchText.length > 0 && !results.busy ? I18n.t("launcher.no_results") : ""

                onHoveredRow: index => view.select(index)
                onClickedRow: index => {
                    if (view.expandedIndex === -1)
                        view.run(index, "");
                }
                onRightClickedRow: index => {
                    view.select(index);
                    if (view.expandedIndex === index)
                        view.collapse();
                    else
                        view.expand(index);
                }
                onOptionHovered: index => view.optionIndex = index
                onOptionTriggered: index => {
                    view.optionIndex = index;
                    view.runSelected();
                }
            }

            ResultGrid {
                id: grid
                objectName: "launcherGrid"
                anchors.fill: parent
                visible: view.gridActive
                items: view.gridActive ? view.items : []
                selectedIndex: view.selectedIndex

                onHoveredRow: index => view.select(index)
                onClickedRow: index => view.run(index, "")
                onRightClickedRow: index => {
                    view.select(index);
                    view.expand(index);
                }
            }
        }
    }

    Divider {
        id: split
        vertical: true
        anchors.top: rule.bottom
        anchors.bottom: parent.bottom
        anchors.topMargin: Space.m
        anchors.left: resultsBox.right
        anchors.leftMargin: Space.m
        opacity: detail.opacity
    }

    PreviewPane {
        id: detail
        objectName: "launcherPreview"
        anchors.top: rule.bottom
        anchors.topMargin: Space.l
        anchors.bottom: parent.bottom
        anchors.left: split.right
        anchors.leftMargin: Space.l
        anchors.right: parent.right
        selection: view.detailOn ? view.current : null
        host: results
        onActionTriggered: option => view.run(view.selectedIndex, option)
        opacity: view.previewOpen ? 1 : 0
        visible: opacity > 0
        Behavior on opacity {
            enabled: Motion.enter.duration > 0
            NumberAnimation {
                duration: Motion.enter.duration
                easing.type: Motion.enter.easing
            }
        }
    }
}
