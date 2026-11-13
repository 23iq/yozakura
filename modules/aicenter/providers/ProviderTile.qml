pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Layouts
import qs.modules.theme
import qs.modules.components.kit
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
    implicitHeight: Space.controlL
    radius: Look.radius("control")
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
        anchors.leftMargin: Space.m
        anchors.rightMargin: Space.m
        spacing: Space.m
        ProviderIcon {
            icon: root.preset.icon || ""
            size: 26
            color: root.connected ? Type.accent : Type.text
        }
        ColumnLayout {
            Layout.fillWidth: true
            spacing: Space.xs / 2
            AiText {
                role: "secondary"
                Layout.fillWidth: true
                text: root.preset.label || root.preset.id || ""
                // a long name wraps (two lines at most), whole
                wrapMode: Text.WordWrap
                maximumLineCount: 2
                elide: Text.ElideNone
                font.weight: Font.Medium
                color: Type.text
            }
            RowLayout {
                spacing: Space.xs
                StatusDot {
                    visible: root.connected
                    implicitWidth: Space.xs + Space.hairline * 2
                    implicitHeight: Space.xs + Space.hairline * 2
                }
                AiText {
                    objectName: "tileState_" + (root.preset.id || "")
                    role: "caption"
                    text: root.stateText
                    color: root.connected ? Colors.success : Colors.outline
                }
            }
        }
        StyledRect {
            visible: root.preset.local === true
            implicitWidth: localLabel.implicitWidth + 2 * Space.s
            implicitHeight: localLabel.implicitHeight + Space.xs
            radius: Look.radius("round", height)
            variant: "common"
            AiText {
                id: localLabel
                role: "caption"
                anchors.centerIn: parent
                text: I18n.t("ai.connect.local")
                color: Type.secondary
            }
        }
    }
}
