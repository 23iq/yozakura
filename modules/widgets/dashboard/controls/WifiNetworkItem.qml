pragma ComponentBehavior: Bound
import QtQuick
import qs.modules.theme
import qs.modules.services
import qs.modules.components.kit
import "DeviceGlyphs.js" as DeviceGlyphs

// One Wi-Fi network as a kit ListRow: the signal glyph, the SSID with its
// state (connected / secured / open, 5 GHz), the connected one selected.
// A click unfolds the password field (when asked) and Connect /
// Disconnect (the row's one primary action).
Column {
    id: root

    required property WifiAccessPoint network
    property bool expanded: false
    readonly property bool active: root.network?.active ?? false

    spacing: Space.xs

    ListRow {
        objectName: "networkRow"
        width: parent.width
        title: root.network?.ssid ?? ""
        subtitle: {
            const parts = [];
            if (root.active)
                parts.push(I18n.t("wifi.connected"));
            else
                parts.push(root.network?.isSecure ? I18n.t("wifi.secured") : I18n.t("wifi.open"));
            if (root.network?.is5GHz)
                parts.push(I18n.t("wifi.band_5g"));
            return parts.join(" · ");
        }
        selected: root.active
        leading: Component {
            Text {
                text: Icons[DeviceGlyphs.wifiGlyph(root.network?.strength)]
                font.family: Icons.font
                font.pixelSize: Type.iconSize("body")
                color: root.active ? Type.accent : Type.secondary
            }
        }
        trailing: Component {
            Text {
                visible: root.network?.isSecure ?? false
                text: Icons.lock
                font.family: Icons.font
                font.pixelSize: Type.iconSize("caption")
                color: Type.muted
            }
        }
        onClicked: root.expanded = !root.expanded
    }

    SearchField {
        objectName: "passwordField"
        width: parent.width
        visible: root.expanded && (root.network?.askingPassword ?? false)
        glyph: Icons.lock
        passwordMode: true
        rule: true
        placeholderText: I18n.t("wifi.password")
        onAccepted: {
            if (text.length > 0) {
                NetworkService.changePassword(root.network, text);
                text = "";
            }
        }
    }

    Item {
        width: parent.width
        height: connect.implicitHeight
        visible: root.expanded

        Chip {
            id: connect
            objectName: "connectChip"
            anchors.right: parent.right
            primary: !root.active
            icon: root.active ? Icons.cancel : Icons.link
            text: root.active ? I18n.t("wifi.disconnect") : I18n.t("wifi.connect")
            onClicked: {
                if (root.active)
                    NetworkService.disconnectWifiNetwork();
                else
                    NetworkService.connectToWifiNetwork(root.network);
            }
        }
    }
}
