pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Layouts
import qs.modules.theme
import qs.modules.components
import qs.modules.services
import qs.config

// One model of a CLI agent in the picker ("Claude › Haiku"), indented under
// the agent: its name, "default" for the agent's own default (with the
// concrete model it resolves to), the effort levels it accepts and a check
// when it is what the visible engine runs with. Tap = engine + model.
StyledRect {
    id: root

    property var model: ({})
    property bool selected: false
    property bool current: false

    signal activated

    readonly property var efforts: model.efforts || []
    readonly property string detail: [model.isDefault ? I18n.t("ai.picker_agent_default") + (model.resolved ? " · " + model.resolved : "") : "", efforts.length > 0 ? I18n.t("ai.picker_efforts").arg(efforts.join(" · ")) : ""].filter(x => x.length > 0).join(" — ")

    implicitHeight: Math.max(36, content.implicitHeight + 10)
    radius: Styling.radius(-6)
    variant: selected ? "focus" : (hover.hovered ? "common" : "transparent")

    HoverHandler {
        id: hover
        cursorShape: Qt.PointingHandCursor
    }
    TapHandler {
        onTapped: root.activated()
    }

    RowLayout {
        id: content
        anchors.fill: parent
        anchors.leftMargin: 38
        anchors.rightMargin: 10
        spacing: 8
        ColumnLayout {
            Layout.fillWidth: true
            spacing: 1
            Text {
                objectName: "agentModelName"
                Layout.fillWidth: true
                text: root.model.name || root.model.id || ""
                elide: Text.ElideRight
                font.family: Config.theme.font
                font.pixelSize: Styling.fontSize(-2)
                font.weight: root.current ? Font.DemiBold : Font.Normal
                color: Colors.overSurface
            }
            Text {
                Layout.fillWidth: true
                visible: text.length > 0
                text: root.detail
                elide: Text.ElideRight
                font.family: Config.theme.font
                font.pixelSize: Styling.fontSize(-4)
                color: Colors.outline
            }
        }
        Text {
            visible: root.current
            text: Icons.accept
            font.family: Icons.font
            font.pixelSize: 13
            color: Colors.primary
        }
    }
}
