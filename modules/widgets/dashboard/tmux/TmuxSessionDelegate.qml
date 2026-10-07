pragma ComponentBehavior: Bound

import QtQuick
import qs.modules.theme
import qs.modules.services
import qs.config
import qs.modules.components.kit
import "TmuxModel.js" as TmuxModel

// One row of the tmux session list: a kit ListRow for the session (or the
// "create" row), the inline rename editor, the cancel / confirm pair of a
// rename or quit, and the expandable options under it. Mouse: click opens
// or creates, right click toggles the options, long press renames, swipe
// left asks to quit the session.
Item {
    id: row

    required property string sessionId
    required property var sessionData
    required property int index
    required property var tab
    required property var list

    readonly property var modelData: row.sessionData
    readonly property bool isCreate: TmuxModel.isCreateRow(row.modelData)
    readonly property bool isInDeleteMode: row.tab.deleteMode && row.modelData.name === row.tab.sessionToDelete
    readonly property bool isInRenameMode: row.tab.renameMode && row.modelData.name === row.tab.sessionToRename
    readonly property bool isExpanded: row.index === row.tab.expandedItemIndex

    width: row.list.width
    height: TmuxModel.rowHeight(row.index, row.tab.expandedItemIndex, row.isInDeleteMode || row.isInRenameMode)
    clip: true

    Behavior on height {
        enabled: Config.animDuration > 0
        NumberAnimation {
            duration: Config.animDuration
            easing.type: Easing.OutQuart
        }
    }

    ListRow {
        id: listRow
        width: parent.width
        height: TmuxModel.ROW_HEIGHT
        selected: row.tab.selectedIndex === row.index
        title: row.isInDeleteMode ? I18n.t("tmux.quit") + " “" + row.tab.sessionToDelete + "”?" : row.modelData.name
        titleEditor: row.isInRenameMode ? renameEditor : null

        leading: Component {
            Text {
                width: Type.iconSize("body")
                horizontalAlignment: Text.AlignHCenter
                text: row.isInDeleteMode ? Icons.alert : row.isInRenameMode ? Icons.edit : row.isCreate ? Icons.plus : Icons.terminalWindow
                font.family: Icons.font
                font.pixelSize: Type.iconSize("body")
                color: row.isInDeleteMode ? Colors.error : listRow.selected ? Type.accent : Type.secondary
            }
        }

        trailing: Component {
            Row {
                spacing: Space.xs
                visible: row.isInDeleteMode || row.isInRenameMode

                Repeater {
                    model: [Icons.cancel, Icons.accept]

                    IconButton {
                        required property string modelData
                        required property int index
                        readonly property int current: row.isInDeleteMode ? row.tab.deleteButtonIndex : row.tab.renameButtonIndex

                        size: "s"
                        icon: modelData
                        highlighted: current === index
                        onHoveredChanged: {
                            if (hovered && !highlighted) {
                                if (row.isInDeleteMode)
                                    row.tab.deleteButtonIndex = index;
                                else
                                    row.tab.renameButtonIndex = index;
                            }
                        }
                        onClicked: {
                            if (row.isInDeleteMode)
                                index === 0 ? row.tab.cancelDeleteMode() : row.tab.confirmDeleteSession();
                            else
                                index === 0 ? row.tab.cancelRenameMode() : row.tab.confirmRenameSession();
                        }
                    }
                }
            }
        }
    }

    Component {
        id: renameEditor
        InlineEdit {
            id: renameField
            text: row.tab.newSessionName
            onTextChanged: row.tab.newSessionName = renameField.text
            Keys.onPressed: event => {
                if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter) {
                    row.tab.confirmRenameSession();
                } else if (event.key === Qt.Key_Escape) {
                    row.tab.cancelRenameMode();
                } else if (event.key === Qt.Key_Left) {
                    row.tab.renameButtonIndex = 0;
                } else if (event.key === Qt.Key_Right) {
                    row.tab.renameButtonIndex = 1;
                } else {
                    return;
                }
                event.accepted = true;
            }
        }
    }

    TmuxSessionGestures {
        anchors.fill: listRow
        row: row
    }

    TmuxSessionOptions {
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.top: listRow.bottom
        anchors.topMargin: 4
        tab: row.tab
        sessionName: row.modelData.name
        shown: row.isExpanded && !row.isInDeleteMode && !row.isInRenameMode
    }
}
