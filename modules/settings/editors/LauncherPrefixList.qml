pragma ComponentBehavior: Bound

import QtQuick
import qs.modules.theme
import qs.modules.services
import qs.modules.components.kit
import qs.modules.settings.store
import "../../widgets/launcher/Providers.js" as Providers

// What the launcher searches, as one list (ReorderList): every provider,
// the inline ones in their result order (drag one by its grip, or focus the
// grip and press Up / Down: prefix.launcher.order), then the tabs; each with
// the prefix that searches only it, typed in place (prefix.<name>, checked
// with Providers.prefixError: never empty, unique, a space after a word),
// and a switch that turns it on or off (prefix.launcher.disabled). A
// provider that is off is dimmed. The stage's results follow at once.
ReorderList {
    id: root

    property var entry
    readonly property var order: SettingsStore.get("prefix.launcher.order") || []
    readonly property var disabled: SettingsStore.get("prefix.launcher.disabled") || []
    readonly property var inline: Providers.ordered(root.order)

    function prefixes() {
        const out = {};
        Providers.PROVIDER_PREFIXES.forEach(k => out[k] = SettingsStore.get("prefix." + k) || "");
        return out;
    }

    name: "launcher"
    keys: root.inline.concat(Providers.TAB_IDS)
    movable: root.inline.length
    rowHeight: Space.controlM
    labelOf: id => I18n.t("launcher.provider." + id)
    onMoved: (id, from, to) => SettingsStore.set("prefix.launcher.order", Providers.move(root.order, id, to - from))

    row: Item {
        id: line
        property string rowKey: ""
        property int rowIndex: 0
        readonly property var meta: Providers.byId(line.rowKey) || {}
        readonly property string prefixKey: line.meta.prefix ? "prefix." + line.meta.prefix : ""
        readonly property bool on: Providers.isEnabled(line.rowKey, root.disabled)
        property string error: ""
        objectName: "launcherPrefix:" + line.rowKey

        Row {
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
                width: line.width - tail.width - Space.m
                role: "body"
                text: I18n.t("launcher.provider." + line.rowKey)
                elide: Text.ElideRight
            }
        }

        Row {
            id: tail
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
                    objectName: "launcherPrefixInput:" + line.rowKey
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
                        const err = Providers.prefixError(line.rowKey, v, root.prefixes(), root.disabled);
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
                objectName: "launcherSearch:" + line.rowKey
                anchors.verticalCenter: parent.verticalCenter
                checked: line.on
                Accessible.name: I18n.t("launcher.provider." + line.rowKey)
                onToggled: v => SettingsStore.set("prefix.launcher.disabled", Providers.setEnabled(root.disabled, line.rowKey, v))
            }
        }
    }
}
