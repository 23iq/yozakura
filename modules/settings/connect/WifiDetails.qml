pragma ComponentBehavior: Bound

import QtQuick
import qs.modules.theme
import qs.modules.services
import qs.modules.components.kit
import qs.modules.settings
import qs.modules.settings.connect
import "ConnectModel.js" as ConnectModel

// Network > the picked network: its signal as a ring around the Wi-Fi
// glyph, its name and state, the facts (signal, band, security), and the
// one action it needs at the foot: Connect (asking for the password when
// the network wants one) or Disconnect.
Item {
    id: root

    property var entry
    property real fillHeight: 0
    readonly property var ap: ConnectModel.pick(NetworkService.friendlyWifiNetworks || [], "ssid", ConnectState.ssid, "active")
    readonly property bool secure: !!root.ap && String(root.ap.security || "") !== "" && root.ap.security !== "--"

    objectName: "wifiDetails"
    // the facts, then the action under them: never over the last fact
    implicitHeight: Math.max(root.fillHeight > 0 ? root.fillHeight : Space.controlL * 3, root.ap ? body.height + Space.m + action.height : 0)

    KitText {
        visible: !root.ap
        role: "secondary"
        text: I18n.t("prefs.net.pick")
    }

    Column {
        id: body
        visible: !!root.ap
        width: root.width
        spacing: Space.m

        Row {
            spacing: Space.l
            Ring {
                id: ring
                width: Space.controlL + Space.l
                height: width
                value: root.ap ? Number(root.ap.strength) / 100 : 0
                Icon {
                    icon: Icons.wifiHigh
                    role: "display"
                    tone: root.ap && root.ap.active ? "accent" : "secondary"
                }
            }
            Column {
                anchors.verticalCenter: ring.verticalCenter
                spacing: Space.xs
                KitText {
                    role: "title"
                    text: root.ap ? root.ap.ssid : ""
                }
                KitText {
                    role: "secondary"
                    color: root.ap && root.ap.active ? Type.accent : Type.secondary
                    text: I18n.t(root.ap && root.ap.active ? "prefs.net.connected" : "prefs.net.not_connected")
                }
            }
        }

        FactRows {
            width: root.width
            facts: root.ap ? [[I18n.t("prefs.net.signal"), root.ap.strength + " %"], [I18n.t("prefs.net.band"), Number(root.ap.frequency) > 4900 ? "5 GHz" : "2.4 GHz"], [I18n.t("prefs.net.security"), root.secure ? root.ap.security : I18n.t("prefs.net.open")]] : []
        }

        SearchField {
            objectName: "wifiPassword"
            width: root.width
            visible: !!root.ap && root.ap.askingPassword === true
            glyph: Icons.lock
            passwordMode: true
            rule: true
            placeholderText: I18n.t("prefs.net.password")
            onAccepted: {
                if (text.length > 0) {
                    NetworkService.changePassword(root.ap, text);
                    text = "";
                }
            }
        }
    }

    PillButton {
        id: action
        objectName: "wifiAction"
        visible: !!root.ap
        y: Math.max(root.height - height, body.height + Space.m)
        kind: root.ap && root.ap.active ? "ghost" : "filled"
        icon: root.ap && root.ap.active ? "xCircle" : "link"
        text: I18n.t(root.ap && root.ap.active ? "prefs.net.disconnect" : "prefs.net.connect")
        onClicked: {
            if (root.ap.active)
                NetworkService.disconnectWifiNetwork();
            else
                NetworkService.connectToWifiNetwork(root.ap);
        }
    }
}
