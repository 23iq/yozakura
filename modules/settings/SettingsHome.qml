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

// The home screen of the settings window: the sakura brand and one large
// search field, then a bento of live tiles (HomeTile, packed by
// HomeLayout.js: fewer columns in a smaller window) and a row of pills for
// the plain system destinations. Typing anywhere searches; the results
// (window rows only, with their current value) replace the bento; Enter
// opens the first, Esc clears. Arrows move between tiles, Enter opens one.
// Cheap by design: no page is created here, the tiles read config only.
FocusScope {
    id: home

    readonly property string query: search.text.trim()
    readonly property var index: SchemaUtil.buildSearchIndex(Categories.categories, k => I18n.t(k)).map(it => Object.assign(it, {
            "context": home.contextOf(it)
        }))
    readonly property var results: home.query.length > 0 ? SchemaUtil.search(home.index, home.query, 12, {
        "compositor": YozdService.compositorName,
        "get": SettingsStore.get
    }) : []
    property int resultIndex: 0
    readonly property var tiles: Categories.home()
    readonly property int columns: HomeLayout.columns(grid.width, Space.px(150))
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
        contentHeight: column.height + Space.xxl * 2
        boundsBehavior: Flickable.StopAtBounds
        clip: true
        ScrollBar.vertical: ScrollBar {
            policy: ScrollBar.AsNeeded
        }

        Column {
            id: column
            x: (parent.width - width) / 2
            y: Space.xl
            width: Math.min(parent.width - Space.xxl * 2, Space.px(1240))
            spacing: Space.xl

            // Brand
            Row {
                anchors.horizontalCenter: parent.horizontalCenter
                spacing: Space.m
                Image {
                    anchors.verticalCenter: parent.verticalCenter
                    width: Math.round(Type.iconSize("title") * 1.6)
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
                    font.pixelSize: Type.size("title") * 1.5
                    text: I18n.t("prefs.title")
                }
            }

            SearchField {
                id: search
                objectName: "settingsSearch"
                anchors.horizontalCenter: parent.horizontalCenter
                width: Math.min(parent.width, Space.px(620))
                boxed: true
                placeholderText: I18n.t("prefs.home.search")
                hints: ["Ctrl F"]
                clearOnEscape: true
                focus: true
                onDownPressed: home.resultIndex = Math.min(home.resultIndex + 1, home.results.length - 1)
                onUpPressed: home.resultIndex = Math.max(home.resultIndex - 1, 0)
                onAccepted: home.activateResult(home.resultIndex)
            }

            // Search results
            Column {
                id: resultsList
                objectName: "settingsSearchResults"
                readonly property var model: home.results
                readonly property int count: home.results.length
                anchors.horizontalCenter: parent.horizontalCenter
                width: Math.min(parent.width, Space.px(720))
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

            // The bento
            Item {
                id: grid
                objectName: "homeGrid"
                width: parent.width
                visible: home.query.length === 0
                readonly property real gap: Space.l
                readonly property real colW: (width - gap * (home.columns - 1)) / home.columns
                readonly property real rowH: Math.max(Space.px(132), Math.round(colW * 0.78))
                height: home.packing.rows * rowH + Math.max(0, home.packing.rows - 1) * gap

                Repeater {
                    id: tileRepeater
                    model: home.packing.cells
                    delegate: HomeTile {
                        id: tile
                        required property var modelData
                        required property int index
                        destination: home.tiles.find(t => t.id === modelData.id)
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
                                pillRow.children[0].forceActiveFocus();
                            else
                                home.focusTile(n);
                        }
                    }
                }
            }

            // Pills for the plain system destinations
            Row {
                id: pillRow
                anchors.horizontalCenter: parent.horizontalCenter
                visible: home.query.length === 0
                spacing: Space.s

                Repeater {
                    model: Categories.pills()
                    delegate: Chip {
                        id: pill
                        required property var modelData
                        objectName: "homePill:" + modelData.id
                        icon: Icons[modelData.icon] ?? ""
                        text: I18n.t(modelData.title)
                        activeFocusOnTab: true
                        highlighted: activeFocus
                        Keys.onReturnPressed: clicked()
                        Keys.onSpacePressed: clicked()
                        Keys.onUpPressed: home.focusTile(0)
                        onClicked: home.destinationOpened(modelData.id, pill)
                    }
                }
            }

            // The active preset and its drift from it (Save to current preset).
            PresetStatusFooter {
                anchors.horizontalCenter: parent.horizontalCenter
                width: Math.min(parent.width, Space.px(360))
                visible: shown && home.query.length === 0
                onActionRequested: id => home.presetAction(id)
            }
        }
    }
}
