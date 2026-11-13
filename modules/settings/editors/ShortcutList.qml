pragma ComponentBehavior: Bound

import QtQuick
import qs.modules.theme
import qs.modules.services
import qs.modules.keybinds
import qs.modules.components.kit
import "keybinds"
import "../../keybinds/BindModel.js" as BindModel

// Shortcuts > every bind, grouped (BindModel.GROUPS: a small heading, then
// one compact KeybindRow each; a click opens it to edit, record keys and
// change the action), filtered by the search beside it. The whole list in
// its card (the page scrolls); a bind just added or searched for is
// scrolled into view.
Item {
    id: root

    property var entry
    property real fillHeight: 0
    objectName: "shortcutList"
    // every bind, as tall as the list (the page scrolls, not the card);
    // only a fixed-height host (`fillHeight`) scrolls it inside
    implicitHeight: root.fillHeight > 0 ? root.fillHeight : Math.max(Space.controlL * 2, column.height)
    clip: true

    Flickable {
        id: flick
        anchors.fill: parent
        contentWidth: width
        contentHeight: column.height
        interactive: root.fillHeight > 0 && contentHeight > height
        boundsBehavior: Flickable.StopAtBounds

        Column {
            id: column
            width: flick.width
            spacing: Space.xs / 2

            Repeater {
                model: BindModel.GROUPS
                delegate: Column {
                    id: group
                    required property var modelData
                    // the rows keep their identity (an open editor stays
                    // open) while the store changes around them
                    readonly property var rows: {
                        KeybindsStore.rows;
                        KeybindsStore.conflicts;
                        return KeybindsStore.visibleRows(group.modelData.id);
                    }
                    onRowsChanged: uids.sync(group.rows.map(r => r.uid))
                    objectName: "shortcutGroup:" + group.modelData.id
                    visible: group.rows.length > 0
                    width: column.width
                    spacing: Space.xs / 2
                    UidListModel {
                        id: uids
                        Component.onCompleted: sync(group.rows.map(r => r.uid))
                    }
                    SectionLabel {
                        width: parent.width
                        text: I18n.t(group.modelData.title)
                    }
                    Repeater {
                        model: uids
                        delegate: KeybindRow {
                            required property string uid
                            width: group.width
                            bind: KeybindsStore.row(uid) || KeybindsStore.emptyRow
                        }
                    }
                }
            }
        }
    }

    // "Edit" from the cheatsheet (or a deep link): open that bind here
    function openPending() {
        const uid = KeybindsStore.pendingEdit;
        if (!uid || !KeybindsStore.row(uid))
            return;
        KeybindsStore.pendingEdit = "";
        KeybindsStore.expandedUid = uid;
        KeybindsStore.reveal(uid);
    }
    Component.onCompleted: Qt.callLater(root.openPending)

    // a bind just added or found: into view
    Connections {
        target: KeybindsStore
        function onEditRequested() {
            root.openPending();
        }
        function onRevealRequested(uid) {
            Qt.callLater(() => {
                const item = root.find(column, "keybindRow:" + uid);
                if (!item)
                    return;
                if (flick.interactive) {
                    flick.contentY = Math.max(0, Math.min(item.mapToItem(column, 0, 0).y - Space.l, flick.contentHeight - flick.height));
                    return;
                }
                // the list is whole: the page scrolls to the row
                for (let p = root.parent; p; p = p.parent) {
                    if (typeof p.revealItem === "function") {
                        p.revealItem(item);
                        break;
                    }
                }
            });
        }
    }
    function find(item, name) {
        if (!item)
            return null;
        if (item.objectName === name)
            return item;
        for (let i = 0; i < item.children.length; i++) {
            const f = root.find(item.children[i], name);
            if (f)
                return f;
        }
        return null;
    }

    // more below
    Mark {
        visible: flick.contentHeight > flick.height && flick.contentY < flick.contentHeight - flick.height - 1
        anchors.bottom: parent.bottom
        width: parent.width
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
