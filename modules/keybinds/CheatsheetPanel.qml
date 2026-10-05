pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Controls
import qs.modules.theme
import qs.modules.components
import qs.modules.services
import qs.config
import qs.modules.keybinds
import "BindModel.js" as BindModel

// Cheatsheet content: title, search-as-you-type and the bind groups laid
// out in balanced columns. Up/Down pick a row, Return edits it in the
// settings; Esc is handled by the window.
Item {
    id: root

    property string query: ""
    property int selectedIndex: -1
    signal closeRequested
    signal editRequested(string uid)

    readonly property var filtered: BindModel.mergeRows(BindModel.filterRows(KeybindsStore.rows, query, KeybindsStore.tr), KeybindsStore.tr)
    readonly property var groups: BindModel.grouped(filtered, false)
    // Rows in visual order (column by column) for keyboard selection.
    readonly property var columnModel: BindModel.columns(groups, Math.max(1, Math.floor((width + gap) / (minColumnWidth + gap))))
    readonly property var ordered: columnModel.reduce((acc, col) => acc.concat(col.reduce((a, g) => a.concat(g.rows), [])), [])
    readonly property string selectedUid: selectedIndex >= 0 && selectedIndex < ordered.length ? ordered[selectedIndex].uid : ""
    readonly property int gap: 14
    readonly property int minColumnWidth: Math.round(Styling.fontSize(0) * 26)

    onQueryChanged: selectedIndex = query !== "" && ordered.length > 0 ? 0 : -1

    function focusSearch() {
        search.focusInput();
    }

    function move(delta) {
        if (!ordered.length)
            return;
        selectedIndex = Math.max(0, Math.min(ordered.length - 1, selectedIndex + delta));
    }

    // Header
    Item {
        id: header
        width: parent.width
        height: search.implicitHeight

        Row {
            id: titleRow
            anchors.left: parent.left
            anchors.verticalCenter: parent.verticalCenter
            spacing: 12

            Keycap {
                anchors.verticalCenter: parent.verticalCenter
                cap: ({
                        "kind": "super",
                        "text": "",
                        "icon": ""
                    })
                sizeOffset: 4
            }
            Column {
                anchors.verticalCenter: parent.verticalCenter
                Text {
                    text: I18n.t("binds.cheatsheet.title")
                    font.family: Config.theme.font
                    font.pixelSize: Styling.fontSize(6)
                    font.weight: Font.Bold
                    color: Colors.overBackground
                }
                Text {
                    text: I18n.t("binds.cheatsheet.hint")
                    font.family: Config.theme.font
                    font.pixelSize: Styling.fontSize(-2)
                    color: Colors.overSurfaceVariant
                }
            }
        }

        SearchInput {
            id: search
            objectName: "cheatsheetSearch"
            anchors.right: closeButton.left
            anchors.rightMargin: 10
            anchors.verticalCenter: parent.verticalCenter
            width: Math.min(420, Math.max(220, parent.width - titleRow.width - closeButton.width - 40))
            iconText: Icons.search
            placeholderText: I18n.t("binds.search_placeholder")
            clearOnEscape: false
            onSearchTextChanged: t => root.query = t
            onEscapePressed: root.closeRequested()
            onDownPressed: root.move(1)
            onUpPressed: root.move(-1)
            onAccepted: {
                if (root.selectedUid !== "")
                    root.editRequested(root.selectedUid);
            }
        }

        Item {
            id: closeButton
            anchors.right: parent.right
            anchors.verticalCenter: parent.verticalCenter
            width: escCap.implicitWidth
            height: escCap.implicitHeight

            Keycap {
                id: escCap
                cap: ({
                        "kind": "text",
                        "text": "Esc",
                        "icon": ""
                    })
                tone: closeArea.containsMouse ? "accent" : "normal"
            }
            MouseArea {
                id: closeArea
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: root.closeRequested()
            }
        }
    }

    Flickable {
        id: flick
        anchors.top: header.bottom
        anchors.topMargin: 20
        anchors.bottom: parent.bottom
        width: parent.width
        contentWidth: width
        contentHeight: columnsRow.implicitHeight
        clip: true
        boundsBehavior: Flickable.StopAtBounds
        ScrollBar.vertical: ScrollBar {
            policy: ScrollBar.AsNeeded
        }

        Row {
            id: columnsRow
            // Few groups (search) do not stretch across a wide screen.
            readonly property real colWidth: Math.min(root.minColumnWidth * 1.5, (flick.width - root.gap * (root.columnModel.length - 1)) / Math.max(1, root.columnModel.length))
            x: Math.max(0, (flick.width - width) / 2)
            spacing: root.gap

            Repeater {
                model: root.columnModel
                delegate: Column {
                    required property var modelData
                    width: columnsRow.colWidth
                    spacing: root.gap

                    Repeater {
                        model: parent.modelData
                        delegate: CheatsheetGroup {
                            required property var modelData
                            width: columnsRow.colWidth
                            model: modelData
                            selectedUid: root.selectedUid
                            onEditRequested: uid => root.editRequested(uid)
                        }
                    }
                }
            }
        }

        Text {
            anchors.horizontalCenter: parent.horizontalCenter
            y: 40
            visible: root.filtered.length === 0
            text: I18n.t("binds.no_matches")
            font.family: Config.theme.font
            font.pixelSize: Styling.fontSize(1)
            color: Colors.overSurfaceVariant
        }
    }
}
