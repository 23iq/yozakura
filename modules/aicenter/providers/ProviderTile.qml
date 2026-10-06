pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Layouts
import qs.modules.theme
import qs.modules.components
import qs.modules.services
import qs.config
import qs.modules.aicenter.common

// One provider in the Connect sheet grid: logo, name and its state
// (connected, local server running/not running, needs a key).
StyledRect {
    id: root

    property var preset: ({})
    property var status: ({})

    signal picked

    readonly property bool connected: status.connected === true
    readonly property string stateText: {
        if (status.state === "hidden")
            return I18n.t("ai.connect.hidden");
        if (connected)
            return preset.local ? I18n.t("ai.connect.running") : I18n.t("ai.connect.connected");
        if (preset.local)
            return status.state === "offline" ? I18n.t("ai.connect.not_running") : I18n.t("ai.connect.not_detected");
        return preset.id === "custom" ? I18n.t("ai.connect.your_server") : I18n.t("ai.connect.needs_key");
    }

    objectName: "tile_" + (preset.id || "")
    implicitHeight: 64
    radius: Styling.radius(-2)
    variant: hover.hovered ? "focus" : "pane"
    enableBorder: true

    Behavior on opacity {
        enabled: BarLook.animDuration > 0
        NumberAnimation {
            duration: BarLook.animDuration / 3
        }
    }

    HoverHandler {
        id: hover
        cursorShape: Qt.PointingHandCursor
    }
    TapHandler {
        onTapped: root.picked()
    }

    RowLayout {
        anchors.fill: parent
        anchors.leftMargin: 12
        anchors.rightMargin: 12
        spacing: 12
        ProviderIcon {
            icon: root.preset.icon || ""
            size: 26
            color: root.connected ? Colors.primary : Colors.overSurface
        }
        ColumnLayout {
            Layout.fillWidth: true
            spacing: 2
            Text {
                Layout.fillWidth: true
                text: root.preset.label || root.preset.id || ""
                elide: Text.ElideRight
                font.family: Config.theme.font
                font.pixelSize: BarLook.font(-1)
                font.weight: Font.Medium
                color: Colors.overSurface
            }
            RowLayout {
                spacing: 5
                StatusDot {
                    visible: root.connected
                    implicitWidth: 6
                    implicitHeight: 6
                }
                Text {
                    objectName: "tileState_" + (root.preset.id || "")
                    text: root.stateText
                    font.family: Config.theme.font
                    font.pixelSize: BarLook.font(-3)
                    color: root.connected ? Colors.success : Colors.outline
                }
            }
        }
        StyledRect {
            visible: root.preset.local === true
            implicitWidth: localLabel.implicitWidth + 12
            implicitHeight: localLabel.implicitHeight + 4
            radius: height / 2
            variant: "common"
            Text {
                id: localLabel
                anchors.centerIn: parent
                text: I18n.t("ai.connect.local")
                font.family: Config.theme.font
                font.pixelSize: BarLook.font(-4)
                color: Colors.overSurfaceVariant
            }
        }
    }
}
