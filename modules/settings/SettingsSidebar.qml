pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Effects
import qs.modules.theme
import qs.modules.services
import qs.modules.components.kit
import "schema/Categories.js" as Categories
import "SchemaUtil.js" as SchemaUtil

// Brand, the kit SearchField and the element page tree (SidebarTree). While
// a query is typed the tree is replaced by schema-generated search results
// (ListRows; Up / Down move the cursor, Enter opens it).
Item {
    id: sidebar

    property string currentCategory: ""
    property bool compact: false
    readonly property string query: searchField.text.trim()
    readonly property var index: SchemaUtil.buildSearchIndex(Categories.categories, k => I18n.t(k))
    readonly property var results: query.length > 0 ? SchemaUtil.search(index, query, 30) : []
    property int resultIndex: 0

    signal categorySelected(string id)
    signal resultActivated(var result)

    onQueryChanged: resultIndex = 0

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

    // Brand
    Item {
        id: brand
        width: parent.width
        height: Space.rowHeight + Space.l

        // The sakura mark in the accent, then the name; the mark alone when compact.
        Image {
            id: mark
            x: sidebar.compact ? (parent.width - width) / 2 : Space.l + Space.s
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
        Column {
            visible: !sidebar.compact
            anchors.left: mark.right
            anchors.leftMargin: Space.m
            anchors.verticalCenter: parent.verticalCenter
            spacing: 0
            KitText {
                role: "title"
                text: "Yozakura"
            }
            KitText {
                role: "caption"
                text: I18n.t("prefs.title")
            }
        }
    }

    // Search
    SearchField {
        id: searchField
        objectName: "settingsSearch"
        anchors.top: brand.bottom
        x: Space.l + Space.s
        width: parent.width - x - Space.l
        height: sidebar.compact ? 0 : implicitHeight
        visible: !sidebar.compact
        placeholderText: I18n.t("prefs.search")
        hints: ["Ctrl F"]
        rule: true
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

    // Element pages
    SidebarTree {
        anchors.top: searchField.bottom
        anchors.topMargin: Space.l
        anchors.bottom: parent.bottom
        width: parent.width
        visible: sidebar.query.length === 0
        currentCategory: sidebar.currentCategory
        compact: sidebar.compact
        onCategorySelected: id => sidebar.categorySelected(id)
    }

    // Search results
    ListView {
        id: resultsView
        objectName: "settingsSearchResults"
        anchors.top: searchField.bottom
        anchors.topMargin: Space.l
        anchors.bottom: parent.bottom
        x: Space.m
        width: parent.width - Space.m * 2
        visible: sidebar.query.length > 0
        clip: true
        spacing: Space.xs / 2
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
                Text {
                    text: Icons[result.modelData.icon] ?? ""
                    font.family: Icons.font
                    font.pixelSize: Type.iconSize("body")
                    color: result.selected ? Type.accent : Type.secondary
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
}
