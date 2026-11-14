pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Controls
import QtQuick.Effects
import qs.modules.theme
import qs.modules.services
import qs.modules.components.kit
import qs.modules.settings.store
import qs.modules.settings.home
import "schema/Categories.js" as Categories
import "SchemaUtil.js" as SchemaUtil
import "ChangesModel.js" as ChangesModel
import "HomeLayout.js" as HomeLayout
import "Ui.js" as Ui

// The home screen of the settings window: a header (the sakura brand, the
// search field on the grid's columns, a History button), then the nine
// destinations as a bento whose tile sizes follow their weight (HomeTile:
// Screen and Look a live scene, the others their icon; each with its name
// and one live status line; fewer columns in a narrow window, the rows
// stretched so home fills it). Typing anywhere searches: the bento gives way
// to the results (a cross-fade with a short glide), a command palette of
// window rows with their breadcrumb and current value (HomeResults); Up /
// Down pick, Enter opens the picked one (it flashes), Esc clears. Arrows
// move between tiles, Enter opens one. Cheap by design: no page is created
// here, the tiles read config only.
FocusScope {
    id: home

    readonly property string query: search.text.trim()
    // The search index of every window row: built on first need (the first
    // query, or `wantIndex`), not at open (it walks every schema page).
    property bool wantIndex: false
    readonly property bool indexNeeded: home.wantIndex || home.query.length > 0
    property var index: []
    onIndexNeededChanged: home.buildIndex()
    // another language: the labels change, build it again
    readonly property int language: I18n.revision || 0
    onLanguageChanged: {
        home.index = [];
        home.buildIndex();
    }
    function buildIndex() {
        if (!home.indexNeeded || home.index.length > 0)
            return;
        home.index = SchemaUtil.buildSearchIndex(Categories.categories, k => I18n.t(k)).map(it => Object.assign(it, {
                "context": home.contextOf(it)
            }));
    }
    readonly property var results: home.query.length > 0 ? SchemaUtil.search(home.index, home.query, 12, {
        "compositor": YozdService.compositorName,
        "get": SettingsStore.get
    }) : []
    property int resultIndex: 0
    // 0 = the bento, 1 = the results (animated: the two cross-fade)
    property real searching: home.query.length > 0 ? 1 : 0
    Behavior on searching {
        enabled: Motion.glide.duration > 0
        NumberAnimation {
            duration: Motion.glide.duration
            easing.type: Motion.glide.easing
        }
    }
    // Once home has shown its first frame: what that frame does not need
    // (tile pictures and status lines, the preset footer) fills in then.
    property bool warm: false
    // Tile scenes come in one per frame after that (spreads their cost).
    property int scenes: 0
    FrameAnimation {
        running: home.warm && home.scenes < home.packing.cells.length
        onTriggered: home.scenes++
    }
    Connections {
        target: home.warm ? null : home.Window.window
        function onFrameSwapped() {
            home.warm = true;
        }
    }
    // no window to show in (a test, a render): at once
    Component.onCompleted: {
        if (!home.Window.window)
            Qt.callLater(() => home.warm = true);
    }
    readonly property var tiles: Categories.home()
    // six columns (tiles sized by weight, Categories.HOME), four or two in
    // a narrower window (with hysteresis)
    property int columns: 6
    readonly property real margin: Space.xl
    readonly property real gap: Look.screenGap
    readonly property var packing: HomeLayout.pack(home.tiles, home.columns)

    // A tile (its destination) opens, from the item it grows out of.
    signal destinationOpened(string id, var tile)
    // A search result opens, from its row.
    signal resultActivated(var result, var row)
    signal presetAction(string id)
    signal historyRequested(var button)

    onQueryChanged: resultIndex = 0

    // "Screen › Bar › Clock": the destination, its tab (when it has several),
    // then the section (the schema context is "page › section").
    function contextOf(it) {
        const g = Categories.groupOf(it.categoryId);
        if (!g)
            return it.context;
        const parts = [I18n.t(g.title)];
        const cat = Categories.byId(it.categoryId);
        if (cat && g.categories.length > 1)
            parts.push(I18n.t(cat.title));
        return parts.concat(String(it.context || "").split(" › ").slice(1)).join(" › ");
    }

    // The current value of a result's setting, as a short text.
    function valueOf(it) {
        const e = it.key ? SettingsStore.entryByKey[it.key] : null;
        if (!e)
            return "";
        const v = SettingsStore.get(it.key);
        return typeof v === "object" ? "" : ChangesModel.describe(e, v, k => I18n.t(k));
    }

    function focusSearch() {
        search.focusInput();
        search.field.selectAll();
    }

    function clearSearch() {
        search.text = "";
    }

    function activateResult(i) {
        if (i < 0 || i >= home.results.length)
            return;
        resultsList.flash(i);
        home.resultActivated(home.results[i], resultsList.rowAt(i));
    }

    function focusTile(i) {
        const t = tileRepeater.itemAt(i);
        if (t)
            t.forceActiveFocus();
    }

    // The tile of a destination (the shell grows a page out of it and
    // shrinks it back into it), null while the bento is not what home shows.
    function tileFor(destinationId) {
        if (home.query.length > 0)
            return null;
        for (let i = 0; i < tileRepeater.count; i++) {
            const t = tileRepeater.itemAt(i);
            if (t && t.destination && t.destination.id === destinationId)
                return t;
        }
        return null;
    }

    // Keeps the picked result in view.
    onResultIndexChanged: Qt.callLater(() => {
        const r = resultsList.rowAt(home.resultIndex);
        if (!r)
            return;
        const p = r.mapToItem(flick.contentItem, 0, 0);
        if (p.y < flick.contentY)
            flick.contentY = Math.max(0, p.y - home.gap);
        else if (p.y + r.height > flick.contentY + flick.height)
            flick.contentY = p.y + r.height - flick.height + home.gap;
    })

    // Typing anywhere goes to the search field.
    Keys.onPressed: event => {
        if (event.text && event.text.length === 1 && event.text >= " " && !(event.modifiers & (Qt.ControlModifier | Qt.AltModifier))) {
            search.focusInput();
            search.text = search.text + event.text;
            event.accepted = true;
        }
    }

    Flickable {
        id: flick
        anchors.fill: parent
        contentWidth: width
        contentHeight: column.height + home.margin * 2
        boundsBehavior: Flickable.StopAtBounds
        clip: true
        ScrollBar.vertical: ScrollBar {
            policy: ScrollBar.AsNeeded
        }

        Column {
            id: column
            x: home.margin
            y: home.margin
            width: flick.width - home.margin * 2
            spacing: home.gap

            // Header: the brand, the search on the grid's columns, History
            Item {
                id: header
                width: parent.width
                height: Space.controlL
                // the field's place on the columns (null: between brand and button)
                readonly property var span: HomeLayout.searchSpan(home.packing.cells, home.columns, grid.colW, grid.gap, brand.width)

                Row {
                    id: brand
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: Space.m
                    Image {
                        anchors.verticalCenter: parent.verticalCenter
                        width: Math.round(Type.iconSize("title") * 1.5)
                        height: width
                        source: Qt.resolvedUrl("../../assets/yozakura/yozakura-icon.svg")
                        sourceSize.width: width * 2
                        sourceSize.height: height * 2
                        fillMode: Image.PreserveAspectFit
                        mipmap: true
                        layer.enabled: true
                        layer.effect: MultiEffect {
                            brightness: 1.0
                            colorization: 1.0
                            colorizationColor: Type.accent
                        }
                    }
                    KitText {
                        anchors.verticalCenter: parent.verticalCenter
                        role: "title"
                        font.pixelSize: Math.round(Type.size("title") * 1.25)
                        text: I18n.t("prefs.title")
                    }
                }

                SearchField {
                    id: search
                    objectName: "settingsSearch"
                    anchors.verticalCenter: parent.verticalCenter
                    x: header.span ? header.span.x : brand.width + home.gap
                    width: header.span ? header.span.width : Math.max(0, history.x - home.gap - x)
                    boxed: true
                    onWindow: true
                    // the question, or one word where the field is too narrow
                    // for it (never a cut sentence)
                    placeholderText: promptMetrics.advanceWidth(I18n.t("prefs.home.search")) * 1.3 + Space.px(130) < width ? I18n.t("prefs.home.search") : I18n.t("prefs.home.search_short")
                    FontMetrics {
                        id: promptMetrics
                        font.family: Type.family("body")
                        font.pixelSize: Type.size("body")
                    }
                    hints: ["Ctrl F"]
                    clearOnEscape: true
                    focus: true
                    onDownPressed: home.resultIndex = Math.min(home.resultIndex + 1, home.results.length - 1)
                    onUpPressed: home.resultIndex = Math.max(home.resultIndex - 1, 0)
                    onAccepted: home.activateResult(home.resultIndex)
                }

                // what you changed (the Changes tab: every change, a way
                // back for each), named, not a bare arrow
                PillButton {
                    id: history
                    objectName: "homeHistory"
                    anchors.right: parent.right
                    anchors.verticalCenter: parent.verticalCenter
                    icon: "clockCounterClockwise"
                    text: I18n.t("prefs.home.history")
                    kind: "ghost"
                    onClicked: home.historyRequested(history)
                    Tooltip {
                        text: I18n.t("prefs.home.history.tip")
                        shown: historyHover.hovered
                    }
                    HoverHandler {
                        id: historyHover
                    }
                }
            }

            // The bento and the results in one place: one gives way to the
            // other (a cross-fade, the incoming one gliding a little).
            Item {
                id: stage
                width: parent.width
                height: Math.max(grid.height * (1 - home.searching), resultsList.implicitHeight * home.searching)

                // The bento: its rows stretch so it and the status tiles
                // fill the window (HomeLayout.rowUnit), never under a
                // readable size.
                Item {
                    id: grid
                    objectName: "homeGrid"
                    onWidthChanged: home.columns = HomeLayout.columns(grid.width, Space.px(150), home.columns)
                    width: parent.width
                    visible: home.searching < 1
                    enabled: home.query.length === 0
                    opacity: 1 - home.searching
                    y: -Space.l * home.searching
                    readonly property real gap: home.gap
                    readonly property real colW: (width - gap * (home.columns - 1)) / home.columns
                    readonly property real avail: flick.height - home.margin * 2 - header.height - home.gap
                    readonly property real rowH: HomeLayout.rowUnit(grid.avail, home.packing.rows, grid.gap, Space.px(118))
                    height: home.packing.rows * rowH + Math.max(0, home.packing.rows - 1) * gap

                    Repeater {
                        id: tileRepeater
                        model: home.packing.cells
                        delegate: HomeTile {
                            id: tile
                            required property var modelData
                            required property int index
                            destination: home.tiles.find(t => t.id === modelData.id)
                            // shadows after the first frame (18 of them cost
                            // it); they fade in (kit Card)
                            shadow: home.warm
                            live: home.warm && tile.index < home.scenes
                            x: modelData.col * (grid.colW + grid.gap)
                            y: modelData.row * (grid.rowH + grid.gap)
                            width: modelData.w * grid.colW + (modelData.w - 1) * grid.gap
                            height: modelData.h * grid.rowH + (modelData.h - 1) * grid.gap
                            onClicked: home.destinationOpened(modelData.id, tile)
                            Keys.onLeftPressed: home.focusTile(HomeLayout.neighbour(home.packing.cells, tile.index, "left"))
                            Keys.onRightPressed: home.focusTile(HomeLayout.neighbour(home.packing.cells, tile.index, "right"))
                            Keys.onUpPressed: {
                                const n = HomeLayout.neighbour(home.packing.cells, tile.index, "up");
                                if (n === tile.index)
                                    home.focusSearch();
                                else
                                    home.focusTile(n);
                            }
                            Keys.onDownPressed: {
                                const n = HomeLayout.neighbour(home.packing.cells, tile.index, "down");
                                if (n !== tile.index)
                                    home.focusTile(n);
                            }
                        }
                    }
                }

                // The results, under the field and on its columns.
                HomeResults {
                    id: resultsList
                    x: search.x
                    width: search.width
                    height: implicitHeight
                    visible: home.searching > 0
                    opacity: home.searching
                    y: Space.l * (1 - home.searching)
                    results: home.results
                    selectedIndex: home.resultIndex
                    valueOf: it => home.valueOf(it)
                    onActivated: (i, row) => {
                        home.resultIndex = i;
                        home.activateResult(i);
                    }
                }
            }

            // The active preset and its drift from it (Save to current
            // preset); by URL, after home shows (the preset service is not
            // needed for the first frame); it fades in.
            Loader {
                id: footer
                anchors.horizontalCenter: parent.horizontalCenter
                width: Math.min(parent.width, Space.px(360))
                active: home.warm
                asynchronous: true
                source: Qt.resolvedUrl("presets/PresetStatusFooter.qml")
                readonly property bool shown: Ui.prop(footer.item, "shown") === true && home.query.length === 0
                visible: footer.opacity > 0
                opacity: footer.shown ? 1 : 0
                Behavior on opacity {
                    enabled: Motion.glide.duration > 0
                    NumberAnimation {
                        duration: Motion.glide.duration
                        easing.type: Motion.glide.easing
                    }
                }
                Connections {
                    target: footer.item
                    ignoreUnknownSignals: true
                    function onActionRequested(id) {
                        home.presetAction(id);
                    }
                }
            }
        }
    }
}
