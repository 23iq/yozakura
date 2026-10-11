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

// Launcher providers (modules/widgets/launcher/Providers.js): the result
// providers in search order (move up/down, on/off, prefix) and the prefix
// tabs (on/off, prefix). Writes prefix.launcher.order/disabled and
// prefix.<name> through SettingsStore.
ColumnLayout {
    id: root

    property var entry

    spacing: 8

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
        radius: Styling.radius(-2)

        RowLayout {
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.top: parent.top
            height: 58
            anchors.leftMargin: 10
            anchors.rightMargin: 12
            spacing: 10

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
                    delegate: Text {
                        id: arrow
                        required property var modelData
                        readonly property bool usable: arrow.modelData.delta < 0 ? card.position > 0 : card.position < card.count - 1
                        text: arrow.modelData.glyph
                        font.family: Icons.font
                        font.pixelSize: 15
                        color: arrowArea.containsMouse && arrow.usable ? Colors.primary : Colors.outline
                        opacity: arrow.usable ? 1 : 0.3
                        Accessible.role: Accessible.Button
                        Accessible.name: I18n.t(arrow.modelData.delta < 0 ? "prefs.launcher.move_up" : "prefs.launcher.move_down")
                        MouseArea {
                            id: arrowArea
                            anchors.fill: parent
                            anchors.margins: -3
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
                radius: Styling.radius(-4)
                Text {
                    anchors.centerIn: parent
                    text: card.meta ? (Icons[card.meta.icon] || "") : ""
                    font.family: Icons.font
                    font.pixelSize: 17
                    color: card.on ? Styling.srItem("primary") : Colors.outline
                }
            }

            ColumnLayout {
                Layout.fillWidth: true
                spacing: 1
                Text {
                    Layout.fillWidth: true
                    text: I18n.t("launcher.provider." + card.pid)
                    font.family: Config.theme.font
                    font.pixelSize: Styling.fontSize(0)
                    font.weight: Font.DemiBold
                    color: card.on ? Colors.overSurface : Colors.outline
                    elide: Text.ElideRight
                }
                Text {
                    Layout.fillWidth: true
                    text: I18n.t("launcher.provider." + card.pid + ".desc")
                    font.family: Config.theme.font
                    font.pixelSize: Styling.fontSize(-2)
                    color: Colors.outline
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

        Text {
            id: errorText
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.bottom: parent.bottom
            anchors.leftMargin: 10
            anchors.rightMargin: 12
            anchors.bottomMargin: 6
            visible: card.prefixError !== ""
            text: card.prefixError
            wrapMode: Text.Wrap
            font.family: Config.theme.font
            font.pixelSize: Styling.fontSize(-3)
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

    Text {
        Layout.topMargin: 8
        Layout.fillWidth: true
        text: I18n.t("prefs.launcher.tabs")
        font.family: Config.theme.font
        font.pixelSize: Styling.fontSize(-2)
        font.weight: Font.DemiBold
        font.letterSpacing: 0.6
        color: Colors.outline
    }

    Repeater {
        model: Providers.TAB_IDS
        delegate: ProviderCard {
            required property string modelData
            pid: modelData
        }
    }

    Text {
        Layout.fillWidth: true
        text: I18n.t("prefs.launcher.prefix_note")
        wrapMode: Text.Wrap
        font.family: Config.theme.font
        font.pixelSize: Styling.fontSize(-3)
        color: Ui.alpha(Colors.outline, 0.9)
    }
}
