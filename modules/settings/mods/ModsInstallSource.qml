import QtQuick
import QtQuick.Layouts
import qs.modules.theme
import qs.modules.services
import qs.config
import qs.modules.settings
import qs.modules.settings.controls

// Package source field + Install. Installing never runs directly: it asks
// for the trust confirmation first (`installRequested(source)`). The field
// clears once ModsService reports that source installed.
ColumnLayout {
    id: root

    signal installRequested(string source)

    readonly property string source: sourceField.input.text.trim()

    width: parent ? parent.width : implicitWidth
    spacing: Metrics.spacing

    function request() {
        if (root.source !== "")
            root.installRequested(root.source);
    }

    Connections {
        target: ModsService
        function onInstalled(source) {
            if (root.source === source)
                sourceField.input.text = "";
        }
    }

    Connections {
        target: sourceField.input
        function onAccepted() {
            root.request();
        }
    }

    RowLayout {
        Layout.fillWidth: true
        spacing: Metrics.spacing

        TextControl {
            id: sourceField
            Layout.fillWidth: true
            enabled: !ModsService.busy
            placeholder: I18n.t("mods.source_placeholder")
            Accessible.name: I18n.t("mods.package_source")
            Accessible.description: I18n.t("mods.source_placeholder")
        }

        PillButton {
            kind: "filled"
            icon: "downloadSimple"
            text: I18n.t("mods.install")
            enabled: !ModsService.busy && root.source !== ""
            onClicked: root.request()
        }
    }

    RowLayout {
        Layout.fillWidth: true
        spacing: Metrics.spacing

        Text {
            Layout.alignment: Qt.AlignTop
            text: Icons.shieldWarning
            font.family: Icons.font
            font.pixelSize: Styling.fontSize(-1)
            color: Colors.warning
        }

        Text {
            Layout.fillWidth: true
            text: I18n.t("mods.trust_warning")
            font.family: Config.theme.font
            font.pixelSize: Styling.fontSize(-2)
            color: Colors.overSurfaceVariant
            wrapMode: Text.Wrap
        }
    }
}
