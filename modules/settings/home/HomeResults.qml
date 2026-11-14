pragma ComponentBehavior: Bound

import QtQuick
import qs.modules.theme
import qs.modules.services
import qs.modules.components.kit

// The home search as a command palette: the results of the query under the
// field, each a row with the setting, its breadcrumb ("Screen › Bar ›
// Clock") and its current value. The rows follow the results by key
// (KeyedListModel): typing more lets the ones that stay glide to their new
// place while the others fade, nothing is rebuilt per keystroke. The
// selected row (Up / Down in the field) wears the selection and the Enter
// keycap; `flash(i)` lights a row as it opens.
Item {
    id: root
    objectName: "settingsSearchResults"

    property var results: []
    property int selectedIndex: 0
    // (result) -> its current value as a short text
    property var valueOf: null
    readonly property var model: root.results
    readonly property int count: root.results.length

    signal activated(int index, Item row)

    implicitHeight: root.count > 0 ? list.contentHeight : empty.implicitHeight + Space.xl * 2

    // One key per result (the rows follow these).
    function keyOf(r) {
        return [r.categoryId, r.sectionId, r.entryId, r.key, r.label].join("|");
    }
    readonly property var keys: {
        const seen = {};
        return root.results.map(r => {
            let k = root.keyOf(r);
            while (seen[k])
                k += "+";
            seen[k] = true;
            return k;
        });
    }
    readonly property var byKey: {
        const m = {};
        root.keys.forEach((k, i) => m[k] = root.results[i]);
        return m;
    }

    function rowAt(i) {
        return list.itemAtIndex(i);
    }
    function flash(i) {
        const r = list.itemAtIndex(i);
        if (r)
            r.flash();
    }

    ListView {
        id: list
        width: parent.width
        height: list.contentHeight
        interactive: false
        spacing: Space.hairline
        model: KeyedListModel {
            keys: root.keys
        }

        delegate: ListRow {
            id: row
            required property string key
            required property int index
            readonly property var result: root.byKey[row.key] || null
            width: list.width
            title: row.result ? row.result.label : ""
            subtitle: row.result ? row.result.context : ""
            selected: row.index === root.selectedIndex
            onClicked: root.activated(row.index, row)

            function flash() {
                flashAnim.restart();
            }

            leading: Component {
                Icon {
                    icon: row.result ? (Icons[row.result.icon] ?? "") : ""
                    tone: row.selected ? "accent" : "secondary"
                }
            }
            trailing: Component {
                Row {
                    spacing: Space.s
                    KitText {
                        anchors.verticalCenter: parent.verticalCenter
                        role: "secondary"
                        text: row.result && root.valueOf ? root.valueOf(row.result) : ""
                        elide: Text.ElideRight
                    }
                    KeyHint {
                        anchors.verticalCenter: parent.verticalCenter
                        visible: row.selected
                        icon: Icons.keyReturn
                    }
                }
            }

            // the accent light of a row that opens
            Mark {
                id: flashMark
                anchors.fill: parent
                radius: row.radius
                color: Look.tonal(Type.accent)
                opacity: 0
                SequentialAnimation {
                    id: flashAnim
                    NumberAnimation {
                        target: flashMark
                        property: "opacity"
                        to: 1
                        duration: Motion.micro.duration
                    }
                    NumberAnimation {
                        target: flashMark
                        property: "opacity"
                        to: 0
                        duration: Motion.glide.duration
                    }
                }
            }
        }

        add: Transition {
            enabled: Motion.glide.duration > 0
            NumberAnimation {
                property: "opacity"
                from: 0
                to: 1
                duration: Motion.glide.duration
                easing.type: Motion.glide.easing
            }
        }
        remove: Transition {
            enabled: Motion.micro.duration > 0
            NumberAnimation {
                property: "opacity"
                to: 0
                duration: Motion.micro.duration
            }
        }
        displaced: SettleTransition {
            duration: Motion.glide.duration
            easingType: Motion.glide.easing
        }
        move: SettleTransition {
            duration: Motion.glide.duration
            easingType: Motion.glide.easing
        }
    }

    KitText {
        id: empty
        anchors.horizontalCenter: parent.horizontalCenter
        y: Space.xl
        visible: root.count === 0
        role: "secondary"
        text: I18n.t("prefs.search.empty")
    }
}
