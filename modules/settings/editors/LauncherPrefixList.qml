pragma ComponentBehavior: Bound

import QtQuick
import qs.modules.theme
import qs.modules.services
import qs.modules.components.kit
import qs.modules.settings.store
import "../../widgets/launcher/Providers.js" as Providers

// The launcher's providers as a compact list: the inline ones in their
// result order (arrows on hover move one up or down,
// prefix.launcher.order), then the tabs; each with the prefix that
// searches only it, typed in place (prefix.<name>, checked with
// Providers.prefixError: never empty, unique, a space after a word). A
// provider that is off is dimmed (its chip turns it on).
Column {
    id: root

    property var entry
    readonly property var order: SettingsStore.get("prefix.launcher.order") || []
    readonly property var disabled: SettingsStore.get("prefix.launcher.disabled") || []
    readonly property var inline: Providers.ordered(root.order)
    readonly property var ids: root.inline.concat(Providers.TAB_IDS)

    spacing: 0

    function prefixes() {
        const out = {};
        Providers.PROVIDER_PREFIXES.forEach(k => out[k] = SettingsStore.get("prefix." + k) || "");
        return out;
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
            height: Space.controlM

            HoverHandler {
                id: hover
            }

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
                    width: line.width - Space.px(170)
                    role: "body"
                    text: I18n.t("launcher.provider." + line.modelData)
                    elide: Text.ElideRight
                }
            }

            Row {
                anchors.right: parent.right
                anchors.verticalCenter: parent.verticalCenter
                spacing: Space.xs

                // order (inline providers): shown on hover
                Repeater {
                    model: line.position >= 0 ? [-1, 1] : []
                    delegate: IconButton {
                        id: arrow
                        required property int modelData
                        objectName: "launcherMove:" + line.modelData + (modelData < 0 ? ":up" : ":down")
                        size: "xs"
                        opacity: hover.hovered ? 1 : 0
                        enabled: modelData < 0 ? line.position > 0 : line.position < root.inline.length - 1
                        icon: modelData < 0 ? Icons.caretUp : Icons.caretDown
                        tooltip: I18n.t(modelData < 0 ? "prefs.launcher.move_up" : "prefs.launcher.move_down")
                        onClicked: SettingsStore.set("prefix.launcher.order", Providers.move(root.order, line.modelData, arrow.modelData))
                    }
                }

                // the prefix, typed in place
                Mark {
                    id: box
                    visible: line.prefixKey !== ""
                    anchors.verticalCenter: parent.verticalCenter
                    width: Space.px(56)
                    height: Space.controlXS
                    radius: Look.radius("control", height)
                    color: Look.raisedFill(input.activeFocus)
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
            }
        }
    }
}
