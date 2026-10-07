import QtQuick
import QtQuick.Layouts
import qs.modules.components.kit
import qs.modules.services

// Clipboard history tab (launcher prefix / dashboard). State and actions are
// in ClipboardTabBase.qml, the parts of the view in the Clipboard*.qml
// components next to it, pure helpers in ClipboardView.js.
ClipboardTabBase {
    id: root

    listView: historyList.view
    onFocusSearchRequested: searchInput.focusInput()

    Keys.onEscapePressed: {
        if (root.deleteMode) {
            root.cancelDeleteMode();
        } else if (root.aliasMode) {
            root.cancelAliasMode();
        } else {
            Visibilities.setActiveModule("");
        }
    }

    // Clicks on empty space leave delete mode
    MouseArea {
        anchors.fill: parent
        enabled: root.deleteMode
        z: -10

        onClicked: {
            if (root.deleteMode) {
                root.cancelDeleteMode();
            }
        }
    }

    RowLayout {
        id: mainLayout
        anchors.fill: parent
        spacing: Space.l

        // Left column: search + list
        Item {
            Layout.preferredWidth: root.leftPanelWidth
            Layout.fillHeight: true

            ClipboardSearchBar {
                id: searchInput
                tab: root
                width: parent.width
                anchors.top: parent.top
            }

            ClipboardList {
                id: historyList
                tab: root
                model: root.historyModel
                width: parent.width
                anchors.top: searchInput.bottom
                anchors.bottom: parent.bottom
                anchors.topMargin: Space.s
            }
        }

        Divider {
            vertical: true
            Layout.fillHeight: true
        }

        // Preview panel (full height, rest of the width)
        ClipboardPreviewPanel {
            tab: root
            Layout.fillWidth: true
            Layout.fillHeight: true
        }
    }

    // Delete / alias modes: Left/Right pick cancel or confirm, Enter/Space run it
    Keys.onPressed: event => {
        if (root.deleteMode) {
            if (event.key === Qt.Key_Left) {
                root.deleteButtonIndex = 0;
                event.accepted = true;
            } else if (event.key === Qt.Key_Right) {
                root.deleteButtonIndex = 1;
                event.accepted = true;
            } else if (event.key === Qt.Key_Return || event.key === Qt.Key_Space) {
                if (root.deleteButtonIndex === 0) {
                    root.cancelDeleteMode();
                } else {
                    root.confirmDeleteItem();
                }
                event.accepted = true;
            } else if (event.key === Qt.Key_Escape) {
                root.cancelDeleteMode();
                event.accepted = true;
            }
        } else if (root.aliasMode) {
            if (event.key === Qt.Key_Left) {
                root.aliasButtonIndex = 0;
                event.accepted = true;
            } else if (event.key === Qt.Key_Right) {
                root.aliasButtonIndex = 1;
                event.accepted = true;
            } else if (event.key === Qt.Key_Return || event.key === Qt.Key_Space) {
                if (root.aliasButtonIndex === 0) {
                    root.cancelAliasMode();
                } else {
                    root.confirmAliasItem();
                }
                event.accepted = true;
            } else if (event.key === Qt.Key_Escape) {
                root.cancelAliasMode();
                event.accepted = true;
            }
        }
    }

    Component.onCompleted: {
        root.refreshClipboardHistory();
        Qt.callLater(() => {
            root.focusSearchInput();
        });
    }
}
