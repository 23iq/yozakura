pragma ComponentBehavior: Bound

import QtQuick
import qs.modules.theme
import qs.modules.services
import qs.modules.components.kit
import "ReorderModel.js" as Model

// A list whose rows you put in order, the one way of every settings editor
// (launcher providers, dashboard tabs, island activities, ordered picks).
// Each row: a grip, then the editor's own content (`row`: a Component with
// `rowKey` and `rowIndex` properties, filling the line right of the grip).
// The first `movable` rows have an order; the rest stay after them.
//
// - Drag the grip: the row follows the pointer as an insertion line between
//   rows; it lands on release. The grip keeps the drag inside a scrolling
//   card (preventStealing).
// - Keyboard: the grip is the row's Tab stop; Up / Down move the row and the
//   focus stays on it (rows are keyed, KeyedListModel: never rebuilt).
// - Pointer and keyboard: up / down arrows show beside the grip while it is
//   hovered or has the keyboard focus.
// Moves are reported (`moved(key, from, to)`); the editor writes its value.
// Given a height (`fillHeight`) the list shows whole rows and scrolls, with
// a fade at its foot.
Item {
    id: root

    property var keys: []
    property int movable: root.keys.length
    property real rowHeight: Space.controlM
    property real fillHeight: 0
    // objectName prefix: <name>Row:<key>, <name>Handle:<key>, <name>Move:<key>:up|down
    property string name: "reorder"
    // a row's name for a screen reader ("Move <name>")
    property var labelOf: key => key
    property Component row
    // the key being dragged and the slot it would land in
    property string dragging: ""
    property int target: -1

    signal moved(string key, int from, int to)

    readonly property real listHeight: root.keys.length * root.rowHeight

    function move(key, to) {
        const from = root.keys.indexOf(key);
        if (from < 0 || to === from || to < 0 || to >= root.movable)
            return;
        root.moved(key, from, to);
        Qt.callLater(() => view.positionViewAtIndex(Math.max(0, root.keys.indexOf(key)), ListView.Contain));
    }

    implicitWidth: Space.px(320)
    implicitHeight: root.fillHeight > 0 ? Math.min(root.listHeight, Math.max(root.rowHeight, Math.floor(root.fillHeight / root.rowHeight) * root.rowHeight)) : root.listHeight

    ListView {
        id: view
        objectName: root.name + "List"
        anchors.fill: parent
        interactive: view.contentHeight > view.height + 1
        clip: view.interactive
        boundsBehavior: Flickable.StopAtBounds
        model: KeyedListModel {
            keys: root.keys
        }
        displaced: SettleTransition {
            duration: Motion.glide.duration
            easingType: Motion.glide.easing
        }
        move: SettleTransition {
            duration: Motion.glide.duration
            easingType: Motion.glide.easing
        }

        delegate: Item {
            id: line
            required property string key
            required property int index
            readonly property bool canMove: line.index < root.movable
            readonly property bool keyboard: handle.activeFocus && FocusState.keyboard
            readonly property bool showMoves: line.canMove && root.dragging === "" && (handleHover.hovered || movesHover.hovered || line.keyboard)
            objectName: root.name + "Row:" + line.key
            width: view.width
            height: root.rowHeight
            z: line.showMoves ? 2 : 1

            // where a dragged row lands: a line above this slot (or under the
            // last movable row)
            Mark {
                visible: root.dragging !== "" && line.canMove && (root.target === line.index || (root.target >= root.movable && line.index === root.movable - 1))
                y: root.target === line.index ? -height / 2 : line.height - height / 2
                x: handle.width
                width: line.width - handle.width
                height: Space.hairline * 2
                color: Type.accent
                z: 3
            }

            // the row (dimmed while it is dragged; the delegate root keeps
            // opacity 1 for the list's transitions)
            Item {
                anchors.fill: parent
                opacity: root.dragging === line.key ? 0.6 : 1

                Item {
                    id: handle
                    objectName: root.name + "Handle:" + line.key
                    width: Space.controlXS
                    height: line.height
                    activeFocusOnTab: line.canMove
                    Accessible.role: Accessible.Button
                    Accessible.name: I18n.t("prefs.reorder.move").replace("%1", root.labelOf(line.key))
                    Accessible.description: I18n.t("prefs.reorder.hint")
                    Keys.onUpPressed: root.move(line.key, Model.stepIndex(line.index, -1, root.movable))
                    Keys.onDownPressed: root.move(line.key, Model.stepIndex(line.index, 1, root.movable))

                    HoverHandler {
                        id: handleHover
                        enabled: line.canMove
                    }
                    Icon {
                        anchors.centerIn: parent
                        visible: line.canMove
                        icon: Icons.dotsSix
                        role: "secondary"
                        tone: grip.containsMouse || grip.pressed || handle.activeFocus ? "text" : "muted"
                    }
                    FocusRing {
                        shown: handle.activeFocus
                    }
                    MouseArea {
                        id: grip
                        anchors.fill: parent
                        enabled: line.canMove
                        hoverEnabled: true
                        cursorShape: pressed ? Qt.ClosedHandCursor : Qt.OpenHandCursor
                        // a vertical drag on the grip reorders, never scrolls the card
                        preventStealing: true
                        onPressed: {
                            handle.forceActiveFocus(Qt.MouseFocusReason);
                            root.dragging = line.key;
                            root.target = line.index;
                        }
                        onPositionChanged: mouse => {
                            if (!pressed)
                                return;
                            root.target = Model.slotAt(mapToItem(view.contentItem, 0, mouse.y).y, root.rowHeight, root.movable);
                        }
                        onReleased: {
                            const t = root.target;
                            const key = root.dragging;
                            root.dragging = "";
                            root.target = -1;
                            if (t >= 0)
                                root.move(key, Model.dropIndex(line.index, t));
                        }
                        onCanceled: {
                            root.dragging = "";
                            root.target = -1;
                        }
                    }
                    Tooltip {
                        text: I18n.t("prefs.reorder.hint")
                        shown: grip.containsMouse && !grip.pressed && line.canMove && !line.showMoves
                    }
                }

                Loader {
                    id: content
                    anchors.left: handle.right
                    anchors.leftMargin: Space.xs
                    anchors.right: parent.right
                    height: parent.height
                    sourceComponent: root.row
                    onLoaded: {
                        content.item.rowKey = Qt.binding(() => line.key);
                        content.item.rowIndex = Qt.binding(() => line.index);
                    }
                }
            }

            // up / down beside the grip while it is hovered or focused
            Mark {
                id: moves
                x: handle.width
                anchors.verticalCenter: parent.verticalCenter
                width: movesRow.implicitWidth + Space.xs * 2
                height: movesRow.implicitHeight + Space.xs
                radius: Look.radius("control", height)
                color: Look.raisedFill(true)
                border.width: Space.hairline
                border.color: Type.hairline
                opacity: line.showMoves ? 1 : 0
                visible: opacity > 0
                Behavior on opacity {
                    enabled: Motion.micro.duration > 0
                    NumberAnimation {
                        duration: Motion.micro.duration
                    }
                }
                HoverHandler {
                    id: movesHover
                }
                Row {
                    id: movesRow
                    anchors.centerIn: parent
                    Repeater {
                        model: [-1, 1]
                        delegate: IconButton {
                            id: arrow
                            required property int modelData
                            objectName: root.name + "Move:" + line.key + (arrow.modelData < 0 ? ":up" : ":down")
                            size: "xs"
                            icon: arrow.modelData < 0 ? Icons.caretUp : Icons.caretDown
                            enabled: arrow.modelData < 0 ? line.index > 0 : line.index < root.movable - 1
                            tooltip: I18n.t(arrow.modelData < 0 ? "prefs.reorder.up" : "prefs.reorder.down")
                            Accessible.name: arrow.tooltip
                            onClicked: root.move(line.key, Model.stepIndex(line.index, arrow.modelData, root.movable))
                        }
                    }
                }
            }
        }
    }

    // more rows under the fold
    Mark {
        visible: view.interactive && view.contentY < view.contentHeight - view.height - 1
        y: view.height - height
        width: root.width
        height: Space.l
        radius: 0
        gradient: Gradient {
            GradientStop {
                position: 0
                color: "transparent"
            }
            GradientStop {
                position: 1
                color: Look.cardFill(false)
            }
        }
    }
}
