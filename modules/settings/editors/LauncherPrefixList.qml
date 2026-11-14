pragma ComponentBehavior: Bound

import QtQuick
import qs.modules.theme
import qs.modules.services
import qs.modules.components.kit
import qs.modules.settings.store
import "../../widgets/launcher/Providers.js" as Providers

// What the launcher searches, as one list: every provider, the inline ones
// in their result order (drag one by its handle, or focus the handle and
// press Up / Down: prefix.launcher.order), then the tabs; each with the
// prefix that searches only it, typed in place (prefix.<name>, checked
// with Providers.prefixError: never empty, unique, a space after a word),
// and a switch that turns it on or off (prefix.launcher.disabled). A
// provider that is off is dimmed. The stage's results follow at once.
Column {
    id: root

    property var entry
    property real fillHeight: 0
    readonly property var order: SettingsStore.get("prefix.launcher.order") || []
    readonly property var disabled: SettingsStore.get("prefix.launcher.disabled") || []
    readonly property var inline: Providers.ordered(root.order)
    readonly property var ids: root.inline.concat(Providers.TAB_IDS)
    readonly property real lineH: Space.controlM
    // the inline provider being dragged and the slot it would land in
    property string dragging: ""
    property int target: -1

    spacing: 0

    function prefixes() {
        const out = {};
        Providers.PROVIDER_PREFIXES.forEach(k => out[k] = SettingsStore.get("prefix." + k) || "");
        return out;
    }

    function moveTo(id, slot) {
        const from = root.inline.indexOf(id);
        const to = Math.max(0, Math.min(root.inline.length - 1, slot));
        if (from >= 0 && to !== from)
            SettingsStore.set("prefix.launcher.order", Providers.move(root.order, id, to - from));
    }

    Repeater {
        model: root.ids
        delegate: Item {
            id: line
            required property string modelData
            required property int index
            readonly property var meta: Providers.byId(modelData) || {}
            readonly property string prefixKey: line.meta.prefix ? "prefix." + line.meta.prefix : ""
            readonly property int position: root.inline.indexOf(modelData)
            readonly property bool on: Providers.isEnabled(modelData, root.disabled)
            property string error: ""
            objectName: "launcherPrefix:" + modelData
            width: root.width
            height: root.lineH
            opacity: root.dragging === line.modelData ? 0.6 : 1

            // where a dragged provider lands: a line above this slot (or
            // under the last inline one)
            Mark {
                visible: root.dragging !== "" && line.position >= 0 && (root.target === line.position || (root.target >= root.inline.length && line.position === root.inline.length - 1))
                y: root.target === line.position ? -height / 2 : line.height - height / 2
                x: handle.width
                width: line.width - handle.width
                height: Space.hairline * 2
                color: Type.accent
                z: 2
            }

            // the drag handle (inline providers: they have an order)
            Item {
                id: handle
                objectName: "launcherHandle:" + line.modelData
                width: Space.controlXS
                height: line.height
                activeFocusOnTab: line.position >= 0
                Accessible.role: Accessible.Button
                Accessible.name: I18n.t("prefs.launcher.reorder")
                Keys.onUpPressed: root.moveTo(line.modelData, line.position - 1)
                Keys.onDownPressed: root.moveTo(line.modelData, line.position + 1)
                Icon {
                    anchors.centerIn: parent
                    visible: line.position >= 0
                    icon: Icons.dotsSix
                    role: "secondary"
                    tone: drag.containsMouse || drag.pressed || handle.activeFocus ? "text" : "muted"
                }
                FocusRing {
                    shown: handle.activeFocus
                }
                MouseArea {
                    id: drag
                    anchors.fill: parent
                    enabled: line.position >= 0
                    hoverEnabled: true
                    cursorShape: pressed ? Qt.ClosedHandCursor : Qt.OpenHandCursor
                    preventStealing: true
                    onPressed: {
                        root.dragging = line.modelData;
                        root.target = line.position;
                    }
                    onPositionChanged: mouse => {
                        if (!pressed)
                            return;
                        const y = mapToItem(root, 0, mouse.y).y;
                        // the slot boundary nearest the pointer
                        root.target = Math.max(0, Math.min(root.inline.length, Math.round(y / root.lineH)));
                    }
                    onReleased: {
                        const t = root.target;
                        const id = root.dragging;
                        root.dragging = "";
                        root.target = -1;
                        if (t >= 0)
                            root.moveTo(id, t > line.position ? t - 1 : t);
                    }
                    onCanceled: {
                        root.dragging = "";
                        root.target = -1;
                    }
                }
                Tooltip {
                    text: I18n.t("prefs.launcher.reorder")
                    shown: drag.containsMouse && !drag.pressed && line.position >= 0
                }
            }

            Row {
                anchors.left: handle.right
                anchors.leftMargin: Space.xs
                anchors.verticalCenter: parent.verticalCenter
                spacing: Space.s
                opacity: line.on ? 1 : 0.45
                Icon {
                    anchors.verticalCenter: parent.verticalCenter
                    icon: Icons[line.meta.icon] ?? ""
                    role: "body"
                    tone: line.on ? "secondary" : "muted"
                }
                KitText {
                    anchors.verticalCenter: parent.verticalCenter
                    width: line.width - handle.width - Space.px(200)
                    role: "body"
                    text: I18n.t("launcher.provider." + line.modelData)
                    elide: Text.ElideRight
                }
            }

            Row {
                anchors.right: parent.right
                anchors.verticalCenter: parent.verticalCenter
                spacing: Space.m

                // the prefix, typed in place
                Mark {
                    id: box
                    visible: line.prefixKey !== ""
                    anchors.verticalCenter: parent.verticalCenter
                    width: Space.px(56)
                    height: Space.controlXS
                    radius: Look.radius("control", height)
                    color: Look.raisedFill(input.activeFocus)
                    opacity: line.on ? 1 : 0.45
                    border.width: line.error !== "" || input.activeFocus ? Space.hairline : 0
                    border.color: line.error !== "" ? Colors.error : Type.accent

                    InlineEdit {
                        id: input
                        objectName: "launcherPrefixInput:" + line.modelData
                        anchors.fill: parent
                        anchors.leftMargin: Space.s
                        anchors.rightMargin: Space.s
                        autoFocus: false
                        role: "secondary"
                        font.family: Type.monoFont
                        horizontalAlignment: TextInput.AlignHCenter
                        enabled: line.on
                        text: line.prefixKey ? String(SettingsStore.get(line.prefixKey) || "") : ""
                        onEditingFinished: {
                            const v = text.trim();
                            const err = Providers.prefixError(line.modelData, v, root.prefixes(), root.disabled);
                            line.error = err ? I18n.t("prefs.launcher.prefix_" + err) : "";
                            if (!err)
                                SettingsStore.set(line.prefixKey, v);
                        }
                    }
                    Tooltip {
                        text: line.error
                        shown: line.error !== ""
                    }
                }
                // a provider without a prefix keeps the column
                Item {
                    visible: line.prefixKey === ""
                    width: box.width
                    height: 1
                }

                Switch {
                    objectName: "launcherSearch:" + line.modelData
                    anchors.verticalCenter: parent.verticalCenter
                    checked: line.on
                    Accessible.name: I18n.t("launcher.provider." + line.modelData)
                    onToggled: v => SettingsStore.set("prefix.launcher.disabled", Providers.setEnabled(root.disabled, line.modelData, v))
                }
            }
        }
    }
}
