import QtQuick
import qs.modules.theme
import qs.modules.services
import qs.modules.components
import qs.config
import qs.modules.settings
import "../Ui.js" as Ui

// Connection status of one app to the generated theme (AppHooksService):
// "Connected" chip, "Connect" button, "Restart X to apply" notice, "Managed
// by your dotfiles" chip (hover shows the line to add) or an error chip.
// Nothing for apps that are absent or have no hook.
Item {
    id: root

    property string appLabel: ""
    property string hookState: ""
    property string reason: ""
    property bool needsRestart: false
    // the app's theming toggle
    property bool themed: true
    signal connectRequested

    readonly property bool relogin: root.hookState === "connected" && root.reason === "relogin"
    readonly property string kind: {
        if (root.hookState === "connected")
            return root.needsRestart || root.relogin ? "notice" : "ok";
        if (root.hookState === "managed")
            return "managed";
        if (root.hookState === "error")
            return "error";
        if (root.hookState === "disconnected" && root.themed)
            return "connect";
        return "";
    }
    readonly property string chipText: {
        switch (root.kind) {
        case "ok":
            return I18n.t("prefs.term.hook.connected");
        case "notice":
            return root.relogin ? I18n.t("prefs.term.hook.relogin") : I18n.t("prefs.term.hook.restart", root.appLabel);
        case "managed":
            return I18n.t("prefs.term.hook.managed");
        case "error":
            return I18n.t("prefs.term.hook.error");
        }
        return "";
    }
    readonly property string chipIcon: root.kind === "ok" ? "checkCircle" : (root.kind === "managed" ? "lock" : (root.kind === "error" ? "warning" : "arrowsClockwise"))
    readonly property color accent: root.kind === "ok" ? Colors.primary : (root.kind === "error" ? Colors.error : Colors.tertiary)
    readonly property string tip: root.kind === "managed" ? I18n.t("prefs.term.hook.managed.tip", root.reason) : (root.kind === "error" ? root.reason : "")

    visible: root.kind !== ""
    implicitWidth: root.kind === "connect" ? connectButton.implicitWidth : chip.width
    implicitHeight: 34

    PillButton {
        id: connectButton
        objectName: "hookConnect"
        visible: root.kind === "connect"
        anchors.verticalCenter: parent.verticalCenter
        icon: "plugsConnected"
        text: I18n.t("prefs.term.hook.connect")
        onClicked: root.connectRequested()
    }

    Rectangle {
        id: chip
        objectName: "hookChip"
        visible: root.kind !== "connect"
        anchors.verticalCenter: parent.verticalCenter
        width: chipRow.implicitWidth + 24
        height: 28
        radius: height / 2
        color: Ui.alpha(root.accent, 0.14)
        border.width: 1
        border.color: Ui.alpha(root.accent, 0.4)

        Row {
            id: chipRow
            anchors.centerIn: parent
            spacing: 6
            Text {
                anchors.verticalCenter: parent.verticalCenter
                text: Icons[root.chipIcon] ?? ""
                font.family: Icons.font
                font.pixelSize: Styling.fontSize(-1)
                color: root.accent
            }
            Text {
                objectName: "hookChipText"
                anchors.verticalCenter: parent.verticalCenter
                text: root.chipText
                font.family: Config.theme.font
                font.pixelSize: Styling.fontSize(-2)
                font.weight: Font.DemiBold
                color: root.accent
            }
        }

        HoverHandler {
            id: hover
        }
        StyledToolTip {
            objectName: "hookTip"
            show: hover.hovered
            tooltipText: root.tip
        }
    }
}
