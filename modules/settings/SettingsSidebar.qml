pragma ComponentBehavior: Bound

import QtQuick
import qs.modules.theme
import qs.modules.services
import qs.config
import "schema/Categories.js" as Categories
import "SchemaUtil.js" as SchemaUtil
import "Ui.js" as Ui

// Brand, search and the element page tree (SidebarTree). While a query is typed the list
// is replaced by schema-generated search results.
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
        searchField.forceActiveFocus();
        searchField.selectAll();
    }

    function activateResult(i) {
        if (i >= 0 && i < results.length)
            resultActivated(results[i]);
    }

    // Brand
    Item {
        id: brand
        width: parent.width
        height: 78

        Row {
            x: sidebar.compact ? (parent.width - width) / 2 : 22
            anchors.verticalCenter: parent.verticalCenter
            spacing: 12

            Rectangle {
                width: 38
                height: 38
                radius: Math.min(Styling.radius(2), 14)
                gradient: Gradient {
                    orientation: Gradient.Horizontal
                    GradientStop {
                        position: 0
                        color: Colors.primary
                    }
                    GradientStop {
                        position: 1
                        color: Colors.tertiary
                    }
                }
                Text {
                    anchors.centerIn: parent
                    text: "桜"
                    font.pixelSize: 20
                    font.weight: Font.Bold
                    color: Colors.overPrimary
                }
            }
            Column {
                visible: !sidebar.compact
                anchors.verticalCenter: parent.verticalCenter
                spacing: 0
                Text {
                    text: "Yozakura"
                    font.family: Config.theme.font
                    font.pixelSize: Styling.fontSize(3)
                    font.weight: Font.Bold
                    color: Colors.overBackground
                }
                Text {
                    text: "夜桜 · " + I18n.t("prefs.title")
                    font.family: Config.theme.font
                    font.pixelSize: Styling.fontSize(-2)
                    color: Colors.overSurfaceVariant
                }
            }
        }
    }

    // Search
    Item {
        id: search
        anchors.top: brand.bottom
        x: 14
        width: parent.width - 28
        height: sidebar.compact ? 0 : 40
        visible: !sidebar.compact

        Rectangle {
            anchors.fill: parent
            radius: height / 2
            color: searchField.activeFocus ? Ui.alpha(Colors.overBackground, 0.1) : Ui.alpha(Colors.overBackground, 0.06)
            border.width: searchField.activeFocus ? 2 : 0
            border.color: Colors.primary
        }
        Text {
            id: glass
            anchors.left: parent.left
            anchors.leftMargin: 14
            anchors.verticalCenter: parent.verticalCenter
            text: Icons.search
            font.family: Icons.font
            font.pixelSize: 15
            color: Colors.overSurfaceVariant
        }
        TextInput {
            id: searchField
            objectName: "settingsSearch"
            anchors.left: glass.right
            anchors.leftMargin: 10
            anchors.right: clearBtn.left
            anchors.rightMargin: 6
            anchors.verticalCenter: parent.verticalCenter
            font.family: Config.theme.font
            font.pixelSize: Styling.fontSize(-1)
            color: Colors.overBackground
            selectionColor: Ui.alpha(Colors.primary, 0.4)
            clip: true
            Keys.onDownPressed: sidebar.resultIndex = Math.min(sidebar.resultIndex + 1, sidebar.results.length - 1)
            Keys.onUpPressed: sidebar.resultIndex = Math.max(sidebar.resultIndex - 1, 0)
            Keys.onReturnPressed: sidebar.activateResult(sidebar.resultIndex)
            Keys.onEnterPressed: sidebar.activateResult(sidebar.resultIndex)
            Keys.onEscapePressed: {
                if (text !== "")
                    text = "";
                else
                    focus = false;
            }

            Text {
                anchors.fill: parent
                verticalAlignment: Text.AlignVCenter
                text: I18n.t("prefs.search")
                font: searchField.font
                color: Ui.alpha(Colors.overSurfaceVariant, 0.75)
                visible: searchField.text === ""
                elide: Text.ElideRight
            }
        }
        Text {
            id: clearBtn
            anchors.right: parent.right
            anchors.rightMargin: 14
            anchors.verticalCenter: parent.verticalCenter
            text: searchField.text !== "" ? Icons.cancel : "Ctrl F"
            font.family: searchField.text !== "" ? Icons.font : Config.theme.font
            font.pixelSize: searchField.text !== "" ? 13 : Styling.fontSize(-3)
            color: Ui.alpha(Colors.overSurfaceVariant, 0.7)
            MouseArea {
                anchors.fill: parent
                anchors.margins: -6
                enabled: searchField.text !== ""
                cursorShape: Qt.PointingHandCursor
                onClicked: searchField.text = ""
            }
        }
    }

    // Element pages
    SidebarTree {
        anchors.top: search.bottom
        anchors.topMargin: 14
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
        anchors.top: search.bottom
        anchors.topMargin: 14
        anchors.bottom: parent.bottom
        x: 10
        width: parent.width - 20
        visible: sidebar.query.length > 0
        clip: true
        spacing: 2
        model: sidebar.results
        currentIndex: sidebar.resultIndex
        boundsBehavior: Flickable.StopAtBounds

        delegate: Item {
            id: result
            required property var modelData
            required property int index
            readonly property bool current: index === sidebar.resultIndex
            width: resultsView.width
            height: 54

            Rectangle {
                anchors.fill: parent
                radius: Math.min(Styling.radius(0), 14)
                color: result.current ? Ui.alpha(Colors.primary, 0.16) : (resultArea.containsMouse ? Ui.alpha(Colors.overBackground, 0.1) : "transparent")
            }
            Text {
                id: resultIcon
                x: 14
                anchors.verticalCenter: parent.verticalCenter
                text: Icons[result.modelData.icon] ?? ""
                font.family: Icons.font
                font.pixelSize: 17
                color: result.current ? Colors.primary : Colors.overSurfaceVariant
            }
            Column {
                anchors.left: resultIcon.right
                anchors.leftMargin: 12
                anchors.right: parent.right
                anchors.rightMargin: 10
                anchors.verticalCenter: parent.verticalCenter
                spacing: 1
                Text {
                    width: parent.width
                    text: result.modelData.label
                    font.family: Config.theme.font
                    font.pixelSize: Styling.fontSize(-1)
                    font.weight: Font.DemiBold
                    color: Colors.overBackground
                    elide: Text.ElideRight
                }
                Text {
                    width: parent.width
                    visible: text !== ""
                    text: result.modelData.context
                    font.family: Config.theme.font
                    font.pixelSize: Styling.fontSize(-3)
                    color: Colors.overSurfaceVariant
                    elide: Text.ElideRight
                }
            }
            MouseArea {
                id: resultArea
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: {
                    sidebar.resultIndex = result.index;
                    sidebar.activateResult(result.index);
                }
            }
        }

        Text {
            anchors.centerIn: parent
            visible: sidebar.results.length === 0
            text: I18n.t("prefs.search.empty")
            font.family: Config.theme.font
            font.pixelSize: Styling.fontSize(-1)
            color: Colors.overSurfaceVariant
        }
    }
}
