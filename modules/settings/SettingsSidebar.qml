pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Controls
import QtQuick.Effects
import qs.modules.theme
import qs.modules.services
import qs.modules.components
import qs.modules.components.kit
import qs.modules.components.signatures
import qs.modules.settings.store
import qs.modules.settings.presets
import "schema/Categories.js" as Categories
import "SchemaUtil.js" as SchemaUtil

// The sakura brand, the kit SearchField and one flat list of destinations
// in labelled blocks (Categories.sidebarSections). One accent mark (tint +
// the brush signature) slides to the selected row. While a query is typed
// the list is replaced by search results over the window's rows
// (SchemaUtil.search; Up / Down move the cursor, Enter opens it).
Item {
    id: sidebar

    property string currentDestination: ""
    property bool compact: false
    readonly property string query: searchField.text.trim()
    readonly property var sections: Categories.sidebarSections()
    readonly property var index: SchemaUtil.buildSearchIndex(Categories.categories, k => I18n.t(k)).map(it => Object.assign(it, {
            "context": sidebar.contextOf(it)
        }))
    readonly property var results: query.length > 0 ? SchemaUtil.search(index, query, 30, {
        "compositor": YozdService.compositorName,
        "get": SettingsStore.get
    }) : []
    property int resultIndex: 0

    signal destinationSelected(string id)
    signal resultActivated(var result)
    signal presetAction(string id)

    onQueryChanged: resultIndex = 0

    // "Bar › Clock": the destination, then the tab when it has several.
    function contextOf(it) {
        const g = Categories.groupOf(it.categoryId);
        if (!g)
            return it.context;
        const dest = I18n.t(g.title);
        const cat = Categories.byId(it.categoryId);
        return g.categories.length > 1 && cat ? dest + " › " + I18n.t(cat.title) : dest;
    }

    function focusSearch() {
        if (compact)
            return;
        searchField.focusInput();
        searchField.field.selectAll();
    }

    function activateResult(i) {
        if (i >= 0 && i < results.length)
            resultActivated(results[i]);
    }

    // Brand: the sakura mark in the accent, then the name; the mark alone
    // when compact.
    Item {
        id: brand
        width: parent.width
        height: Space.rowHeight + Space.l

        Image {
            id: mark
            x: sidebar.compact ? (parent.width - width) / 2 : Space.m + Look.rowInset
            anchors.verticalCenter: parent.verticalCenter
            width: Math.round(Type.iconSize("title") * 1.3)
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
            visible: !sidebar.compact
            anchors.left: mark.right
            anchors.leftMargin: Space.m
            anchors.verticalCenter: parent.verticalCenter
            role: "title"
            text: I18n.t("prefs.title")
        }
    }

    SearchField {
        id: searchField
        objectName: "settingsSearch"
        anchors.top: brand.bottom
        x: Space.m
        width: parent.width - Space.m * 2
        height: sidebar.compact ? 0 : implicitHeight
        visible: !sidebar.compact
        placeholderText: I18n.t("prefs.search")
        hints: ["Ctrl F"]
        boxed: true
        clearOnEscape: false
        onDownPressed: sidebar.resultIndex = Math.min(sidebar.resultIndex + 1, sidebar.results.length - 1)
        onUpPressed: sidebar.resultIndex = Math.max(sidebar.resultIndex - 1, 0)
        onAccepted: sidebar.activateResult(sidebar.resultIndex)
        onEscapePressed: {
            if (text !== "")
                clear();
            else
                field.focus = false;
        }
    }

    Flickable {
        id: nav
        objectName: "settingsNav"
        anchors.top: searchField.bottom
        anchors.topMargin: Space.m
        anchors.bottom: presetFooter.top
        width: parent.width
        visible: sidebar.query.length === 0
        contentHeight: navColumn.implicitHeight + Space.l
        clip: true
        boundsBehavior: Flickable.StopAtBounds
        ScrollBar.vertical: ScrollBar {
            policy: ScrollBar.AsNeeded
        }

        // The selected row's NavItem (set by the rows themselves).
        property Item current: null
        function place() {
            if (!nav.current)
                return;
            const p = nav.current.mapToItem(navColumn, 0, 0);
            selection.targetY = p.y;
            selection.height = nav.current.height;
        }

        // The selection mark: an accent tint over the brush signature,
        // gliding from the previous row to the new one.
        StyledRect {
            id: selection
            objectName: "navSelection"
            property real targetY: 0
            x: navColumn.x
            y: navColumn.y + targetY
            width: navColumn.width
            visible: nav.current !== null
            variant: "primary"
            backgroundOpacity: Look.activeTint
            enableBorder: false
            enableShadow: false
            radius: Look.chipRadius(height)

            BrushHighlight {
                spread: Space.xs
            }

            Behavior on targetY {
                enabled: Motion.glide.duration > 0
                NumberAnimation {
                    duration: Motion.glide.duration
                    easing.type: Motion.glide.easing
                }
            }
        }

        Column {
            id: navColumn
            x: Space.m
            width: parent.width - Space.m * 2
            spacing: Space.m
            onHeightChanged: nav.place()

            Repeater {
                model: sidebar.sections

                delegate: Column {
                    id: block
                    required property var modelData
                    width: navColumn.width
                    spacing: Space.hairline

                    SectionLabel {
                        width: parent.width
                        visible: !sidebar.compact
                        text: I18n.t(block.modelData.title)
                    }

                    Repeater {
                        model: block.modelData.groups

                        delegate: NavItem {
                            id: item
                            required property var modelData
                            width: block.width
                            destination: modelData
                            compact: sidebar.compact
                            selected: modelData.id === sidebar.currentDestination
                            onSelectedChanged: if (selected) {
                                nav.current = item;
                                Qt.callLater(nav.place);
                            }
                            Component.onCompleted: if (selected) {
                                nav.current = item;
                                Qt.callLater(nav.place);
                            }
                            onClicked: sidebar.destinationSelected(modelData.id)
                        }
                    }
                }
            }
        }
    }

    // Search results
    ListView {
        id: resultsView
        objectName: "settingsSearchResults"
        anchors.top: searchField.bottom
        anchors.topMargin: Space.m
        anchors.bottom: presetFooter.top
        x: Space.m
        width: parent.width - Space.m * 2
        visible: sidebar.query.length > 0
        clip: true
        spacing: Space.hairline
        model: sidebar.results
        currentIndex: sidebar.resultIndex
        boundsBehavior: Flickable.StopAtBounds

        delegate: ListRow {
            id: result
            required property var modelData
            required property int index
            width: resultsView.width
            title: modelData.label
            subtitle: modelData.context
            selected: index === sidebar.resultIndex
            onClicked: {
                sidebar.resultIndex = result.index;
                sidebar.activateResult(result.index);
            }
            leading: Component {
                Icon {
                    icon: Icons[result.modelData.icon] ?? ""
                    tone: result.selected ? "accent" : "secondary"
                }
            }
        }

        KitText {
            anchors.centerIn: parent
            visible: sidebar.results.length === 0
            role: "secondary"
            text: I18n.t("prefs.search.empty")
        }
    }

    // The active preset and its drift from it (Save to current preset).
    PresetStatusFooter {
        id: presetFooter
        anchors.bottom: parent.bottom
        width: parent.width
        compact: sidebar.compact
        onActionRequested: id => sidebar.presetAction(id)
    }
}
