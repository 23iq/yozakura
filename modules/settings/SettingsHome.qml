pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Controls
import QtQuick.Effects
import qs.modules.theme
import qs.modules.services
import qs.modules.components.kit
import qs.modules.settings.store
import qs.modules.settings.presets
import "schema/Categories.js" as Categories
import "SchemaUtil.js" as SchemaUtil
import "ChangesModel.js" as ChangesModel
import "HomeLayout.js" as HomeLayout
import "Ui.js" as Ui

// The home screen of the settings window: the sakura brand, one large
// search field and undo, then a bento of live tiles (HomeTile, each a
// small scene of what it opens; packed by HomeLayout.js on a 12-column grid,
// 6 in a narrow window, its rows stretched so home fills the window) and a
// row of wide status tiles for the plain system destinations
// (HomeStatusTile). Typing anywhere searches; the results
// (window rows only, with their current value) replace the bento; Enter
// opens the first, Esc clears. Arrows move between tiles, Enter opens one.
// Cheap by design: no page is created here, the tiles read config only.
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
    readonly property int columns: HomeLayout.columns(grid.width, Space.px(72))
    readonly property real margin: Space.xl
    readonly property real gap: Space.m
    readonly property var packing: HomeLayout.pack(home.tiles, home.columns)

    signal destinationOpened(string id, var tile)
    signal resultActivated(var result)
    signal presetAction(string id)

    onQueryChanged: resultIndex = 0

    // "Bar › Clock": the destination, the tab when it is not the first one,
    // then the section (the schema context is "page › section").
    function contextOf(it) {
        const g = Categories.groupOf(it.categoryId);
        if (!g)
            return it.context;
        const parts = [I18n.t(g.title)];
        const cat = Categories.byId(it.categoryId);
        if (cat && g.categories.indexOf(cat.id) > 0)
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

    function activateResult(i) {
        if (i >= 0 && i < home.results.length)
            home.resultActivated(home.results[i]);
    }

    function focusTile(i) {
        const t = tileRepeater.itemAt(i);
        if (t)
            t.forceActiveFocus();
    }

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

            // Header: the brand, the search, undo
            Item {
                id: header
                width: parent.width
                height: Space.controlL

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
                    x: Math.max(brand.width + home.gap, (parent.width - width) / 2)
                    width: Math.min(parent.width - brand.width - undoButton.width - home.gap * 2, Space.px(620))
                    boxed: true
                    placeholderText: I18n.t("prefs.home.search")
                    hints: ["Ctrl F"]
                    clearOnEscape: true
                    focus: true
                    onDownPressed: home.resultIndex = Math.min(home.resultIndex + 1, home.results.length - 1)
                    onUpPressed: home.resultIndex = Math.max(home.resultIndex - 1, 0)
                    onAccepted: home.activateResult(home.resultIndex)
                }

                IconButton {
                    id: undoButton
                    objectName: "homeUndo"
                    anchors.right: parent.right
                    anchors.verticalCenter: parent.verticalCenter
                    icon: Icons.arrowCounterClockwise
                    size: "l"
                    focusable: true
                    enabled: SettingsStore.undoStack.length > 0
                    opacity: enabled ? 1 : 0.4
                    tooltip: I18n.t("prefs.home.undo")
                    onClicked: SettingsStore.undo()
                }
            }

            // Search results
            Column {
                id: resultsList
                objectName: "settingsSearchResults"
                readonly property var model: home.results
                readonly property int count: home.results.length
                anchors.horizontalCenter: parent.horizontalCenter
                width: Math.min(parent.width, Space.px(760))
                visible: home.query.length > 0
                spacing: Space.hairline

                Repeater {
                    model: home.results
                    delegate: ListRow {
                        id: result
                        required property var modelData
                        required property int index
                        width: resultsList.width
                        title: modelData.label
                        subtitle: modelData.context
                        selected: index === home.resultIndex
                        onClicked: {
                            home.resultIndex = result.index;
                            home.activateResult(result.index);
                        }
                        leading: Component {
                            Icon {
                                icon: Icons[result.modelData.icon] ?? ""
                                tone: result.selected ? "accent" : "secondary"
                            }
                        }
                        trailing: Component {
                            KitText {
                                role: "secondary"
                                text: home.valueOf(result.modelData)
                                elide: Text.ElideRight
                            }
                        }
                    }
                }
                KitText {
                    anchors.horizontalCenter: parent.horizontalCenter
                    visible: home.results.length === 0
                    role: "secondary"
                    text: I18n.t("prefs.search.empty")
                }
            }

            // The bento: its rows stretch so it and the status tiles fill
            // the window (HomeLayout.rowUnit), never under a readable size.
            Item {
                id: grid
                objectName: "homeGrid"
                width: parent.width
                visible: home.query.length === 0
                readonly property real gap: home.gap
                readonly property real colW: (width - gap * (home.columns - 1)) / home.columns
                readonly property real avail: flick.height - home.margin * 2 - header.height - statusRow.height - home.gap * 2
                readonly property real rowH: HomeLayout.rowUnit(grid.avail, home.packing.rows, grid.gap, Space.px(20))
                height: home.packing.rows * rowH + Math.max(0, home.packing.rows - 1) * gap

                Repeater {
                    id: tileRepeater
                    model: home.packing.cells
                    delegate: HomeTile {
                        id: tile
                        required property var modelData
                        required property int index
                        destination: home.tiles.find(t => t.id === modelData.id)
                        // shadows after the first frame (18 of them cost it)
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
                            if (n === tile.index)
                                (statusRepeater.itemAt(0) as Item).forceActiveFocus();
                            else
                                home.focusTile(n);
                        }
                    }
                }
            }

            // Wide status tiles: the plain system destinations, live
            Grid {
                id: statusRow
                width: parent.width
                visible: home.query.length === 0
                readonly property int count: Categories.pills().length
                columns: home.columns >= 12 ? statusRow.count : 3
                spacing: home.gap
                readonly property real tileW: (width - spacing * (columns - 1)) / columns

                Repeater {
                    id: statusRepeater
                    model: Categories.pills()
                    delegate: HomeStatusTile {
                        id: pill
                        required property var modelData
                        required property int index
                        destination: modelData
                        shadow: home.warm
                        live: home.warm
                        width: statusRow.tileW
                        height: Space.controlL + Space.m
                        onClicked: home.destinationOpened(modelData.id, pill)
                        Keys.onUpPressed: home.focusTile(0)
                        Keys.onLeftPressed: (statusRepeater.itemAt(Math.max(0, index - 1)) as Item).forceActiveFocus()
                        Keys.onRightPressed: (statusRepeater.itemAt(Math.min(statusRow.count - 1, index + 1)) as Item).forceActiveFocus()
                    }
                }
            }

            // The active preset and its drift from it (Save to current
            // preset); by URL, after home shows (the preset service is not
            // needed for the first frame).
            Loader {
                id: footer
                anchors.horizontalCenter: parent.horizontalCenter
                width: Math.min(parent.width, Space.px(360))
                active: home.warm
                asynchronous: true
                source: Qt.resolvedUrl("presets/PresetStatusFooter.qml")
                visible: Ui.prop(footer.item, "shown") === true && home.query.length === 0
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
