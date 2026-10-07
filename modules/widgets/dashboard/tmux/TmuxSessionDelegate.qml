pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import qs.modules.theme
import qs.modules.components
import qs.config
import "TmuxModel.js" as TmuxModel

// One row of the tmux session list: the session (or the "create" row) with
// its icon, inline rename field, delete/rename confirmation buttons and the
// expandable options menu. Mouse: click opens/creates, right click toggles
// the options, long press renames, swipe left asks to quit the session.
Rectangle {
    id: row

    required property string sessionId
    required property var sessionData
    required property int index
    required property var tab
    required property var list

    readonly property var modelData: row.sessionData
    readonly property bool isCreate: TmuxModel.isCreateRow(row.modelData)
    property bool isInDeleteMode: row.tab.deleteMode && row.modelData.name === row.tab.sessionToDelete
    property bool isInRenameMode: row.tab.renameMode && row.modelData.name === row.tab.sessionToRename
    property bool isExpanded: row.index === row.tab.expandedItemIndex
    property color textColor: {
        if (row.isInDeleteMode) {
            return Styling.srItem("error");
        } else if (row.isInRenameMode) {
            return Styling.srItem("secondary");
        } else if (row.isExpanded) {
            return Styling.srItem("pane");
        } else {
            return Colors.overSurface;
        }
    }

    width: row.list.width
    height: TmuxModel.rowHeight(row.index, row.tab.expandedItemIndex, row.isInDeleteMode || row.isInRenameMode)
    color: "transparent"
    radius: 16
    clip: true

    Behavior on y {
        enabled: Config.animDuration > 0
        NumberAnimation {
            duration: Config.animDuration / 2
            easing.type: Motion.morph.easing
        }
    }

    Behavior on height {
        enabled: Config.animDuration > 0
        NumberAnimation {
            duration: Config.animDuration
            easing.type: Motion.morph.easing
        }
    }

    MouseArea {
        id: mouseArea
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.top: parent.top
        height: row.isExpanded ? TmuxModel.ROW_HEIGHT : parent.height
        hoverEnabled: !row.list.isScrolling
        enabled: !row.isInDeleteMode && !row.isInRenameMode
        acceptedButtons: Qt.LeftButton | Qt.RightButton

        property real startX: 0
        property real startY: 0
        property bool isDragging: false
        property bool longPressTriggered: false

        onEntered: {
            if (row.list.isScrolling)
                return;
            if (!row.tab.deleteMode && !row.tab.renameMode && row.tab.expandedItemIndex === -1) {
                row.tab.selectedIndex = row.index;
                row.list.currentIndex = row.index;
            }
        }

        onClicked: mouse => {
            const t = row.tab;
            if (mouse.button === Qt.LeftButton) {
                if (t.deleteMode && row.modelData.name !== t.sessionToDelete) {
                    t.cancelDeleteMode();
                    return;
                } else if (t.renameMode && row.modelData.name !== t.sessionToRename) {
                    t.cancelRenameMode();
                    return;
                }

                if (!t.deleteMode && !t.renameMode && !row.isExpanded) {
                    if (row.modelData.isCreateSpecificButton) {
                        t.createTmuxSession(row.modelData.sessionNameToCreate);
                    } else if (row.modelData.isCreateButton) {
                        t.createTmuxSession();
                    } else {
                        t.attachToSession(row.modelData.name);
                    }
                }
            } else if (mouse.button === Qt.RightButton) {
                if (t.deleteMode) {
                    t.cancelDeleteMode();
                    return;
                } else if (t.renameMode) {
                    t.cancelRenameMode();
                    return;
                }

                if (!row.isCreate) {
                    // Toggle the options menu
                    if (t.expandedItemIndex === row.index) {
                        t.expandedItemIndex = -1;
                        t.selectedOptionIndex = 0;
                        t.keyboardNavigation = false;
                        // Keep the selection on the hovered row after closing
                        t.selectedIndex = row.index;
                        row.list.currentIndex = row.index;
                    } else {
                        t.expandedItemIndex = row.index;
                        t.selectedIndex = row.index;
                        row.list.currentIndex = row.index;
                        t.selectedOptionIndex = 0;
                        t.keyboardNavigation = false;
                    }
                }
            }
        }

        onPressed: mouse => {
            mouseArea.startX = mouse.x;
            mouseArea.startY = mouse.y;
            mouseArea.isDragging = false;
            mouseArea.longPressTriggered = false;

            if (mouse.button !== Qt.RightButton) {
                longPressTimer.start();
            }
        }

        onPositionChanged: mouse => {
            if (mouseArea.pressed && mouse.button !== Qt.RightButton) {
                let deltaX = mouse.x - mouseArea.startX;
                let deltaY = mouse.y - mouseArea.startY;
                let distance = Math.sqrt(deltaX * deltaX + deltaY * deltaY);

                // More than 10 px is a drag; a left swipe asks to quit
                if (distance > 10) {
                    mouseArea.isDragging = true;
                    longPressTimer.stop();

                    if (deltaX < -50 && Math.abs(deltaY) < 30 && !row.isCreate) {
                        if (!mouseArea.longPressTriggered) {
                            row.tab.enterDeleteMode(row.modelData.name);
                            mouseArea.longPressTriggered = true;
                        }
                    }
                }
            }
        }

        onReleased: mouse => {
            longPressTimer.stop();
            mouseArea.isDragging = false;
            mouseArea.longPressTriggered = false;
        }

        Timer {
            id: longPressTimer
            interval: 800
            repeat: false
            onTriggered: {
                if (!mouseArea.isDragging && !row.isCreate) {
                    row.tab.enterRenameMode(row.modelData.name);
                    mouseArea.longPressTriggered = true;
                }
            }
        }
    }

    TmuxSessionOptions {
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.bottom: parent.bottom
        anchors.leftMargin: 8
        anchors.rightMargin: 8
        anchors.bottomMargin: 8
        tab: row.tab
        sessionName: row.modelData.name
        shown: row.isExpanded && !row.isInDeleteMode && !row.isInRenameMode
    }

    TmuxConfirmActions {
        anchors.right: parent.right
        anchors.top: parent.top
        anchors.rightMargin: 8
        anchors.topMargin: 8
        active: row.isInRenameMode
        buttonIndex: row.tab.renameButtonIndex
        highlightVariant: "oversecondary"
        iconColor: Colors.overSecondary
        highlightedIconColor: Colors.overSecondaryContainer
        onCancelClicked: row.tab.cancelRenameMode()
        onConfirmClicked: row.tab.confirmRenameSession()
        onHoverIndex: index => row.tab.renameButtonIndex = index
    }

    RowLayout {
        id: mainContent
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.top: parent.top
        anchors.margins: 8
        anchors.rightMargin: row.isInRenameMode ? 84 : 8
        height: 32
        spacing: 8

        Behavior on anchors.rightMargin {
            enabled: Config.animDuration > 0
            NumberAnimation {
                duration: Config.animDuration
                easing.type: Motion.morph.easing
            }
        }

        StyledRect {
            id: iconBackground
            Layout.preferredWidth: 32
            Layout.preferredHeight: 32
            variant: {
                if (row.isInDeleteMode) {
                    return "overerror";
                } else if (row.isInRenameMode) {
                    return "oversecondary";
                } else if (row.modelData.isCreateButton) {
                    return "primary";
                } else {
                    return "common";
                }
            }
            radius: Styling.radius(-4)

            Text {
                anchors.centerIn: parent
                text: {
                    if (row.isInDeleteMode) {
                        return Icons.alert;
                    } else if (row.isInRenameMode) {
                        return Icons.edit;
                    } else if (row.isCreate) {
                        return Icons.plus;
                    } else {
                        return Icons.terminalWindow;
                    }
                }
                color: iconBackground.item
                font.family: Icons.font
                font.pixelSize: 16
                textFormat: Text.RichText
            }
        }

        ColumnLayout {
            Layout.fillWidth: true
            spacing: 2

            Loader {
                Layout.fillWidth: true
                sourceComponent: row.tab.renameMode && row.modelData.name === row.tab.sessionToRename ? renameTextInput : normalText
            }

            Component {
                id: normalText
                Text {
                    text: {
                        if (row.isInDeleteMode && !row.isCreate) {
                            return `Quit "${row.tab.sessionToDelete}"?`;
                        } else {
                            return row.modelData.name;
                        }
                    }
                    color: row.textColor
                    font.family: Config.theme.font
                    font.pixelSize: Config.theme.fontSize
                    font.weight: row.isInDeleteMode ? Font.Bold : (row.modelData.isCreateButton ? Font.Medium : Font.Bold)
                    elide: Text.ElideRight
                }
            }

            Component {
                id: renameTextInput
                TextField {
                    id: renameField
                    text: row.tab.newSessionName
                    color: Colors.overSecondary
                    selectionColor: Colors.overSecondary
                    selectedTextColor: Colors.secondary
                    font.family: Config.theme.font
                    font.pixelSize: Config.theme.fontSize
                    font.weight: Font.Bold
                    background: Rectangle {
                        color: "transparent"
                        border.width: 0
                    }
                    selectByMouse: true

                    onTextChanged: {
                        row.tab.newSessionName = renameField.text;
                    }

                    Component.onCompleted: {
                        Qt.callLater(() => {
                            renameField.forceActiveFocus();
                            renameField.selectAll();
                        });
                    }

                    Keys.onPressed: event => {
                        if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter) {
                            row.tab.confirmRenameSession();
                            event.accepted = true;
                        } else if (event.key === Qt.Key_Escape) {
                            row.tab.cancelRenameMode();
                            event.accepted = true;
                        } else if (event.key === Qt.Key_Left) {
                            row.tab.renameButtonIndex = 0;
                            event.accepted = true;
                        } else if (event.key === Qt.Key_Right) {
                            row.tab.renameButtonIndex = 1;
                            event.accepted = true;
                        }
                    }
                }
            }
        }
    }

    TmuxConfirmActions {
        anchors.right: parent.right
        anchors.top: parent.top
        anchors.rightMargin: 8
        anchors.topMargin: 8
        active: row.isInDeleteMode
        buttonIndex: row.tab.deleteButtonIndex
        highlightVariant: "overerror"
        iconColor: Colors.overError
        highlightedIconColor: Colors.overErrorContainer
        onCancelClicked: row.tab.cancelDeleteMode()
        onConfirmClicked: row.tab.confirmDeleteSession()
        onHoverIndex: index => row.tab.deleteButtonIndex = index
    }
}
