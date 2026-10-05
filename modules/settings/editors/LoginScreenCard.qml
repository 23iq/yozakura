import QtQuick
import Quickshell
import Quickshell.Io
import qs.modules.globals
import qs.modules.services
import qs.modules.theme
import qs.config
import qs.modules.settings
import "../Ui.js" as Ui

// SDDM login theme: whether it is installed, when it was last synced (the
// shell re-syncs it on wallpaper, palette and lock screen changes), a
// "sync now" and the install command to copy (installing needs root, so
// the shell never runs it).
Item {
    id: root

    property var entry
    property bool installed: false
    property string syncedAt: ""
    readonly property string installCommand: "sudo " + Quickshell.shellDir + "/scripts/install-sddm-theme.sh"

    implicitHeight: column.implicitHeight + 28

    function refresh() {
        probe.running = false;
        probe.running = true;
    }

    Component.onCompleted: refresh()

    Process {
        id: probe
        command: ["sh", "-c", "f=\"$1/theme.conf\"; [ -r \"$f\" ] && date -r \"$f\" '+%Y-%m-%d %H:%M'", "sh", Brand.sddmDataDir]
        stdout: StdioCollector {
            onStreamFinished: {
                root.syncedAt = text.trim();
                root.installed = root.syncedAt !== "";
            }
        }
    }

    Process {
        id: sync
        command: ["bash", Quickshell.shellDir + "/scripts/sddm-sync.sh", "--force", "--quiet"]
        onExited: root.refresh()
    }

    Process {
        id: copy
        command: ["wl-copy", "--", root.installCommand]
    }

    Rectangle {
        anchors.fill: parent
        radius: Math.min(Styling.radius(2), 18)
        color: Ui.alpha(Colors.overBackground, 0.06)
        border.width: 1
        border.color: Ui.alpha(Colors.outlineVariant, 0.6)
    }

    Column {
        id: column
        x: 14
        y: 14
        width: parent.width - 28
        spacing: 10

        Row {
            spacing: 10
            Rectangle {
                anchors.verticalCenter: parent.verticalCenter
                width: 8
                height: 8
                radius: 4
                color: root.installed ? Colors.success : Colors.outline
            }
            Text {
                anchors.verticalCenter: parent.verticalCenter
                text: root.installed ? I18n.t("prefs.lockscreen.sddm.installed", root.syncedAt) : I18n.t("prefs.lockscreen.sddm.not_installed")
                font.family: Config.theme.font
                font.pixelSize: Styling.fontSize(-1)
                font.weight: Font.Medium
                color: Colors.overBackground
            }
        }

        Text {
            width: parent.width
            visible: !root.installed
            text: root.installCommand
            font.family: Config.theme.monoFont
            font.pixelSize: Styling.fontSize(-2)
            color: Colors.overSurfaceVariant
            wrapMode: Text.WrapAnywhere
        }

        Row {
            spacing: 8
            PillButton {
                visible: root.installed
                enabled: !sync.running
                icon: "sync"
                text: sync.running ? I18n.t("prefs.lockscreen.sddm.syncing") : I18n.t("prefs.lockscreen.sddm.sync")
                onClicked: sync.running = true
            }
            PillButton {
                visible: !root.installed
                icon: "copy"
                text: I18n.t("prefs.lockscreen.sddm.copy_install")
                onClicked: copy.running = true
            }
        }
    }
}
