pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Controls
import qs.modules.services
import qs.modules.components.kit
import qs.modules.keybinds
import "BindModel.js" as BindModel

// Cheatsheet content: the heading is the search field (title role,
// search-as-you-type), then the bind groups as kit Groups laid out in
// balanced columns. Up/Down pick a row, Return edits it in the settings;
// Esc (or the Esc key hint) closes.
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
    readonly property int gap: Look.groupBoxed ? Look.groupGap : Space.xxl
    readonly property int minColumnWidth: Math.round(Type.size("body") * 26)

    onQueryChanged: selectedIndex = query !== "" && ordered.length > 0 ? 0 : -1

    function focusSearch() {
        search.focusInput();
    }

    function move(delta) {
        if (!ordered.length)
            return;
        selectedIndex = Math.max(0, Math.min(ordered.length - 1, selectedIndex + delta));
    }

    // Header: the search field is the title; the key hints sit at the right.
    Item {
        id: header
        width: parent.width
        height: search.implicitHeight

        CheatsheetSearch {
            id: search
            objectName: "cheatsheetSearch"
            anchors.left: parent.left
            anchors.right: hints.left
            anchors.rightMargin: Space.xl
            anchors.verticalCenter: parent.verticalCenter
            placeholderText: I18n.t("binds.cheatsheet.title")
            onSearchTextChanged: t => root.query = t
            onEscapePressed: root.closeRequested()
            onDownPressed: root.move(1)
            onUpPressed: root.move(-1)
            onAccepted: {
                if (root.selectedUid !== "")
                    root.editRequested(root.selectedUid);
            }
        }

        Row {
            id: hints
            anchors.right: parent.right
            anchors.verticalCenter: parent.verticalCenter
            spacing: Space.m

            KitText {
                anchors.verticalCenter: parent.verticalCenter
                role: "caption"
                text: I18n.t("binds.cheatsheet.hint")
            }

            KeyHint {
                id: escHint
                anchors.verticalCenter: parent.verticalCenter
                text: "Esc"
                border.color: closeArea.containsMouse ? Type.text : Qt.rgba(Type.muted.r, Type.muted.g, Type.muted.b, 0.5)

                MouseArea {
                    id: closeArea
                    anchors.fill: parent
                    anchors.margins: -Space.s
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: root.closeRequested()
                }
            }
        }
    }

    Divider {
        id: rule
        anchors.top: header.bottom
        anchors.topMargin: Space.m
        width: parent.width
    }

    Flickable {
        id: flick
        anchors.top: rule.bottom
        anchors.topMargin: Space.xl
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
                    spacing: Look.groupGap

                    Repeater {
                        model: parent.modelData
                        delegate: CheatsheetGroup {
                            required property var modelData
                            required property int index
                            width: columnsRow.colWidth
                            model: modelData
                            divider: index > 0
                            selectedUid: root.selectedUid
                            onEditRequested: uid => root.editRequested(uid)
                        }
                    }
                }
            }
        }

        KitText {
            anchors.horizontalCenter: parent.horizontalCenter
            y: Space.xxl
            visible: root.filtered.length === 0
            role: "secondary"
            text: I18n.t("binds.no_matches")
        }
    }
}
