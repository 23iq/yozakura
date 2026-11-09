pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Layouts
import qs.modules.theme
import qs.modules.components
import qs.modules.services
import qs.modules.settings.store
import qs.config
import "../controls"
import "../Ui.js" as Ui
import "../../widgets/launcher/Providers.js" as Providers
import qs.modules.components.kit

// Launcher providers (modules/widgets/launcher/Providers.js): the result
// providers in search order (move up/down, on/off, prefix) and the prefix
// tabs (on/off, prefix). Writes prefix.launcher.order/disabled and
// prefix.<name> through SettingsStore.
ColumnLayout {
    id: root

    property var entry

    spacing: Space.s

    readonly property var order: SettingsStore.get("prefix.launcher.order") || []
    readonly property var disabled: SettingsStore.get("prefix.launcher.disabled") || []
    readonly property var inline: Providers.ordered(order)

    function move(id, delta) {
        SettingsStore.set("prefix.launcher.order", Providers.move(root.order, id, delta));
    }

    // Config.prefix as the editor sees it (settings store values).
    function prefixes() {
        const out = {};
        Providers.PROVIDER_PREFIXES.forEach(k => {
            out[k] = SettingsStore.get("prefix." + k) || "";
        });
        return out;
    }

    function setOn(id, on) {
        SettingsStore.set("prefix.launcher.disabled", Providers.setEnabled(root.disabled, id, on));
    }

    component ProviderCard: StyledRect {
        id: card

        required property string pid
        property int position: -1
        property int count: 0
        readonly property var meta: Providers.byId(pid)
        readonly property bool on: Providers.isEnabled(pid, root.disabled)
        readonly property string prefixKey: meta && meta.prefix ? "prefix." + meta.prefix : ""
        // Why the typed prefix was refused (shown under the card), or "".
        property string prefixError: ""

        Layout.fillWidth: true
        implicitHeight: 58 + (prefixError !== "" ? errorText.implicitHeight + 8 : 0)
        variant: "common"
        radius: Look.radius("control")

        RowLayout {
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.top: parent.top
            height: 58
            anchors.leftMargin: Space.m
            anchors.rightMargin: Space.m
            spacing: Space.m

            // Order arrows (result providers only)
            Column {
                visible: card.position >= 0
                spacing: 0
                Repeater {
                    model: [
                        {
                            "glyph": Icons.caretUp,
                            "delta": -1
                        },
                        {
                            "glyph": Icons.caretDown,
                            "delta": 1
                        }
                    ]
                    delegate: Icon {
                        id: arrow
                        role: "secondary"
                        required property var modelData
                        readonly property bool usable: arrow.modelData.delta < 0 ? card.position > 0 : card.position < card.count - 1
                        icon: arrow.modelData.glyph
                        color: arrowArea.containsMouse && arrow.usable ? Colors.primary : Colors.outline
                        opacity: arrow.usable ? 1 : 0.3
                        Accessible.role: Accessible.Button
                        Accessible.name: I18n.t(arrow.modelData.delta < 0 ? "prefs.launcher.move_up" : "prefs.launcher.move_down")
                        MouseArea {
                            id: arrowArea
                            anchors.fill: parent
                            anchors.margins: -Space.xs
                            hoverEnabled: true
                            enabled: arrow.usable
                            cursorShape: Qt.PointingHandCursor
                            onClicked: root.move(card.pid, arrow.modelData.delta)
                        }
                    }
                }
            }

            StyledRect {
                Layout.preferredWidth: 34
                Layout.preferredHeight: 34
                variant: card.on ? "primary" : "internalbg"
                radius: Look.radius("control")
                Icon {
                    anchors.centerIn: parent
                    icon: card.meta ? (Icons[card.meta.icon] || "") : ""
                    color: card.on ? Styling.srItem("primary") : Colors.outline
                }
            }

            ColumnLayout {
                Layout.fillWidth: true
                spacing: Space.hairline
                KitText {
                    Layout.fillWidth: true
                    text: I18n.t("launcher.provider." + card.pid)
                    font.weight: Font.DemiBold
                    color: card.on ? Colors.overSurface : Colors.outline
                    elide: Text.ElideRight
                }
                KitText {
                    role: "caption"
                    Layout.fillWidth: true
                    text: I18n.t("launcher.provider." + card.pid + ".desc")
                    elide: Text.ElideRight
                }
            }

            // Prefix
            TextControl {
                visible: card.prefixKey !== ""
                Layout.preferredWidth: 64
                text: card.prefixKey ? (SettingsStore.get(card.prefixKey) || "") : ""
                placeholder: "—"
                monospace: true
                enabled: card.on
                Accessible.name: I18n.t("prefs.launcher.prefix")
                invalid: card.prefixError !== ""
                onEdited: t => {
                    if (!card.prefixKey)
                        return;
                    const v = t.trim();
                    const err = Providers.prefixError(card.pid, v, root.prefixes(), root.disabled);
                    card.prefixError = err ? I18n.t("prefs.launcher.prefix_" + err) : "";
                    if (!err)
                        SettingsStore.set(card.prefixKey, v);
                }
            }

            ToggleControl {
                checked: card.on
                Accessible.name: I18n.t("launcher.provider." + card.pid)
                onToggled: v => root.setOn(card.pid, v)
            }
        }

        KitText {
            id: errorText
            role: "caption"
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.bottom: parent.bottom
            anchors.leftMargin: Space.m
            anchors.rightMargin: Space.m
            anchors.bottomMargin: Space.s
            visible: card.prefixError !== ""
            text: card.prefixError
            wrapMode: Text.Wrap
            color: Colors.error
        }
    }

    Repeater {
        model: root.inline
        delegate: ProviderCard {
            required property string modelData
            required property int index
            pid: modelData
            position: index
            count: root.inline.length
        }
    }

    KitText {
        role: "caption"
        Layout.topMargin: Space.s
        Layout.fillWidth: true
        text: I18n.t("prefs.launcher.tabs")
        font.weight: Font.DemiBold
        font.letterSpacing: 0.6
    }

    Repeater {
        model: Providers.TAB_IDS
        delegate: ProviderCard {
            required property string modelData
            pid: modelData
        }
    }

    KitText {
        role: "caption"
        Layout.fillWidth: true
        text: I18n.t("prefs.launcher.prefix_note")
        wrapMode: Text.Wrap
        color: Ui.alpha(Colors.outline, 0.9)
    }
}
